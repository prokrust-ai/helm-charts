# Web API

Installed by `prokrust-system` with its selected image and chart versions. Use one installation per namespace; provide existing image-pull secrets through `global.imagePullSecrets`.

- `global.workloadPlacementProfile`: `arm64` by default. Use `standard` only with images supported by the selected nodes.
- `webApi.browserOrigin`: public HTTPS origin; terminate TLS upstream. Configure shared browser sessions through the system chart.
- `webApi.connectorRegistryConfigMap` and `webApi.connectorRegistryItems`: a standalone installation's provider registry bundle. The system chart can set `webApi.renderFromParent` and call `web-api.resources` with the child context plus `ConnectorRegistry.sources` and `ConnectorRegistry.checksum` to project its enabled providers and roll the API on updates.
- `global.networkPolicy`: permitted Kubernetes API, DNS and artifact-store destinations. Artifact access requires the configured storage credentials or workload identity.

For direct rendering, set `webApi.enabled=true`. Installation requires the matching Prokrust CRDs and system resources.
