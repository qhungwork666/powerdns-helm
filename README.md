# PowerDNS + Poweradmin Helm chart

A deliberately small Helm chart for Kubernetes-native deployments:

- PowerDNS Authoritative 5.0.x
- Poweradmin 4.3.x
- CloudNativePG PostgreSQL
- Public DNS via `Service type: LoadBalancer` using the cluster's existing LB
- Poweradmin via ClusterIP + optional Ingress
- Poweradmin talks to PowerDNS through the PowerDNS REST API
- PostgreSQL is not exposed outside the cluster

## Design choices

The CNPG operator is **not** bundled as a Helm dependency. Install and lifecycle-manage the operator separately; this application chart only creates CNPG custom resources. That keeps cluster-scoped operator upgrades decoupled from the application release.

PowerDNS runs two replicas by default. The DNS service exposes both UDP/53 and TCP/53. The PowerDNS API remains internal as a ClusterIP service.

Poweradmin uses its own PostgreSQL database and talks to PowerDNS through the API backend. This avoids granting Poweradmin direct access to the PowerDNS database.

## Prerequisites

1. Kubernetes cluster.
2. Existing implementation for `Service type: LoadBalancer`.
3. Ingress controller if `poweradmin.ingress.enabled=true`.
4. CloudNativePG operator installed.
5. A StorageClass suitable for PostgreSQL.

## Install CNPG operator

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace
```

Pin the operator/chart version according to your platform standard.

## Configure

At minimum change:

```yaml
secrets:
  postgres:
    pdnsPassword: <random>
    poweradminPassword: <random>
  powerdns:
    apiKey: <random>
  poweradmin:
    adminPassword: <random>
    sessionKey: <random>

dns:
  ns1: ns1.example.com
  ns2: ns2.example.com
  hostmaster: hostmaster.example.com

poweradmin:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: poweradmin.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: poweradmin-tls
        hosts:
          - poweradmin.example.com
```

For GitOps, prefer `secrets.existingSecret` and manage that Secret with SOPS, Sealed Secrets, or External Secrets rather than committing credentials into `values.yaml`.

## Install

```bash
helm upgrade --install dns ./powerdns-poweradmin \
  --namespace dns-system \
  --create-namespace \
  -f values-prod.yaml
```

## Verify

```bash
kubectl -n dns-system get cluster
kubectl -n dns-system get pods -o wide
kubectl -n dns-system get svc
kubectl -n dns-system get ingress
```

Public DNS LB:

```bash
kubectl -n dns-system get svc dns-powerdns
```

Test authoritative API from inside the cluster:

```bash
kubectl -n dns-system run curl --rm -it --restart=Never \
  --image=curlimages/curl -- \
  curl -H 'X-API-Key: <key>' \
  http://dns-powerdns-api:8081/api/v1/servers/localhost
```

## Production notes

- Use an externally managed Secret mechanism.
- The default is three CNPG instances; make sure your Kubespray cluster has enough schedulable nodes/failure domains.
- Configure CNPG backups before considering the database production-grade.
- Keep `ns1` and `ns2` in different failure domains; two pods in the same Kubernetes cluster are not a substitute for independent DNS infrastructure.
- For NetworkPolicy, enable it only after validating the Kubespray CNI's policy behavior and any LB health-check source ranges.
- Pin image tags; do not use `latest` in production.
