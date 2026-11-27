{{- define "operator.connectorRegistry" -}}
{{- $settings := .Values.connectors | default dict -}}
{{- $discovery := $settings.discovery | default dict -}}
{{- range $slug := list "bigquery" "gcs" "iceberg" "paimon" "s3" "synthetic" -}}
  {{- if hasKey $settings $slug -}}
    {{- fail (printf "connectors.%s is no longer an install option: enable connectors.discovery.enabled and install connector-%s as a separate Helm release" $slug $slug) -}}
  {{- end -}}
{{- end -}}
{{- if $discovery.enabled -}}
  {{- if or $settings.enabled $settings.registryConfigMap $settings.registryItems -}}
    {{- fail "Connector discovery cannot be combined with external aggregate registry settings" -}}
  {{- end -}}
  {{- $web := (index .Values "web-api").webApi -}}
  {{- if and $web.enabled (not $web.renderFromParent) -}}
    {{- fail "Connector discovery requires the integrated Web API renderer" -}}
  {{- end -}}
  {{- if or $web.connectorRegistryConfigMap $web.connectorRegistryItems -}}
    {{- fail "Connector discovery cannot be combined with external Web API registry settings" -}}
  {{- end -}}
  {{- dict "enabled" true "providers" (sortAlpha $discovery.providers) | toJson -}}
{{- else -}}
  {{- dict "enabled" ($settings.enabled | default false) | toJson -}}
{{- end -}}
{{- end -}}
