# charts

Helm charts shared by every TLOI service, published to `oci://ghcr.io/tloi-dalat/charts`. One generic chart means each app's config in control-plane is a short `values.yaml`, not a pile of manifests.

## `app`

Renders one workload and what it needs:

| Template | When |
|---|---|
| `Deployment` or `StatefulSet` | always (`kind:`) |
| `Service` | when `ports` is set and `service.enabled` (default) |
| `NetworkPolicy` | `networkPolicy.enabled` |
| `Job` (ArgoCD **PreSync** hook) | `migrate.enabled`: runs to completion before the workload updates; on failure the sync stops and old pods keep serving |

All options, with comments, are in [`charts/app/values.yaml`](charts/app/values.yaml). Raw Kubernetes
structures (probes, volumes, NetworkPolicy rules, security contexts) pass through unchanged.

Defaults worth knowing:

- `automountServiceAccountToken: false` and `enableServiceLinks: false` on every pod. Nothing here
  calls the Kubernetes API, and the judge runs untrusted code.
- `securityContext.allowPrivilegeEscalation: false`.
- `env` is a **map**. Literals become strings, and `{valueFrom: …}` passes through.
- `migrate.backoffLimit: 0`. MySQL DDL isn't transactional, so a migration that died halfway
  shouldn't be blindly re-run. Read the logs.

### Use from control-plane

```yaml
# clusters/dev/oj/site/kustomization.yaml
helmGlobals: { chartHome: /tmp/charts }
helmCharts:
  - repo: oci://ghcr.io/tloi-dalat/charts
    name: app
    version: 0.1.0          # always pin
    releaseName: oj-site    # → resource names, Service DNS name
    namespace: oj
    valuesFile: values.yaml
```

ArgoCD must have `kustomize.buildOptions: --enable-helm` (set in control-plane's bootstrap).

## Releasing

1. Change the chart **and bump `version` in `Chart.yaml`**.
2. Add or adjust a `ci/*.yaml` values file if the change adds a new shape. CI lints and renders each one.
3. Merge. The publish workflow pushes any version not yet on GHCR, and fails if a published version's
   files changed (versions are immutable because control-plane pins them).
4. Bump `version:` in the control-plane kustomizations that should pick it up.

Make the `charts/app` package **public** on GHCR (Package settings → Change visibility).
ArgoCD's kustomize-helm pull uses no registry credentials.
