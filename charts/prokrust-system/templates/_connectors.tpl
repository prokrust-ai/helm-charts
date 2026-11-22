{{/* Build both consumer projections from the same enabled, packaged providers. */}}
{{- define "operator.connectorRegistry" -}}
{{- $providers := list -}}
{{- $sources := list (dict "configMap" (dict "name" "prokrust-connector-registry-index"
      "items" (list (dict "key" "registry.json" "path" "registry.json")))) -}}
{{- range $slug, $settings := .Values.connectors -}}
  {{- if and (has $slug (list "bigquery" "gcs" "iceberg" "paimon" "s3" "synthetic")) $settings.enabled -}}
    {{- $wrapper := required "Enabled providers require the bundled connectors dependency" $.Subcharts.connectors -}}
    {{- $provider := required (printf "Missing bundled connector %s" $slug) (index $wrapper.Subcharts $slug) -}}
    {{- $descriptor := dict "file" (printf "%s/descriptor.json" $slug) "sha256" $provider.Values.descriptorDigest -}}
    {{- $providers = append $providers (dict "id" (printf "prokrust.ai/%s" $slug)
          "enabled" true "release" $provider.Chart.AppVersion "descriptor" $descriptor
          "controllerNamespace" $.Release.Namespace "tlsProfile" "installation-ca") -}}
    {{- $items := list -}}
    {{- range $file := list "descriptor.json" "connection-v1.json" "selector-v1.json" -}}
      {{- $items = append $items (dict "key" $file "path" (printf "%s/%s" $slug $file)) -}}
    {{- end -}}
    {{- $sources = append $sources (dict "configMap" (dict "name" (printf "prokrust-connector-%s-registry" $slug) "items" $items)) -}}
  {{- end -}}
{{- end -}}
{{- $legacy := .Values.connectors.enabled | default false -}}
{{- if $providers -}}
  {{- range $key := list "enabled" "registryConfigMap" "registryItems" -}}
    {{- if hasKey $.Values.connectors $key -}}
      {{- fail (printf "connectors.%s cannot be combined with bundled providers" $key) -}}
    {{- end -}}
  {{- end -}}
  {{- $web := index .Values "web-api" -}}
  {{- if and $web.webApi.enabled (not $web.webApi.renderFromParent) -}}
    {{- fail "Bundled providers require the integrated Web API chart when webApi.enabled is true" -}}
  {{- end -}}
  {{- if or $web.webApi.connectorRegistryConfigMap $web.webApi.connectorRegistryItems -}}
    {{- fail "External Web API registry configuration cannot be combined with bundled providers" -}}
  {{- end -}}
  {{- $index := dict "providers" $providers | toJson -}}
  {{- dict "enabled" true "index" $index "sources" $sources "checksum" (sha256sum $index) | toJson -}}
{{- else -}}
  {{- dict "enabled" $legacy | toJson -}}
{{- end -}}
{{- end -}}
