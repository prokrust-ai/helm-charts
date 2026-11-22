# Prokrust workspace

Install once per workload namespace after installing `prokrust-system`.
`supportedSystemVersion` records the system release used to verify this chart.
Enrollment requires an installed system with a recorded release.
Controllers run centrally in the system namespace. This chart directly owns
workspace ServiceAccounts, image references, quotas, network policies and optional
ServingRuntime resources; it has no child chart dependencies.

Set `installation.namespace`, `global.networkPolicy.apiServerEndpoints` and the storage,
identity and pull Secret settings for the workspace. Installation requires access
to its enrollment resources in the system namespace and scoped cluster RBAC.
Wait for workspace enrollment to become Ready before submitting workloads.

Enable `serving.enabled` in both System and Workspace for KServe. Configure
`connectors.enabled` and exact `connectionResources` when using external providers.
`tenantDefaults` optionally owns the workspace's policy, artifact store and
Ballista cluster. Drain and release the workspace before uninstalling.

ArtifactStore defaults use inline `storage.backend: S3` with `storage.s3`, or
`storage.backend: GCS` with `storage.gcs`; credential values stay in Secrets.
The cluster must already provide Prokrust CRDs, Argo Workflows and, when enabled,
KServe. Supported Kubernetes versions match System: 1.35–1.37.
