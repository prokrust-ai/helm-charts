{{- define "ballista.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{- define "ballista.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: prokrust
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}
