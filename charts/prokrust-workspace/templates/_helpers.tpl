{{- define "operator.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: prokrust
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "operator.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{- define "operator.workflowNames" -}}
{{- range $path, $_ := .Files.Glob "files/resources/workflows/*.yaml" }}
{{- $object := $.Files.Get $path | fromYaml }}
{{- include "operator.startupWorkflow" (dict "object" $object "systemNamespace" (default $.Release.Namespace $.StartupSystemNamespace)) -}}
{{- $projection := dict "apiVersion" $object.apiVersion "kind" $object.kind "namespace" $.Release.Namespace "spec" $object.spec }}
{{- $digest := sha256sum (toJson $projection) }}
{{- $base := regexReplaceAll "-[0-9a-f]{12}$" $object.metadata.name "" }}
- {{ printf "%s-%s" $base (trunc 12 $digest) }}
{{- end }}
{{- end -}}

{{- define "operator.placementProfile" -}}
{{- $profile := "standard" -}}
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

{{- define "operator.startupWorkflow" -}}
{{- range $template := .object.spec.templates }}
{{- if and $template.container (has $template.serviceAccountName (list "prokrust-trainer" "prokrust-batch-predictor")) }}
{{- $startupEnv := list (dict "name" "PROKRUST_STARTUP_URL" "value" (printf "https://prokrust-runtime-startup.%s.svc/startup/v1/authorize" $.systemNamespace)) (dict "name" "PROKRUST_POD_NAME" "valueFrom" (dict "fieldRef" (dict "fieldPath" "metadata.name"))) (dict "name" "PROKRUST_POD_UID" "valueFrom" (dict "fieldRef" (dict "fieldPath" "metadata.uid"))) (dict "name" "PROKRUST_STARTUP_CONTAINER" "value" "main") }}
{{- $_ := set $template.container "env" (concat $template.container.env $startupEnv) }}
{{- $_ := set $template.container "volumeMounts" (append $template.container.volumeMounts (dict "name" "prokrust-startup" "mountPath" "/var/run/prokrust-startup" "readOnly" true)) }}
{{- $sources := list (dict "serviceAccountToken" (dict "audience" "prokrust-runtime-startup" "expirationSeconds" 600 "path" "token")) (dict "configMap" (dict "name" "prokrust-runtime-startup-ca" "items" (list (dict "key" "ca.crt" "path" "ca.crt")))) }}
{{- $_ := set $template "volumes" (append $template.volumes (dict "name" "prokrust-startup" "projected" (dict "defaultMode" 288 "sources" $sources))) }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "operator.networkFamily" -}}
{{- $family := .Values.global.networkFamily | default "IPv4" -}}
{{- if not (has $family (list "IPv4" "IPv6")) -}}
{{- fail "global.networkFamily must be IPv4 or IPv6" -}}
{{- end -}}
{{- $family -}}
{{- end -}}

{{- define "operator.installation" -}}
{{- $system := .Values.installation.namespace -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $system) -}}
{{- fail "installation.namespace must be the existing Prokrust system namespace" -}}
{{- end -}}
{{- if or (gt (len $system) 63) (eq $system .Release.Namespace) -}}
{{- fail "installation.namespace must be a distinct system namespace of at most 63 characters" -}}
{{- end -}}
{{- $system -}}
{{- end -}}

{{- define "operator.humanAccount" -}}
{{- if has . (list "default" "prokrust-application-controller" "prokrust-ballista-cluster-controller" "prokrust-web-api" "prokrust-workflow-executor" "prokrust-connection-probe" "prokrust-artifact-store-probe" "prokrust-table-staging" "prokrust-table-materializer" "prokrust-graph-materializer" "prokrust-training-materializer" "prokrust-prediction-materializer" "prokrust-artifact-writer" "prokrust-trainer" "prokrust-batch-predictor" "prokrust-ballista-scheduler" "prokrust-ballista-executor" "prokrust-kserve-runtime") -}}
{{- fail "OIDC access must use an explicit human-access ServiceAccount, separate from product runtime identities" -}}
{{- end -}}
{{- end -}}
