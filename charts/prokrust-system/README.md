# prokrust-system

Install into a dedicated system namespace; this chart uses fixed resource names and a default-deny network policy.

Installation controllers and Web API for Prokrust. Install the matching
`prokrust-crds` release first; create workspaces with `prokrust-workspace`.
Web API is included in this chart; no separate Web API chart installation is required.

Requires Kubernetes 1.35–1.37, ARM64 nodes, cert-manager, and Argo Workflows.
The Kubernetes range follows the bundled kubectl 1.36 client's
[supported version skew](https://kubernetes.io/releases/version-skew-policy/#kubectl).
Provide registry pull credentials, licensing Secrets, and cluster-specific
network access through values. Controller requests and limits are configurable
under `controllers.applicationResources` and `controllers.ballistaClusterResources`.

## Install connectors with Helm

Install the matching provider CRDs with `prokrust-crds`. Enable
`connectors.discovery.enabled` in the System release. Each entry of
`connectors.discovery.providers` names a trusted provider that System can
load. The default list contains `bigquery`, `gcs`, `iceberg`, `paimon`, `s3`,
and `synthetic`. An empty installation works with discovery enabled.

Install one provider release per provider in the System namespace. Pin the
chart version on that release. For example, with installation-specific values
in `bigquery-values.yaml`:

```sh
helm upgrade --install connector-bigquery oci://ar.prokrust.io/charts/connector-bigquery \
  --namespace prokrust-system --version 1.5.0-rc.2 --values bigquery-values.yaml
```

Configure controller pull credentials, API server endpoints, workspace RBAC,
runtime identity and network access on the provider release. Enroll workspaces
and enable their connector access in the Workspace chart. Each provider chart
installs its controller and the descriptor, digest and schemas in its
`prokrust-connector-<provider>-registry` ConfigMap. Operator and Web API read
updates when Kubernetes refreshes their mounted volumes. To upgrade, repeat
the provider command with a compatible new chart version. Drain accepted work
before removing a provider release.

With Kustomize, pin each provider’s chart version and values in its own
`helmCharts` entry.

Restrict write access to the installation namespace. Discovery adds an
admission check for creates, updates and deletes of trusted registry ConfigMaps.
The Helm installer needs regular write permissions for the provider resources
and the `register` verb for that provider's ConfigMap. Cluster administrators
already have both. A namespace administrator can grant the additional
permission by binding the `prokrust-connector-registry-writer` Role to trusted
provider installers, or create a narrower Role restricted to one ConfigMap.
Verify any pre-existing trusted ConfigMaps before enabling discovery.

For an existing aggregate registry, keep `connectors.enabled`,
`connectors.registryConfigMap`, `connectors.registryItems` and the corresponding
Web API values. To switch to discovery, remove those aggregate registry settings.

## License activation during uninstall

A plain `helm uninstall` runs a pre-delete Job that releases this installation's
activation slot using its existing signing key. Installs, upgrades and rollbacks
leave the slot in place. Helm also runs uninstall when cleaning up a failed
first install with `--atomic`. If the installation never acquired a slot, the
Job succeeds without contacting the license server.

For an active installation the Job waits for vendor acknowledgement before Helm
deletes resources. Once teardown starts the controller stops activating and
reserving new licensed work. After an outage or a failed Job, keep the
installation identity, activation and entitlement Secret, restore connectivity
to the Kubernetes API and license endpoint, then retry `helm uninstall`. The
retry reuses the saved challenge after a lost response. A subsequent install
can activate again with the retained identity. For deliberate offline removal,
record the installation and activation IDs, then use `helm uninstall --no-hooks`.
Contact the license administrator to release that slot separately.

For Kustomize-rendered charts managed by Argo CD, use `leaseBootstrap.mode: argo`
and set `licensing.uninstall.argoApplication` to the owning Application:

```yaml
licensing:
  uninstall:
    argoApplication:
      namespace: argocd
      name: prokrust-system
```

Argo CD 3.5.3 recognizes the rendered Helm pre-delete annotation. The Job
requires a deletion timestamp and an Argo resource-cascade finalizer on that
exact Application. Normal syncs and orphan deletion preserve the activation.
If the Application already disappeared during orphan deletion, the Job also
succeeds without contacting the vendor. Permission and connection errors block
the Job before any licensing call. Argo mode
without an Application binding omits the uninstall hook. When applying plain
YAML with a tool that does not implement hooks, exclude Helm hooks during
rendering. With Kustomize, set `skipHooks: true` on the System `helmCharts` entry
when applying the output directly to Kubernetes.
