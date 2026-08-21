# PowerDNS + Poweradmin Helm chart

A small production-oriented Helm chart for a native Kubernetes/Kubespray cluster.

## Versions

| Component | Version | Notes |
|---|---:|---|
| PowerDNS Authoritative | **5.1.4** | Current 5.1 patch release; PostgreSQL/gpgsql backend and API supported. |
| Poweradmin | **4.4.0** | Current release; supports PowerDNS 4.x/5.x and API backend. |
| PostgreSQL | **18.4** | Current PostgreSQL 18 minor used by the current CNPG 1.30 line. |
| CloudNativePG Operator | **1.30.0** | Current supported CNPG minor; Helm chart **0.29.0**. |
| Gateway API | **v1** resources | Gateway/CRDs are platform-managed by the existing Envoy Gateway installation. |

At the time this chart was updated (2026-08-21), PowerDNS 5.1.4 and Poweradmin 4.4.0 are the current application releases used here. CNPG 1.30.0 is the current supported operator minor and uses PostgreSQL 18.4 as the supported image line.

## Why this layout

```text
Internet
  |
  +-- UDP/TCP :53 --> Service type=LoadBalancer --> PowerDNS x2
  |
  +-- HTTPS --> existing Envoy Gateway --> HTTPRoute --> Poweradmin x2
                                      |
                                      +--> PowerDNS API :8081

PowerDNS x2 -----------+
                       +--> CNPG PostgreSQL x3
Poweradmin x2 ---------+
```

The chart does **not** install:

- Envoy Gateway
- Gateway API CRDs
- CloudNativePG Operator
- MetalLB

Those are platform responsibilities and are expected to already exist.

## Prerequisites

- Kubernetes **1.34-1.36** for the default CNPG 1.30 design.
- CloudNativePG Operator **1.30.0** already installed.
- Envoy Gateway + Gateway API CRDs already installed.
- A working `Service type=LoadBalancer` implementation that supports **both UDP and TCP 53**.
- At least two Kubernetes nodes for the default PowerDNS/Poweradmin scheduling rules; three nodes are recommended for the 3-instance PostgreSQL cluster.

CNPG 1.30 is the reason the chart targets Kubernetes 1.34+. It uses the `DatabaseRole` resource for declarative role management.

## Install CloudNativePG

The CNPG operator Helm chart version is **0.29.0**, whose application version is **1.30.0**:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm upgrade --install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  --version 0.29.0 \
  cnpg/cloudnative-pg
```

The chart and operator versions are different numbers; do not use `--version 1.30.0` for the Helm chart.

## Install this chart

```bash
helm upgrade --install dns ./powerdns-poweradmin \
  --namespace dns-system \
  --create-namespace \
  -f examples/values-prod.yaml
```

## Envoy Gateway

This chart intentionally follows the platform/app separation:

- platform team owns `Gateway`
- this application chart owns `HTTPRoute`

The default Route references:

```yaml
gateway:
  enabled: true
  existingGateway:
    name: public-gateway
    namespace: envoy-gateway-system
    sectionName: https
  hostname: poweradmin.example.com
```

Because the Gateway is cross-namespace, its HTTPS listener must explicitly allow HTTPRoutes from `dns-system` (for example with `allowedRoutes.namespaces.from: Selector` and a namespace label, or `All`). Gateway API requires this for cross-namespace attachment.

Example platform-side listener policy:

```yaml
allowedRoutes:
  namespaces:
    from: Selector
    selector:
      matchLabels:
        kubernetes.io/metadata.name: dns-system
```

Do not expose the PowerDNS API through the Gateway. It remains a ClusterIP service on TCP 8081.

## PowerDNS PostgreSQL schema

PowerDNS uses the Generic PostgreSQL (`gpgsql`) backend. The chart applies the official PostgreSQL backend schema to the `pdns` database using an idempotent post-install/post-upgrade Job. This is intentional because the CNPG `Database` resource creates the database itself; the application schema then has to be applied after the database is available.

The schema includes DNSSEC-related tables (`cryptokeys`, `domainmetadata`) as required for `gpgsql-dnssec=yes`.

## Poweradmin integration

Poweradmin runs in API backend mode:

```text
Poweradmin --> PowerDNS HTTP API --> PowerDNS --> PostgreSQL
```

Poweradmin therefore does not need direct database access to the PowerDNS database.

## Secrets

For production GitOps, prefer External Secrets / SOPS / another secret manager and point the chart to existing Secrets.

### Application secret

```yaml
secrets:
  existingSecret: powerdns-poweradmin-credentials
```

Required keys:

- `pdns-api-key`
- `poweradmin-admin-password`
- `poweradmin-session-key`

### CNPG role secrets

```yaml
postgresql:
  roles:
    pdns:
      existingSecret: powerdns-poweradmin-pdns-db
    poweradmin:
      existingSecret: powerdns-poweradmin-poweradmin-db
```

Each role Secret must be `kubernetes.io/basic-auth` with `username` and `password` keys.

## Production recommendations

- Use two or more PowerDNS replicas across nodes/failure domains.
- Keep the DNS Service as `LoadBalancer` and expose both UDP/TCP 53.
- Keep PowerDNS API as ClusterIP only.
- Use at least 3 CNPG instances across 3 nodes for PostgreSQL HA.
- Configure CNPG backups before calling the deployment production-ready.
- Use separate external DNS failure domains for `ns1` and `ns2`; two Pods in one K8s cluster are not disaster redundancy.
- Replace broad `powerdns.api.allowFrom` CIDRs with the real Pod CIDRs of the cluster.
- Pin image digests after acceptance testing if your supply-chain policy requires immutable artifacts.
