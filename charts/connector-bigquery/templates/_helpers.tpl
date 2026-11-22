{{- define "connector-bigquery.name" -}}
{{- if eq .Chart.Name "bigquery" -}}
  {{- $full := printf "%s-connector-bigquery" .Release.Namespace -}}
  {{- if gt (len $full) 53 -}}
    {{- printf "%s-%s" ($full | trunc 40 | trimSuffix "-") (sha256sum $full | trunc 12) -}}
  {{- else -}}
    {{- $full -}}
  {{- end -}}
{{- else -}}
  {{- printf "%s-%s" .Release.Namespace .Release.Name | trunc 53 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- define "connector-bigquery.settings" -}}
{{- $runtime := required "runtimeImage must be pinned by digest" .Values.runtimeImage -}}
{{- if not (regexMatch "@sha256:[a-f0-9]{64}$" $runtime) -}}{{ fail "runtimeImage must be pinned by digest" }}{{- end -}}
{{- $digest := required "descriptorDigest is required" .Values.descriptorDigest -}}
{{- if not (regexMatch "^sha256:[a-f0-9]{64}$" $digest) -}}{{ fail "descriptorDigest must be a lowercase SHA-256 digest" }}{{- end -}}
{{- $settings := dict "release" .Chart.AppVersion "runtimeImage" $runtime "descriptorDigest" $digest "runtimeServiceAccountName" .Values.runtimeServiceAccountName "runtimeNodeSelector" .Values.runtimeNodeSelector "runtimeTolerations" .Values.runtimeTolerations "replicas" .Values.replicas "partitionConcurrency" .Values.partitionConcurrency "controlConcurrency" .Values.controlConcurrency "maxAttemptSeconds" .Values.maxAttemptSeconds "cleanupGraceSeconds" .Values.cleanupGraceSeconds "egress" .Values.egress "resources" .Values.runtimeResources -}}
{{- with .Values.runtimeSourceTokenAudience -}}
{{- if not (and $.Values.protectRuntimeRoots (has . $.Values.runtimeTokenAudiences) (le (len .) 2048) (regexMatch "^[!-~]+$" .)) -}}
{{- fail "runtimeSourceTokenAudience requires protected runtime roots and an exact runtimeTokenAudiences entry" -}}
{{- end -}}
{{- $_ := set $settings "runtimeSourceTokenAudience" . -}}
{{- end -}}
{{- with .Values.runtimeArtifactCredentialsSecretName -}}
{{- if not (and $.Values.protectRuntimeRoots (regexMatch "^prokrust-connector-runtime-artifact-[a-z0-9]([-a-z0-9]*[a-z0-9])?$" .) (le (len .) 63)) -}}
{{- fail "runtimeArtifactCredentialsSecretName requires protected prokrust-connector-runtime-artifact-* Secret" -}}
{{- end -}}
{{- $_ := set $settings "runtimeArtifactCredentialsSecretName" . -}}
{{- end -}}
{{- with .Values.runtimeArtifactCredentialsProjectionUsername -}}
{{- if not (and $.Values.runtimeArtifactCredentialsSecretName (regexMatch "^system:serviceaccount:[a-z0-9][-a-z0-9]*:[a-z0-9][-a-z0-9]*$" .)) -}}
{{- fail "runtimeArtifactCredentialsProjectionUsername requires an exact ServiceAccount and artifact Secret" -}}
{{- end -}}
{{- end -}}
{{- $settings | toJson -}}
{{- end -}}
