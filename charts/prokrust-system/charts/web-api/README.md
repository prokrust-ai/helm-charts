# Web API

Installed by `prokrust-system` with its selected image and chart versions. Use one installation per namespace; provide existing image-pull secrets through `global.imagePullSecrets`.

- `global.workloadPlacementProfile`: `arm64` by default. Use `standard` only with images supported by the selected nodes.
- `webApi.browserOrigin`: public HTTPS origin; terminate TLS upstream. Configure shared browser sessions through the system chart.
- `webApi.connectorRegistryConfigMap` and `webApi.connectorRegistryItems` configure an aggregate registry for a standalone Web API installation. System can pass a list of trusted provider slugs in `ConnectorRegistry.providers` when rendering `web-api.resources`. The API reads each independently installed provider’s registration from its optional ConfigMap mount and refreshes the catalog as kubelet updates the volume. The earlier aggregate projection via `ConnectorRegistry.sources` and `ConnectorRegistry.checksum` also remains supported.
- `global.networkPolicy`: permitted Kubernetes API, DNS and artifact-store destinations. Artifact access requires the configured storage credentials or workload identity.

For direct rendering, set `webApi.enabled=true`. Installation requires the matching Prokrust CRDs and system resources.
