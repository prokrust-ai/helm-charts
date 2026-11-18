{{- define "operator.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{- define "operator.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: prokrust
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "operator.schedulingProfile" -}}
{{- $profile := required "workflowIntegrity.schedulingProfile must be standard or gkeOptimizeUtilization" .Values.workflowIntegrity.schedulingProfile -}}
{{- if not (has $profile (list "standard" "gkeOptimizeUtilization")) -}}
{{- fail "workflowIntegrity.schedulingProfile must be standard or gkeOptimizeUtilization" -}}
{{- end -}}
{{- $profile -}}
{{- end -}}

{{- define "operator.placementProfile" -}}
{{- $profile := "arm64" -}}
{{- if hasKey .Values.global "workloadPlacementProfile" -}}
{{- $profile = .Values.global.workloadPlacementProfile -}}
{{- end -}}
{{- if not (has $profile (list "standard" "arm64")) -}}
{{- fail "global.workloadPlacementProfile must be standard or arm64" -}}
{{- end -}}
{{- $profile -}}
{{- end -}}

{{- define "operator.podPlacement" -}}
{{- if eq (include "operator.placementProfile" .) "arm64" -}}
nodeSelector:
  kubernetes.io/arch: arm64
tolerations:
  - key: kubernetes.io/arch
    operator: Equal
    value: arm64
    effect: NoSchedule
{{- end -}}
{{- end -}}

{{- define "operator.imagePullSecrets" -}}
{{- $references := .Values.global.imagePullSecrets -}}
{{- if not (kindIs "slice" $references) -}}
{{- fail "global.imagePullSecrets must be a list of name-only objects" -}}
{{- end -}}
{{- if gt (len $references) 8 -}}
{{- fail "global.imagePullSecrets cannot exceed eight references" -}}
{{- end -}}
{{- $names := dict -}}
{{- range $reference := $references -}}
{{- if not (kindIs "map" $reference) -}}
{{- fail "global.imagePullSecrets must be a list of name-only objects" -}}
{{- end -}}
{{- if or (ne (len $reference) 1) (not (hasKey $reference "name")) (not (kindIs "string" $reference.name)) -}}
{{- fail "global.imagePullSecrets must be a list of name-only objects" -}}
{{- end -}}
{{- if or (gt (len $reference.name) 253) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$" $reference.name)) -}}
{{- fail "global.imagePullSecrets names must be DNS subdomains up to 253 bytes" -}}
{{- end -}}
{{- if hasKey $names $reference.name -}}
{{- fail "global.imagePullSecrets contains duplicate references" -}}
{{- end -}}
{{- $_ := set $names $reference.name true -}}
{{- end -}}
{{- toJson $references -}}
{{- end -}}

{{- define "operator.dnsServerCIDRs" -}}
{{- $cidrs := list -}}
{{- if hasKey .Values.global "dnsServerCIDRs" -}}
{{- $cidrs = .Values.global.dnsServerCIDRs -}}
{{- end -}}
{{- if not (kindIs "slice" $cidrs) -}}
{{- fail "global.dnsServerCIDRs must be a list of unique IPv4 /32 or IPv6 /128 DNS server hosts" -}}
{{- end -}}
{{- if gt (len $cidrs) 8 -}}
{{- fail "global.dnsServerCIDRs cannot exceed eight DNS server hosts" -}}
{{- end -}}
{{- $seen := dict -}}
{{- $pattern := "^(?:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}/32|(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|::|::[0-9A-Fa-f]{1,4}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}::|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::|::(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|::[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}::(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}:(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}::(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\\.(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})/128)$" -}}
{{- range $cidr := $cidrs -}}
{{- if not (kindIs "string" $cidr) -}}
{{- fail "global.dnsServerCIDRs must contain IPv4 /32 or IPv6 /128 DNS server hosts" -}}
{{- end -}}
{{- if not (regexMatch $pattern $cidr) -}}
{{- fail "global.dnsServerCIDRs must contain IPv4 /32 or IPv6 /128 DNS server hosts" -}}
{{- end -}}
{{- if hasKey $seen $cidr -}}
{{- fail "global.dnsServerCIDRs contains duplicate DNS server hosts" -}}
{{- end -}}
{{- $_ := set $seen $cidr true -}}
{{- end -}}
{{- toJson $cidrs -}}
{{- end -}}

{{- define "operator.licenseWorkloadMatch" -}}
object.spec.containers.exists(c, (has(c.command) && size(c.command) > 0 && c.command[0] in ['/usr/local/bin/prokrust-trainer', '/usr/local/bin/prokrust-batch-predictor', '/usr/local/bin/prokrust-serve']) || (has(c.image) && ['ar.prokrust.io/prokrust/trainer:', 'ar.prokrust.io/prokrust/trainer@', 'ar.prokrust.io/prokrust/trainer-cuda:', 'ar.prokrust.io/prokrust/trainer-cuda@', 'ar.prokrust.io/prokrust/batch-predictor:', 'ar.prokrust.io/prokrust/batch-predictor@', 'ar.prokrust.io/prokrust/serving:', 'ar.prokrust.io/prokrust/serving@', 'ar.prokrust.io/prokrust/model-server:', 'ar.prokrust.io/prokrust/model-server@'].exists(prefix, c.image.startsWith(prefix)))) || (has(object.spec.initContainers) && object.spec.initContainers.exists(c, (has(c.command) && size(c.command) > 0 && c.command[0] in ['/usr/local/bin/prokrust-trainer', '/usr/local/bin/prokrust-batch-predictor', '/usr/local/bin/prokrust-serve']) || (has(c.image) && ['ar.prokrust.io/prokrust/trainer:', 'ar.prokrust.io/prokrust/trainer@', 'ar.prokrust.io/prokrust/trainer-cuda:', 'ar.prokrust.io/prokrust/trainer-cuda@', 'ar.prokrust.io/prokrust/batch-predictor:', 'ar.prokrust.io/prokrust/batch-predictor@', 'ar.prokrust.io/prokrust/serving:', 'ar.prokrust.io/prokrust/serving@', 'ar.prokrust.io/prokrust/model-server:', 'ar.prokrust.io/prokrust/model-server@'].exists(prefix, c.image.startsWith(prefix))))) || (has(object.spec.ephemeralContainers) && object.spec.ephemeralContainers.exists(c, (has(c.command) && size(c.command) > 0 && c.command[0] in ['/usr/local/bin/prokrust-trainer', '/usr/local/bin/prokrust-batch-predictor', '/usr/local/bin/prokrust-serve']) || (has(c.image) && ['ar.prokrust.io/prokrust/trainer:', 'ar.prokrust.io/prokrust/trainer@', 'ar.prokrust.io/prokrust/trainer-cuda:', 'ar.prokrust.io/prokrust/trainer-cuda@', 'ar.prokrust.io/prokrust/batch-predictor:', 'ar.prokrust.io/prokrust/batch-predictor@', 'ar.prokrust.io/prokrust/serving:', 'ar.prokrust.io/prokrust/serving@', 'ar.prokrust.io/prokrust/model-server:', 'ar.prokrust.io/prokrust/model-server@'].exists(prefix, c.image.startsWith(prefix))))) || (has(object.spec.serviceAccountName) && object.spec.serviceAccountName in ['prokrust-trainer', 'prokrust-batch-predictor', 'prokrust-kserve-runtime', 'prokrust-serving', 'prokrust-model-server', 'prokrust-table-staging', 'prokrust-table-materializer', 'prokrust-graph-materializer', 'prokrust-training-materializer', 'prokrust-prediction-materializer', 'prokrust-artifact-writer', 'prokrust-workflow-executor']) || (has(object.spec.volumes) && object.spec.volumes.exists(v, (has(v.secret) && v.secret.secretName.matches('^prokrust-license-[0-9a-f]{24}$')) || (has(v.projected) && v.projected.sources.exists(s, has(s.secret) && s.secret.name.matches('^prokrust-license-[0-9a-f]{24}$')))))
{{- end -}}

{{- define "operator.networkFamily" -}}
{{- $family := .Values.global.networkFamily | default "IPv4" -}}
{{- if not (has $family (list "IPv4" "IPv6")) -}}
{{- fail "global.networkFamily must be IPv4 or IPv6" -}}
{{- end -}}
{{- $family -}}
{{- end -}}

{{- define "operator.bindHost" -}}
{{- if eq (include "operator.networkFamily" .) "IPv6" -}}[::]{{- else -}}0.0.0.0{{- end -}}
{{- end -}}

{{- define "operator.serviceFamily" -}}
{{- if eq (include "operator.networkFamily" .) "IPv6" -}}
ipFamilies: [IPv6]
ipFamilyPolicy: SingleStack
{{- end -}}
{{- end -}}

{{- define "operator.humanAccount" -}}
{{- if has . (list "default" "prokrust-application-controller" "prokrust-ballista-cluster-controller" "prokrust-web-api" "prokrust-workflow-executor" "prokrust-connection-probe" "prokrust-artifact-store-probe" "prokrust-table-staging" "prokrust-table-materializer" "prokrust-graph-materializer" "prokrust-training-materializer" "prokrust-prediction-materializer" "prokrust-artifact-writer" "prokrust-trainer" "prokrust-batch-predictor" "prokrust-ballista-scheduler" "prokrust-ballista-executor" "prokrust-kserve-runtime") -}}
{{- fail "OIDC access must use an explicit human-access ServiceAccount, separate from product runtime identities" -}}
{{- end -}}
{{- end -}}
