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

For external sources, enable `connectors.enabled`, install the provider charts,
and supply their pinned descriptor registry through `connectors.registryConfigMap`
and `connectors.registryItems`. Configure the embedded Web API with the same
registry using `web-api.webApi.connectorRegistryConfigMap` and
`web-api.webApi.connectorRegistryItems`.
