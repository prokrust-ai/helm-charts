{{- define "workspace.managed" -}}
{{- $workspace := .Values.workspace | default dict -}}
{{- if and .Values.tenantDefaults (eq $workspace.mode "external") }}{{ fail "external mode cannot own tenantDefaults" }}{{ end -}}
{{- if and $workspace.connectionRules (not $workspace.storage) }}{{ fail "workspace.connectionRules requires managed workspace.storage" }}{{ end -}}
{{- if $workspace.storage -}}
  {{- if or (eq $workspace.mode "external") .Values.tenantDefaults }}{{ fail "workspace.storage cannot be combined with external ownership or tenantDefaults" }}{{ end -}}
  true
{{- else if eq $workspace.mode "managed" -}}
  {{- fail "workspace.mode=managed requires workspace.storage" -}}
{{- else if and (ne $workspace.mode "external") (not (hasKey .Values "tenantDefaults")) -}}
  {{- fail "Set workspace.storage to configure the workspace, or workspace.mode=external to manage its policy, store and compute separately" -}}
{{- end -}}
{{- end -}}

{{- define "workspace.workers" -}}
{{- $workers := list "prokrust-connection-probe" "prokrust-artifact-store-probe" "prokrust-table-staging" "prokrust-table-materializer" "prokrust-graph-materializer" "prokrust-training-materializer" "prokrust-prediction-materializer" "prokrust-artifact-writer" "prokrust-trainer" "prokrust-batch-predictor" -}}
{{- if .Values.serving.enabled }}{{ $workers = append $workers "prokrust-kserve-runtime" }}{{ end -}}
{{- toJson $workers -}}
{{- end -}}

{{- define "workspace.storageAccountAnnotations" -}}
{{- if eq .provider "IRSA" }}
eks.amazonaws.com/role-arn: {{ .roleArn | quote }}
{{- else if eq .provider "EKSPodIdentity" }}
prokrust.ai/aws-identity-provider: EKSPodIdentity
prokrust.ai/aws-role-arn: {{ .roleArn | quote }}
{{- end -}}
{{- end -}}

{{- define "workspace.storageAuth" -}}
{{- if .secretName -}}
type: Secret
secretRef:
  name: {{ .secretName | quote }}
  accessKeyIdKey: AWS_ACCESS_KEY_ID
  secretAccessKeyKey: AWS_SECRET_ACCESS_KEY
{{- else if has .provider (list "IRSA" "EKSPodIdentity") -}}
type: WorkloadIdentity
workloadIdentity:
  provider: {{ .provider }}
  roleArn: {{ .roleArn | quote }}
{{- else if eq .provider "Federation" -}}
federation:
  configMapRef: {name: {{ .configMapName | quote }} }
  configKey: {{ .configKey | quote }}
  audience: {{ .audience | quote }}
{{- else if eq .provider "ADC" -}}
{}
{{- else -}}
{{- fail "Unsupported workspace storage auth provider" -}}
{{- end -}}
{{- end -}}

{{- define "workspace.storageObjects" -}}
{{- $s := .Values.workspace.storage -}}
{{- $writer := $s.auth -}}
{{- $worker := $s.ballistaAuth | default (dict "provider" "ADC") -}}
{{- $writerAuth := include "workspace.storageAuth" $writer | fromYaml -}}
{{- $workerAuth := include "workspace.storageAuth" $worker | fromYaml -}}
{{- $accounts := append (include "workspace.workers" . | fromJsonArray) "prokrust-workflow-executor" -}}
{{- $ballistaAccounts := list "prokrust-ballista-scheduler" "prokrust-ballista-executor" -}}
{{- $common := dict "bucket" $s.bucket "prefix" $s.prefix "auth" $writerAuth "serviceAccountName" "prokrust-artifact-store-probe" -}}
{{- $policy := .Files.Get "files/workspace/policy.yaml" | fromYaml -}}
{{- $connections := dict "rules" (list) -}}
{{- /* Policy authorizes the same credential references that the store will present. */ -}}
{{- $profile := "aws" -}}
{{- if eq $s.backend "S3" -}}
  {{- if not $s.ballistaAuth }}{{ fail "S3 needs separate auth and ballistaAuth credentials" }}{{ end -}}
  {{- if or (and $writer.secretName (eq $writer.secretName $worker.secretName)) (and $writer.roleArn (eq $writer.roleArn $worker.roleArn)) }}{{ fail "S3 writer and Ballista need distinct credentials" }}{{ end -}}
  {{- $suffix := ternary "amazonaws.com.cn" "amazonaws.com" (hasPrefix "cn-" $s.region) -}}
  {{- $partition := ternary "aws-cn" (ternary "aws-us-gov" "aws" (hasPrefix "us-gov-" $s.region)) (hasPrefix "cn-" $s.region) -}}
  {{- range list $writer $worker -}}
    {{- if and .roleArn (not (hasPrefix (printf "arn:%s:iam::" $partition) .roleArn)) }}{{ fail "IAM role partition must match the S3 region" }}{{ end -}}
  {{- end -}}
  {{- $origin := printf "https://s3.dualstack.%s.%s" $s.region $suffix -}}
  {{- $_ := set $common "region" $s.region -}}
  {{- $_ := set $common "tls" (dict "verify" true) -}}
  {{- $_ := set $common "forcePathStyle" false -}}
  {{- $bindings := list -}}{{- $secrets := list -}}
  {{- range $part := list (dict "auth" $writer "accounts" $accounts "host" true) (dict "auth" $worker "accounts" $ballistaAccounts) -}}
    {{- if $part.auth.secretName -}}
      {{- $secrets = append $secrets ((include "workspace.storageAuth" $part.auth | fromYaml).secretRef) -}}
    {{- else -}}
      {{- $identity := pick $part.auth "provider" "roleArn" -}}
      {{- range $part.accounts }}{{ $bindings = append $bindings (merge (dict "serviceAccount" . "namespace" $.Release.Namespace) $identity) }}{{ end -}}
      {{- if $part.host -}}
        {{- range list "prokrust-application-controller" "prokrust-web-api" }}{{ $bindings = append $bindings (merge (dict "namespace" $.Values.installation.namespace "serviceAccount" .) $identity) }}{{ end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $endpoint := dict "origin" $origin "allowRedirects" false "allowedResolvedCidrs" .Values.global.networkPolicy.artifactStore.cidrs "denyCidrs" (list "0.0.0.0/8" "127.0.0.0/8" "169.254.0.0/16" "224.0.0.0/4" "::/128" "::1/128" "fe80::/10") -}}
  {{- $rule := dict "connectionName" "default" "purpose" "Artifact" "endpoint" $endpoint "bucket" $s.bucket "allowedPrefixes" (list $s.prefix) "forcePathStyle" false "auth" (dict "secretRefs" $secrets "serviceAccounts" (concat $accounts $ballistaAccounts) "workloadIdentityBindings" $bindings) -}}
  {{- $_ := set $connections "rules" (list $rule) -}}
{{- else -}}
  {{- $profile = "gcp-s3-compatible" -}}
  {{- if and (eq $writer.provider "Federation") (not $s.ballistaAuth) }}{{ fail "GCS federation requires explicit separate ballistaAuth" }}{{ end -}}
  {{- if and $writer.configMapName (eq $writer.configMapName $worker.configMapName) }}{{ fail "Writer and Ballista federation must use distinct ConfigMaps" }}{{ end -}}
  {{- $maps := list -}}{{- $audiences := list -}}
  {{- range list $writer $worker }}{{ if eq .provider "Federation" }}{{ $maps = append $maps .configMapName }}{{ $audiences = append $audiences .audience }}{{ end }}{{ end -}}
  {{- $rule := dict "connectionName" "default" "connectionKind" "GCSConnection" "purpose" "Artifact" "serviceAccounts" (concat $accounts $ballistaAccounts) "bucket" $s.bucket "allowedPrefixes" (list $s.prefix) "federationConfigMaps" ($maps | uniq) "federationAudiences" ($audiences | uniq) -}}
  {{- $_ := set $connections "gcpRules" (list $rule) -}}
{{- end -}}
{{- /* Providers key policy by kind and connection name; each lookup must be unique. */ -}}
{{- $seen := dict (printf "%sConnection/default" $s.backend) true -}}
{{- range $key, $rules := .Values.workspace.connectionRules -}}
  {{- range $rule := $rules -}}
    {{- $kind := "S3Connection" -}}
    {{- if eq $key "gcpRules" -}}
      {{- $kind = $rule.connectionKind -}}
      {{- if not (has $kind (list "GCSConnection" "BigQueryConnection")) }}{{ fail "gcpRules requires GCSConnection or BigQueryConnection" }}{{ end -}}
    {{- end -}}
    {{- $identity := printf "%s/%s" $kind $rule.connectionName -}}
    {{- if or (hasKey $seen $identity) (not (has $rule.purpose (list "Source" "Destination"))) -}}
      {{- fail (printf "Additional connection %s must be unique and have Source or Destination purpose" $identity) -}}
    {{- end -}}
    {{- $_ := set $seen $identity true -}}
    {{- $_ := set $connections $key (append (get $connections $key | default list) $rule) -}}
  {{- end -}}
{{- end -}}
{{- $backend := lower $s.backend -}}
{{- $store := dict "publication" "ManifestLast" "retentionPolicy" "Retain" "storage" (dict "backend" $s.backend $backend $common) "ballistaAuth" (dict "backend" $s.backend $backend $workerAuth) -}}
{{- $_ := set $policy "authorization" (dict "connectionProfile" $profile "connections" $connections) -}}
{{- /* Release composition supplies the operator, worker images, Ballista build and lock reference. */ -}}
{{- $release := required "Managed workspaces need a release-prepared chart with verified runtime pins" (.Files.Get "files/workspace-release.json") | fromJson -}}
{{- $images := dict "operator" $release.operatorImage "modelServer" (include "operator.image" .Values.serving.images.modelServer) -}}
{{- range $name := list "data-job" "trainer" "batch-predictor" "ballista" -}}
  {{- range $key, $image := (index $.Values $name).images }}{{ $_ := set $images $key (include "operator.image" $image) }}{{ end -}}
{{- end -}}
{{- range $key, $image := $images -}}
  {{- if or (ne $image (index $release.images $key)) (not (regexMatch "@sha256:[0-9a-f]{64}$" $image)) (hasSuffix (repeat 64 "0") $image) -}}
    {{- fail (printf "Managed workspace image %s must match the verified workspace runtime lock" $key) -}}
  {{- end -}}
{{- end -}}
{{- $_ := set $policy.execution "images" $images -}}
{{- $_ := set $policy.execution "release" (dict "mode" "Qualification" "lock" $release.lock) -}}
{{- $_ := set $policy.execution.controller "conversionParallelism" .Values.conversionSemaphore.limit -}}
{{- $runtime := include "operator.servingRuntimeObject" . | fromYaml -}}
{{- $runtimeDigest := sha256sum (toJson (dict "apiVersion" $runtime.apiVersion "kind" $runtime.kind "namespace" .Release.Namespace "spec" $runtime.spec)) -}}
{{- $_ := set $policy.execution "serving" (dict "runtime" (dict "name" (printf "prokrust-serving-v1-%s" (trunc 12 $runtimeDigest)) "specDigest" (printf "sha256:%s" $runtimeDigest)) "autoscalerClass" "HPA" "deploymentMode" "Standard" "storageHelperDisabled" true "clusterLocal" true) -}}
{{- $ballista := dict "clusterName" "default" "release" $release.ballista.upstreamTag "configurationDigest" (printf "sha256:%s" $release.ballista.configurationSha256) "crateVersions" $release.ballista.crateVersions "upstreamCommit" $release.ballista.upstreamCommit "maxConcurrentProducers" .Values.producerSemaphore.limit "serviceAccounts" (dict "scheduler" (first $ballistaAccounts) "executor" (last $ballistaAccounts)) "ports" (dict "workflowGrpc" 50050 "workflowRest" 50050 "executorFlight" 50051 "executorShuffle" 50052) -}}
{{- $_ := set $policy.execution "ballista" $ballista -}}
{{- $cluster := .Files.Get "files/workspace/ballista.yaml" | fromYaml -}}
{{- $_ := set $cluster "maxConcurrentProducers" .Values.producerSemaphore.limit -}}
{{- $_ := set $cluster "release" $ballista.release -}}
{{- $_ := set $cluster "schedulerImage" $images.ballistaScheduler -}}
{{- $_ := set $cluster "executorImage" $images.ballistaExecutor -}}
{{- dict "namespace" .Release.Namespace "artifactStore" $store "ballistaCluster" $cluster "policy" $policy | toJson -}}
{{- end -}}
