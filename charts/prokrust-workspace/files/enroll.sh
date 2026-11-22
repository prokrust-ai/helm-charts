set -eu

# kubectl with a request timeout can skip in-cluster discovery.
api_host="${KUBERNETES_SERVICE_HOST:?Kubernetes Service host is required}"
api_port="${KUBERNETES_SERVICE_PORT:?Kubernetes Service port is required}"
case "$api_host" in *:*) api_host="[$api_host]";; esac
umask 077
export KUBECONFIG="$HOME/prokrust-hook-kubeconfig"
cat > "$KUBECONFIG" <<EOF
apiVersion: v1
kind: Config
current-context: incluster
clusters:
- name: local
  cluster:
    server: "https://$api_host:$api_port"
    certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
contexts:
- name: incluster
  context:
    cluster: local
    user: hook
users:
- name: hook
  user:
    tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
EOF

read_namespace() {
  kubectl --request-timeout=10s get namespace "$WORKSPACE" -o "$1"
}

installed="$(kubectl --request-timeout=10s -n "$INSTALLATION" get configmap prokrust-component-versions \
  -o 'jsonpath={.data.compositionVersion}')" || {
  echo "Cannot read the product release from installation $INSTALLATION. Install the system chart first and check enrollment API access." >&2
  exit 1
}
if [ -z "$installed" ]; then
  echo "Installation $INSTALLATION has no recorded system release." >&2
  exit 1
fi

# Argo applies opt-in default resources after this Sync hook. Helm also checks
# existing ownership during server-side rendering and its own install checks.
if [ "$CHECK_DEFAULTS" = true ]; then
  for kind in prokrustpolicy artifactstore ballistacluster; do
    found="$(kubectl --request-timeout=10s -n "$WORKSPACE" get "$kind" default --ignore-not-found \
      -o 'jsonpath={.metadata.name}{"|"}{.metadata.annotations.prokrust\.ai/workspace-chart}')"
    if [ -n "$found" ] && [ "$found" != "default|$WORKSPACE_RELEASE" ]; then
      echo "Refusing to adopt existing $kind/default in $WORKSPACE. Disable tenantDefaults or use the existing resource owner." >&2
      exit 1
    fi
  done
fi

for attempt in 1 2 3 4 5; do
  state="$(read_namespace 'jsonpath={.metadata.resourceVersion}{"|"}{.metadata.labels.prokrust\.ai/installation}{"|"}{.metadata.deletionTimestamp}')" || {
    echo "Cannot read workspace Namespace $WORKSPACE. Provision the namespace and check enrollment RBAC and API egress." >&2
    exit 1
  }
  version="${state%%|*}"
  assignment="${state#*|}"
  if [ -z "$version" ] || [ -n "${assignment#*|}" ]; then
    echo "Workspace Namespace $WORKSPACE is terminating or has no resourceVersion." >&2
    exit 1
  fi
  assignment="${assignment%%|*}"
  if [ "$assignment" = "$INSTALLATION" ]; then
    exit 0
  fi
  if [ -n "$assignment" ]; then
    echo "Workspace $WORKSPACE is assigned to $assignment. Drain and release it before installing for $INSTALLATION." >&2
    exit 1
  fi
  if kubectl --request-timeout=10s label namespace "$WORKSPACE" \
    "prokrust.ai/installation=$INSTALLATION" --resource-version="$version"; then
    exit 0
  fi
  sleep "$attempt"
done
echo "Cannot assign $WORKSPACE to $INSTALLATION. Check the Namespace label, enrollment admission, RBAC, and API connectivity." >&2
exit 1
