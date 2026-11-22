{
  "capabilities": [
    "atomic-source-snapshot",
    "browse",
    "inspect",
    "original-files",
    "probe",
    "source-byte-budget",
    "source-request-budget",
    "source-row-budget",
    "staged-byte-budget"
  ],
  "connectionKinds": [
    {
      "apiVersion": "sources.prokrust.ai/v1beta1",
      "kind": "SyntheticConnection",
      "plural": "syntheticconnections",
      "schema": {
        "file": "connection-v1.json",
        "sha256": "sha256:{{ .Files.Get "files/registry/connection-v1.json" | sha256sum }}"
      },
      "scope": "Namespaced"
    }
  ],
  "connectorProtocolMajor": 1,
  "formatVersion": 1,
  "providerId": "prokrust.ai/synthetic",
  "providerMajor": {{ first (splitList "." .Chart.AppVersion) | int }},
  "release": "{{ .Chart.AppVersion }}",
  "runtimeImages": [
    {
      "digest": "{{ last (splitList "@" .Values.runtimeImage) }}",
      "role": "runtime"
    },
    {
      "digest": "{{ last (splitList "@" .Values.controllerImage) }}",
      "role": "controller"
    }
  ],
  "selectorSchemas": [
    {
      "defaultForNew": true,
      "file": "selector-v1.json",
      "schemaVersion": "v1",
      "sha256": "sha256:{{ .Files.Get "files/registry/selector-v1.json" | sha256sum }}"
    }
  ],
  "ui": {
    "displayName": "Synthetic Events"
  }
}
