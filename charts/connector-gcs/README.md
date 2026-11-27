# connector-gcs

The chart publishes the signed release's descriptor and schema files in
`prokrust-connector-gcs-registry` in its installation namespace. Each
namespace supports one installation of this provider.

Set `imagePullSecrets`, `nodeSelector`, and `tolerations` for the controller
Pod. Set `runtimeNodeSelector` and `runtimeTolerations` for runtime Pods.
Runtime Pods use the image pull secrets of their workspace ServiceAccount.

## Manage the runtime ServiceAccount

When a separate installer manages the runtime ServiceAccount in a workspace,
set its exact Kubernetes username under that workspace name. For example:

```yaml
runtimeServiceAccountManagers:
  analytics:
    - system:serviceaccount:platform:workspace-installer
```

The installer also needs Kubernetes RBAC to create, update or delete the
configured `runtimeServiceAccountName`. This setting grants an admission
exception for those account operations in that workspace. Token requests and
other connector resources retain their own admission checks.

## Runtime token admission

Runtime root protection denies ordinary callers access to the reserved service
account, including `serviceaccounts/token`. Set `runtimeTokenAudiences` only to
workload-identity audiences already authorized by the cluster. The empty default
does not permit node token minting.

The exception permits only `CREATE` on the exact runtime account's `token`
subresource, with a nonempty audience list entirely contained in the configured
allowlist. Both the authenticated `system:nodes` group and a nonempty
`system:node:` username are required. It grants no RBAC permissions and does not
permit node changes to service accounts, Pods, Secrets or other runtime roots.
Cluster authentication and node TokenRequest authorization remain the trust
boundary; a compromised node remains a trusted node for this narrow request.

On GKE Standard with Calico, the observed metadata-server Pods mount kubelet
credentials, and the installed `gke-metadata-server-token-requester` role binds
`system:nodes` to `request-serviceaccounts-token-audience` for the workload pool.
This supports configuring that exact pool audience. These are configuration and
RBAC observations, not a capture of the TokenRequest body or authenticated caller.
Do not add the metadata service to `additionalTrustedUsers` to enable this path.
