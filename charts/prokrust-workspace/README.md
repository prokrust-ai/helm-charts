# Prokrust workspace

Install once per workload namespace after installing the Prokrust CRDs, Argo Workflows and the System chart. Set `installation.namespace` to the System namespace. Enrollment needs access to Kubernetes through `global.networkPolicy.apiServerEndpoints`. The published chart records its verified System release in `supportedSystemVersion`.

## Configure artifact storage

A managed workspace creates `ProkrustPolicy/default`, `ArtifactStore/default` and `BallistaCluster/default`. For an existing S3 bucket, supply the writer and Ballista credentials separately. For example:

```yaml
installation:
  namespace: prokrust-system
workspace:
  storage:
    backend: S3
    bucket: example-team-artifacts
    prefix: team/artifacts/
    region: us-east-1
    auth: {secretName: team-artifact-writer}
    ballistaAuth: {secretName: team-ballista}
```

Create both Secrets in the workspace namespace with keys `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. To use IAM, replace either Secret reference with `{provider: IRSA, roleArn: arn:aws:iam::123456789012:role/team-artifacts}` or `{provider: EKSPodIdentity, roleArn: ...}`. Writer and Ballista credentials must be distinct. The chart annotates its workspace ServiceAccounts for the selected identities. Configure IAM trust or Pod Identity associations and grant the required bucket permissions. Configure the installation-owned application controller and Web API ServiceAccounts for the writer identity when those components access the store.

For GCS with application default credentials, use:

```yaml
workspace:
  storage:
    backend: GCS
    bucket: example-team-artifacts
    prefix: team/artifacts/
    auth: {provider: ADC}
```

Configure cloud workload identity for the writer and Ballista ServiceAccounts. For workload identity federation, use `{provider: Federation, configMapName: writer-federation, configKey: credentials.json, audience: ...}`. Supply a separate `ballistaAuth` using ADC or its own federation ConfigMap. Credential contents stay outside Helm values.

Set `global.networkPolicy.artifactStore.cidrs` to the approved storage endpoint networks. For IAM, configure `global.networkPolicy.awsAuth.enabled` and STS egress, plus `podIdentityAgentEnabled` for Pod Identity. For GCS configure `global.networkPolicy.gcpAuth` metadata and Google API egress. Also configure DNS, API access and `global.imagePullSecrets` for the cluster. These settings depend on the network and installed identity services.

The chart uses release-pinned images, workflow programs, a digest-pinned runtime lock and the shipped Ballista configuration. The policy starts in Qualification mode. Ballista starts on demand with one executor and releases idle compute after 180 seconds. Capacity admission, probes and cloud connectivity still need to succeed in the installed cluster. Enable `serving.enabled` in both System and Workspace when using KServe. Configure `connectors.enabled` and exact `connectionResources` when using connector controllers.

## Give connector runtimes artifact access

A source connector can browse its source before it has permission to read scan plans or stage snapshot results. Configure the artifact identity independently of its source credentials. For example, a BigQuery source can keep Google federation and use a dedicated IRSA role for S3 staging.

In the **System** chart set `connectors.bigquery.runtimeServiceAccountName` to the exact workspace ServiceAccount below. For IRSA, include `sts.amazonaws.com` in `connectors.bigquery.runtimeTokenAudiences` alongside any required source audience. Keep the source token audience and source egress configured on the provider.

In the **Workspace** chart:

```yaml
connectors:
  enabled: true
  artifactAccess:
    bigquery:
      serviceAccount: {name: prokrust-connector-runtime-bigquery, create: true}
      auth: {provider: IRSA, roleArn: arn:aws:iam::123456789012:role/team-connector-stage}
global:
  networkPolicy:
    artifactStore: {cidrs: [192.0.2.0/24], port: 443}
    awsAuth: {enabled: true, stsCIDRs: [198.51.100.12/32]}
```

Replace example CIDRs with the artifact and regional STS destinations for your cluster. Each provider shares its configured runtime account across that provider's connections in this namespace. Bind cloud trust to the exact namespace, account and required token audience. Scope versioned control reads to `<store-prefix>/connector-control/<workspace-uid>/<connection-uid>/` and staging reads/writes to the corresponding `connector-staging` prefix. Include prefix-constrained listing if required for immutable-object absence checks. Give cleanup permissions to the designated cleanup owner. Runtime-access probes remove their current sentinel keys with a normal object delete. On versioned buckets, configure a lifecycle rule for the probe prefixes to expire noncurrent sentinel versions and expired delete markers according to your retention policy. The cleanup identity needs no permission to delete specific object versions (S3 `s3:DeleteObjectVersion`). Final snapshot destinations remain under the publisher identity.

| Artifact credential | Workspace `auth` | Installation configuration |
|---|---|---|
| S3 IRSA | `{provider: IRSA, roleArn: ...}` | Configure role trust, STS token audience and STS egress. |
| EKS Pod Identity | `{provider: EKSPodIdentity, roleArn: ...}` | Associate the role with this ServiceAccount in EKS. Enable `global.networkPolicy.awsAuth.enabled` and `podIdentityAgentEnabled`. Configure the provider's token allowlist for the EKS agent's audience. |
| S3 access keys | `{secretName: prokrust-connector-runtime-artifact-team}` | Set the System provider's `runtimeArtifactCredentialsSecretName` to the same namespace-local Secret. Configure its trusted projection writer when applicable. Provision `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally `AWS_SESSION_TOKEN` through the Secret owner. |
| GCS workload identity | `{provider: ADC}` | Bind the Kubernetes identity in Google Cloud and enable `global.networkPolicy.gcpAuth` with its metadata and Google API endpoints. For GKE service-account impersonation, add `gcpServiceAccount: connector@example.iam.gserviceaccount.com` to `auth`. |

The workspace chart creates a namespace-local egress policy for connector pods identified by their connection UID label. Its destinations come from the existing artifact store and configured credential mode. A same-namespace artifact store selected by pod labels also receives connector ingress. Provider-specific policies continue to supply DNS and source access. When those policies or an external network owner already restrict artifact traffic per provider, set `connectors.artifactNetworkPolicy.enabled: false`. The chart will leave connector artifact egress and the artifact-store ingress peers to that owner. Cloud IAM enforces workspace and object-prefix permissions. Connector runtimes using GCS need ADC supplied to the runtime itself. The workspace worker's federation ConfigMap applies to the worker pods.

**Upgrade an existing installation.** Set `serviceAccount.create: false` to keep the existing ServiceAccount in its current GitOps owner. Apply the role annotation or Pod Identity association there, install the matching Workspace chart, then roll the connector runtime pods through the provider controller so cloud admission injects the credentials. For a fresh installation, `create: true` creates the runtime account with API-token automount disabled. Authorize the installer to manage this protected ServiceAccount in the provider admission policy. Verify source browsing and a fresh snapshot's versioned control read and staging write with the actual runtime identity.

## Authorize provider connections

Under `workspace.connectionRules`, append S3 rules through `rules` or GCS and BigQuery rules through `gcpRules`. Each entry authorizes one connection name and kind for Source or Destination operations. The generated Artifact rule is reserved for the managed store. For example, an S3 workspace exporting to BigQuery can authorize its destination and GCS staging connection together:

```yaml
workspace:
  # Keep the workspace.storage block above.
  connectionRules:
    gcpRules:
      - connectionKind: BigQueryConnection
        connectionName: reports
        purpose: Destination
        serviceAccounts: [prokrust-connection-probe]
        project: analytics-project
        jobProjects: [analytics-project]
        datasets: [reports]
        locations: [US]
      - connectionKind: GCSConnection
        connectionName: export-staging
        purpose: Destination
        serviceAccounts: [prokrust-connection-probe]
        bucket: analytics-export-staging
        allowedPrefixes: [reports/]
```

Create the corresponding connections and select the ready GCS staging connection during export. Include any required federation audiences and explicitly permitted BigQuery write modes on their rules.

## Upgrade and ownership

- Existing, nonempty `tenantDefaults` continues to render full reviewed specs. Use it for qualified-release promotion, custom endpoints or advanced compute settings.
- If existing defaults are owned outside the release, keep that manager and set `workspace.mode: external`. Previous installations with explicitly empty `tenantDefaults: []` also retain their infrastructure-only behavior. An installation that previously omitted these values must record its choice before upgrading. Helm and Argo CD render the same ownership decision.
- Managed storage creates `prokrust-ballista-scheduler` and `prokrust-ballista-executor` ServiceAccounts. If another application already owns them, set `workspace.ballistaAccounts: external` and configure both accounts for `ballistaAuth`. Existing workspace-owned workers receive their writer annotations from Helm.
- Before switching resource owners, drain active workloads and compare the fully rendered manifests. Preserve the default objects and their UIDs. Remove overlapping declarations from the previous manager only with pruning disabled during the transfer. Supply ownership metadata explicitly for a deliberate handoff; the enrollment hook verifies the release-name annotation `prokrust.ai/workspace-chart`, and native Helm checks its release ownership metadata. Switching to external mode while pruning is enabled can delete chart-managed resources.


### Workspace pod placement

The installation administrator authorizes named templates in the system chart's `global.placementTemplates`. The managed workspace chart accepts an exact subset in `workspace.placementTemplates`. Set `workspace.placementDefaults` to choose a default per pod role. Existing full-spec policies use the same fields under `spec.execution`. With external ownership, configure the policy at its source.

```yaml
workspace:
  placementTemplates:
    gpu-training:
      allowedRoles: [trainer]
      nodeSelector:
        workload.example.com/pool: gpu
      tolerations:
        - {key: dedicated, operator: Equal, value: training, effect: NoSchedule}
  placementDefaults:
    trainer: {name: gpu-training}
```

Supply these fields alongside the workspace's storage settings. A workload can choose another template approved for its role. Installation architecture and scheduling constraints still apply. GPU requests and limits are configured separately. Existing frozen workflow attempts retain their pod specification. Ballista changes to immutable scheduling or capacity child templates require explicit cluster replacement.
