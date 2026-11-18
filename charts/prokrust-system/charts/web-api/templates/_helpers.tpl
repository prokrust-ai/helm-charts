{{- define "web-api.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{- define "web-api.workloadPlacement" -}}
{{- $profile := "arm64" -}}
{{- if hasKey .Values.global "workloadPlacementProfile" -}}
{{- $profile = .Values.global.workloadPlacementProfile -}}
{{- end -}}
{{- if not (and (kindIs "string" $profile) (or (eq $profile "standard") (eq $profile "arm64"))) -}}
{{- fail "global.workloadPlacementProfile must be standard or arm64" -}}
{{- end -}}
{{- if eq $profile "arm64" -}}
nodeSelector:
  kubernetes.io/arch: arm64
tolerations:
  - key: kubernetes.io/arch
    operator: Equal
    value: arm64
    effect: NoSchedule
{{- end -}}
{{- end -}}

{{- define "web-api.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: prokrust
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "web-api.networkFamily" -}}
{{- $family := .Values.global.networkFamily | default "IPv4" -}}
{{- if not (has $family (list "IPv4" "IPv6")) -}}
{{- fail "global.networkFamily must be IPv4 or IPv6" -}}
{{- end -}}
{{- $family -}}
{{- end -}}

{{- define "web-api.bindHost" -}}
{{- if eq (include "web-api.networkFamily" .) "IPv6" -}}[::]{{- else -}}0.0.0.0{{- end -}}
{{- end -}}

{{- define "web-api.serviceFamily" -}}
{{- if eq (include "web-api.networkFamily" .) "IPv6" -}}
ipFamilies: [IPv6]
ipFamilyPolicy: SingleStack
{{- end -}}
{{- end -}}
