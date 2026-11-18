{{- define "operator.profilingEnv" -}}
- name: RP_PROFILING_ENABLED
  value: {{ .Values.profiling.enabled | quote }}
{{- if .Values.profiling.enabled }}
- name: RP_PROFILING_BACKEND_URL
  value: {{ printf "http://prokrust-pyroscope.%s.svc:4040" .Release.Namespace | quote }}
- name: RP_PROFILING_ALLOY_IMAGE
  value: {{ .Values.profiling.alloyImage | quote }}
- name: RP_PROFILING_NAMESPACE
  value: {{ .Release.Namespace | quote }}
- name: RP_PROFILING_MAX_CONCURRENT
  value: {{ .Values.profiling.maxConcurrentCaptures | quote }}
- name: RP_PROFILING_NSYS_PVC
  value: {{ .Values.profiling.nsightToolsPVC | quote }}
{{- end }}
{{- end -}}
