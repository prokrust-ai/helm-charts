# ballista Helm chart

Published independently as `oci://ar.prokrust.io/charts/ballista`. Initial chart version `0.1.0-rc.1`. Images use immutable digest references under `ar.prokrust.io/prokrust`. Replace zero digest placeholders with composition-generated values before installation.

Shared namespace configuration: `global.imagePullSecrets` and `global.networkPolicy`. Secrets must already exist in the release namespace. The operator umbrella pins child chart versions; install either umbrella or individual charts once per namespace to avoid duplicate ownership.

## Network family and IPv6 CIDRs

`global.networkFamily` accepts `IPv4` (default) or `IPv6`. Set the same profile
across installation charts. CIDR allowlists accept validated IPv4/IPv6 ranges;
GCP metadata constraints remain provider-specific. External connectivity and
IPv6-only runtime qualification are separate requirements.
Operator selects the network family for generated runtime workloads.
