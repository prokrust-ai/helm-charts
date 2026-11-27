# prokrust-system

Install into a dedicated system namespace; this chart uses fixed resource names and a default-deny network policy.

Installation controllers and Web API for Prokrust. Install the matching
`prokrust-crds` release first; create workspaces with `prokrust-workspace`.
Web API is included in this chart; no separate Web API chart installation is required.

Requires Kubernetes 1.35–1.37, ARM64 nodes, cert-manager, and Argo Workflows.
The Kubernetes range follows the bundled kubectl 1.36 client's
[supported version skew](https://kubernetes.io/releases/version-skew-policy/#kubectl).
Provide registry pull credentials, licensing Secrets, and cluster-specific
network access through values. Controller requests and limits are configurable
under `controllers.applicationResources` and `controllers.ballistaClusterResources`.

## Install connectors with Helm

Install the matching provider CRDs with `prokrust-crds`. Enable
`connectors.discovery.enabled` in the System release. Each entry of
`connectors.discovery.providers` names a trusted provider that System can
load. The default list contains `bigquery`, `gcs`, `iceberg`, `paimon`, `s3`,
and `synthetic`. An empty installation works with discovery enabled.

Install one provider release per provider in the System namespace. Pin the
chart version on that release. For example, with installation-specific values
in `bigquery-values.yaml`:

```sh
helm upgrade --install connector-bigquery oci://ar.prokrust.io/charts/connector-bigquery \
  --namespace prokrust-system --version 1.5.0-rc.2 --values bigquery-values.yaml
```

Configure controller pull credentials, API server endpoints, workspace RBAC,
runtime identity and network access on the provider release. Enroll workspaces
and enable their connector access in the Workspace chart. Each provider chart
installs its controller and the descriptor, digest and schemas in its
`prokrust-connector-<provider>-registry` ConfigMap. Operator and Web API read
updates when Kubernetes refreshes their mounted volumes. To upgrade, repeat
the provider command with a compatible new chart version. Drain accepted work
before removing a provider release.

Restrict write access to the installation namespace. Discovery adds an
admission check for creates, updates and deletes of trusted registry ConfigMaps.
The Helm installer needs regular write permissions for the provider resources
and the `register` verb for that provider's ConfigMap. Cluster administrators
already have both. A namespace administrator can grant the additional
permission by binding the `prokrust-connector-registry-writer` Role to trusted
provider installers, or create a narrower Role restricted to one ConfigMap.
Verify any pre-existing trusted ConfigMaps before enabling discovery.

For an existing aggregate registry, keep `connectors.enabled`,
`connectors.registryConfigMap`, `connectors.registryItems` and the corresponding
Web API values. To switch to discovery, remove those aggregate registry settings.

## Move bundled providers to standalone Helm releases

Use Helm 3.17 or newer from the Helm 3 series and Python 3 with PyYAML for
this one-time ownership handoff. Coordinate it with anyone managing these
resources. Drain active connector work and keep the old System chart, its
values and the exact component chart versions for recovery. The provider data
and controller names must survive the transfer.

1. Save the installed System manifest and effective values. For each enabled
   provider, copy its values under `connectors.<provider>` into a separate
   values file, removing the old `enabled` switch and preserving inherited
   settings. Render the standalone chart at **the same chart version** as the
   bundled dependency, in the same namespace with release name
   `connector-<provider>`. Compare the resource kinds, namespaces, names,
   immutable fields, selectors and RBAC bindings to the installed manifest.
   Long namespace names can produce different truncated names. Resolve every
   mismatch before transferring ownership.
2. Extract `files/migration/retain-bundled-connectors.py` from the new System
   chart and make it executable. Upgrade the **currently installed, bundled**
   System chart at its original version with the same release name and values:

   ```sh
   helm upgrade "$SYSTEM_RELEASE" oci://ar.prokrust.io/charts/prokrust-system \
     --namespace "$SYSTEM_NAMESPACE" --version "$BUNDLED_VERSION" --reuse-values \
     --post-renderer ./retain-bundled-connectors.py
   ```

   Check `helm get manifest` and live metadata. Every enabled provider resource
   must now carry `helm.sh/resource-policy: keep`. Verify that all other
   resources retain their original policies. This bridge revision lets Helm
   retain those objects when the dependency disappears on the next upgrade.
3. Prepare the new System values from the installation configuration. Remove
   all old `connectors.<provider>` blocks and enable discovery. Upgrade to
   the split System chart using `--reset-values --values system-values.yaml`
   to avoid carrying obsolete provider keys forward. Verify the System
   manifest no longer owns provider objects and that they are still present.
4. Run the standalone Helm install command above for each provider, adding
   `--take-ownership` and using the verified version and values from step 1.
   Verify every expected object belongs to the new release, that each provider
   controller is Ready and that Operator and Web API see its descriptor.
   Compare provider object UIDs with the saved live UIDs. Helm 3 can leave the
   bridge's keep annotation on the live object after adoption. Clear it before
   relying on uninstall.

Save this cleanup helper as `clear-bridge-keep.py`. It acts on the supplied
manifest inventory and tests the expected Helm owner and resource version
before removing the live annotation. For a forward transfer, run it once per
provider, for example:

```sh
helm get manifest connector-bigquery -n "$SYSTEM_NAMESPACE" > bigquery-inventory.yaml
python3 clear-bridge-keep.py connector-bigquery "$SYSTEM_NAMESPACE" bigquery-inventory.yaml
```

```python
import json
from pathlib import Path
import subprocess
import sys

import yaml

release, namespace, inventory = sys.argv[1:]
for obj in yaml.safe_load_all(Path(inventory).read_text()):
    if not obj:
        continue
    meta = obj["metadata"]
    group, _, _ = obj["apiVersion"].rpartition("/")
    resource = obj["kind"] + ("." + group if group else "") + "/" + meta["name"]
    # Workspace RoleBindings can be in a different namespace. kubectl also
    # resolves cluster-scoped resources when given a namespace default.
    command = ["kubectl", "--namespace", meta.get("namespace", namespace)]
    live = json.loads(subprocess.check_output(command + ["get", resource, "-o", "json"]))["metadata"]
    annotations = live.get("annotations", {})
    if (annotations.get("meta.helm.sh/release-name"), annotations.get("meta.helm.sh/release-namespace")) != (release, namespace):
        sys.exit(f"Unexpected owner of {resource} in {meta.get('namespace', namespace)}")
    if annotations.get("helm.sh/resource-policy") == "keep":
        subprocess.run(command + ["annotate", resource, "--resource-version=" + live["resourceVersion"],
                                  "helm.sh/resource-policy-"], check=True)
```

### Reverse the ownership transfer

Roll back ordinary connector upgrades with the provider release's `helm rollback`.
To return to a bundled System version:

1. Drain connector work, save all six or fewer standalone manifests as
   inventories, and verify the old System render has identical names, scopes,
   selectors and controller images. Restore the original provider values and
   versions in the old System values file.
2. Create the post-renderer below and run one bridge upgrade per standalone
   release, using its **current** chart version and release name. Each release's
   bridge manifest must retain every object in its saved inventory.

   ```sh
   cat > retain-provider <<'PYTHON'
   #!/usr/bin/env python3
   import sys
   import yaml
   objects = [o for o in yaml.safe_load_all(sys.stdin) if o]
   if not objects:
       sys.exit("No provider objects found")
   for obj in objects:
       obj["metadata"].setdefault("annotations", {})["helm.sh/resource-policy"] = "keep"
   yaml.safe_dump_all(objects, sys.stdout, sort_keys=False, explicit_start=True)
   PYTHON
   chmod +x retain-provider
   helm upgrade "$CONNECTOR_RELEASE" "oci://ar.prokrust.io/charts/$CONNECTOR_RELEASE" \
     -n "$SYSTEM_NAMESPACE" --version "$CONNECTOR_VERSION" --reuse-values --post-renderer ./retain-provider
   ```

3. Verify both the bridge revision (`helm get manifest`) and the live objects
   carry the keep policy. Uninstall each standalone release with
   `helm uninstall "$CONNECTOR_RELEASE" -n "$SYSTEM_NAMESPACE" --keep-history`.
   Confirm that the inventoried objects still exist with their original UIDs.
4. Reinstall the old dependency layout into the existing System release:

   ```sh
   helm upgrade "$SYSTEM_RELEASE" oci://ar.prokrust.io/charts/prokrust-system \
     -n "$SYSTEM_NAMESPACE" --version "$BUNDLED_VERSION" --reset-values \
     --values bundled-values.yaml --take-ownership
   ```

5. Verify System now owns the same provider object UIDs. Clean the temporary
   live policies for each saved provider inventory, this time passing
   `"$SYSTEM_RELEASE"` as the expected owner. Check provider readiness, registry
   contents and a representative connection.

Kustomize users can pin each provider's chart version and values in its own
`helmCharts` entry. Preserve release names, namespaces, resource identities and
the existing GitOps application ownership when changing the render inputs.
Kustomize renders manifests and has no Helm release history to transfer.

## License activation during uninstall

A plain `helm uninstall` runs a pre-delete Job that releases this installation's
activation slot using its existing signing key. Installs, upgrades and rollbacks
leave the slot in place. Helm also runs uninstall when cleaning up a failed
first install with `--atomic`. If the installation never acquired a slot, the
Job succeeds without contacting the license server.

For an active installation the Job waits for vendor acknowledgement before Helm
deletes resources. Once teardown starts the controller stops activating and
reserving new licensed work. After an outage or a failed Job, keep the
installation identity, activation and entitlement Secret, restore connectivity
to the Kubernetes API and license endpoint, then retry `helm uninstall`. The
retry reuses the saved challenge after a lost response. A subsequent install
can activate again with the retained identity. For deliberate offline removal,
record the installation and activation IDs, then use `helm uninstall --no-hooks`.
Contact the license administrator to release that slot separately.

For Kustomize-rendered charts managed by Argo CD, use `leaseBootstrap.mode: argo`
and set `licensing.uninstall.argoApplication` to the owning Application:

```yaml
licensing:
  uninstall:
    argoApplication:
      namespace: argocd
      name: prokrust-system
```

Argo CD 3.5.3 recognizes the rendered Helm pre-delete annotation. The Job
requires a deletion timestamp and an Argo resource-cascade finalizer on that
exact Application. Normal syncs and orphan deletion preserve the activation.
If the Application already disappeared during orphan deletion, the Job also
succeeds without contacting the vendor. Permission and connection errors block
the Job before any licensing call. Argo mode
without an Application binding omits the uninstall hook. When applying plain
YAML with a tool that does not implement hooks, exclude Helm hooks during
rendering. With Kustomize, set `skipHooks: true` on the System `helmCharts` entry
when applying the output directly to Kubernetes.
