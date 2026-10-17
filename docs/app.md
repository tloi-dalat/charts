# The `app` chart

One workload and what it needs. Every key is overridable from an app's `values.yaml` in control-plane; raw
Kubernetes structures (probes, volumes, NetworkPolicy rules, security contexts) pass through unchanged.

| Renders | When |
|---|---|
| `Deployment` or `StatefulSet` | always (`kind`) |
| `Service` | `ports` set and `service.enabled` (default) |
| `NetworkPolicy` | `networkPolicy.enabled` |
| `HorizontalPodAutoscaler` | `autoscaling.enabled`; the workload then has no `spec.replicas`, so ArgoCD doesn't fight the HPA |
| `Job` (ArgoCD PreSync hook) | `migrate.enabled`; runs before the workload updates. On failure the sync stops and old pods keep serving |

## Values

| Key | Default | Notes |
|---|---|---|
| `nameOverride` | `""` | Resource names default to the release name |
| `kind` | `Deployment` | `StatefulSet` for a stable identity per pod (judges) |
| `replicaCount` | `1` | Ignored when autoscaling is on |
| `autoscaling.*` | off, 2–4, CPU 70% | Targets are % of `resources.requests`, so set requests to one pod's real steady load. Leave `targetMemoryUtilizationPercentage` null for gunicorn/celery (their memory never drops). `behavior`: raw autoscaling/v2 policies. Stateless workloads only |
| `image.repository`, `image.tag` | | Required. `image.digest` optionally pins the exact image |
| `command`, `args` | `[]` | |
| `env` | `{}` | A map. Literals become strings; `{valueFrom: …}` passes through |
| `envFrom` | `[]` | |
| `ports` | `[]` | `[{name, containerPort, protocol?}]`, also the Service ports |
| `service` | enabled, `ClusterIP` | |
| `probes.liveness/readiness/startup` | `{}` | Raw probe specs |
| `resources`, `podSecurityContext` | `{}` | |
| `securityContext` | `allowPrivilegeEscalation: false` | |
| `automountServiceAccountToken` | `false` | Nothing calls the Kubernetes API, and the judge runs untrusted code. `enableServiceLinks` is always off |
| `strategy` | `{}` | Deployment only |
| `nodeSelector`, `tolerations`, `affinity`, `podLabels`, `podAnnotations` | empty | |
| `volumes`, `volumeMounts` | `[]` | Raw |
| `networkPolicy` | off | `ingress` / `egress`: raw rule lists; `[]` denies all |
| `migrate` | off | `command`, `resources`, `activeDeadlineSeconds: 900`, `backoffLimit: 0` (MySQL DDL isn't transactional; read the logs instead of re-running). Its pods don't carry the workload's labels, so the Service never routes to them |

## Use from control-plane

```yaml
helmGlobals: { chartHome: /tmp/charts }
helmCharts:
  - repo: oci://ghcr.io/tloi-dalat/charts
    name: app
    version: 0.2.1
    releaseName: online-judge-site
    namespace: online-judge
    valuesFile: values.yaml
```

ArgoCD needs `kustomize.buildOptions: --enable-helm`.

## Release

1. Change the chart and bump `version` in `Chart.yaml`. Published versions are immutable: control-plane pins them.
2. Add or adjust a `ci/*-values.yaml` file for a new shape; CI lints and renders each one.
3. Merge. The publish workflow pushes any version not yet on GHCR, and fails if a published version's files
   changed without a bump.
4. Bump `version` in the control-plane kustomizations that should use it.

The `charts/app` package must be public on GHCR: ArgoCD pulls it without credentials.
