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
