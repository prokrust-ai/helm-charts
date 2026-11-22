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

Enable a bundled provider with `connectors.<provider>.enabled: true` and place
its Helm overrides under the same provider key. The supported keys are
`bigquery`, `gcs`, `iceberg`, `paimon`, `s3`, and `synthetic`. Install the
corresponding CRDs with `prokrust-crds`. Each enabled chart installs its
controller and its `prokrust-connector-<provider>-registry` ConfigMap. The
application controller and Web API project those bundles into their registries;
changing provider versions or enablement rolls both consumers.

Existing installations using an external registry can keep `connectors.enabled`,
`connectors.registryConfigMap`, `connectors.registryItems` and their Web API
registry settings. Remove those settings when migrating to the provider map.
If provider resources already belong to standalone Helm releases, transfer
their ownership to the system release before enabling the same providers.
Review existing resource names and ensure each has a single release owner.
