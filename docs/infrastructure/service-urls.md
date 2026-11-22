---
icon: lucide/link
---

# Service URLs

Environment: AWS region `us-east-1`, EKS cluster `platform`. The frontend and API
are published through CloudFront.

The public documentation intentionally omits AWS account IDs, EKS API endpoints,
database and cache hostnames, private bucket names and internal load-balancer
hostnames. Keep the full inventory in the private operator runbook and record
only public URLs and redacted resource names in delivery evidence.

## Public endpoints

| Endpoint | URL | Status |
| --- | --- | --- |
| Landing | `https://d15ogksm4jp6sl.cloudfront.net/` | Verified 200, CloudFront static S3 export |
| Store | `https://d15ogksm4jp6sl.cloudfront.net/store/` | Verified 200, CloudFront static S3 export |
| Admin | `https://d15ogksm4jp6sl.cloudfront.net/admin/` | Verified 200, CloudFront static S3 export |
| API | `https://d15ogksm4jp6sl.cloudfront.net/api` | Verified 200, CloudFront `/api/*` → Gateway NLB |
| API health | `https://d15ogksm4jp6sl.cloudfront.net/api/actuator/health` | Verified 200; prefix stripped |
| Faro ingest (prepared) | `https://d15ogksm4jp6sl.cloudfront.net/faro/collect` | Prepared behind `enable_faro_ingest`; not deployed |
| Documentation | `https://microsserv52.github.io/platform/` | Published from `main` |

CloudFront terminates TLS for viewers and forwards `/api/*` to the NLB over
HTTP. The CloudFront function strips the `/api` prefix, so the Gateway receives
`/products`, `/auth/login`, `/session/login`, etc.

The function also adds an `x-site` header (`landing`, `store`, `admin`) and the
site cache policy includes it in the cache key. Without that header, all three
static sites rewrote to `/index.html` and shared one cache entry, so every route
returned the first cached site.

There is no custom domain or ACM certificate yet; the CloudFront hostname is
the public application URL. Adding one requires a domain, Route 53 hosted zone,
ACM certificate, CloudFront alias and updates to CORS, cookies, Cognito and
Faro origins; see [Custom domains](custom-domains.md).

## Access from a workstation

Use the public URL:

```bash
curl -fsS https://d15ogksm4jp6sl.cloudfront.net/api/actuator/health
curl -fsS https://d15ogksm4jp6sl.cloudfront.net/api/products
```

For cluster debugging, bypass CloudFront with the Gateway Service:

```bash
kubectl -n platform port-forward svc/gateway 8080:8080
curl http://localhost:8080/actuator/health
```

Do not use the NLB HTTP origin directly for normal clients; it bypasses
CloudFront TLS and the path rewrite.

## Cluster-internal services

These names resolve only inside the `platform` namespace:

| Service | Internal URL | Health |
| --- | --- | --- |
| Gateway | `http://gateway:8080` | `/actuator/health` |
| Auth | `http://auth:8080` | `/actuator/health` |
| Account | `http://account:8080` | `/actuator/health` |
| Order | `http://order:8080` | `/actuator/health` |
| Product | `http://product:8080` | `/actuator/health` |
| Exchange | `http://exchange:8080` | `/health` |
| Exchange mock | `http://exchange-mock:8080` (LocalStack only) | `/health` |

## Observability endpoints

These are ClusterIP services in the `observability` namespace. None is public;
use port-forward unless the Cognito ALB ingress is installed.

| Component | Internal URL | Local URL |
| --- | --- | --- |
| Grafana | `http://grafana.observability.svc.cluster.local:3000` | `http://localhost:3000` |
| Prometheus | `http://observability-kube-prometheus-prometheus.observability.svc.cluster.local:9090` | `http://localhost:9090` |
| Mimir | `http://mimir.observability.svc.cluster.local:9009/prometheus` | `http://localhost:9009` |
| Loki | `http://loki.observability.svc.cluster.local:3100` | `http://localhost:3100` |
| Tempo | `http://tempo.observability.svc.cluster.local:3200` | `http://localhost:3200` |
| Pyroscope | `http://pyroscope.observability.svc.cluster.local:4040` | `http://localhost:4040` |
| Alloy OTLP | `alloy.observability.svc.cluster.local:4317` | `localhost:4317` |
| Faro ingest | `http://alloy.observability.svc.cluster.local:12347/collect` | `http://localhost:8080/faro/collect` (nginx → Alloy) |

## AWS service endpoints

| Service | Endpoint |
| --- | --- |
| EKS API | Private operator detail; region `us-east-1` |
| ECR | Private operator detail; region `us-east-1` |
| RDS PostgreSQL | Private operator detail; private subnet |
| ElastiCache Redis | Private operator detail; private subnet |
| CloudFront | Public hostname `d15ogksm4jp6sl.cloudfront.net` |
| Gateway NLB | Private operator detail; CloudFront-only origin |

RDS and ElastiCache are in private subnets and are not publicly accessible. The
NLB is internet-facing on HTTP port 80, but its security group allows only the
AWS CloudFront origin-facing prefix list; direct NLB access is blocked. The
Kubernetes Service is a fixed NodePort (`30080`) behind that NLB.

## Frontend delivery

The three applications are static Next.js exports. `scripts/sync-frontends.sh`
builds `web/landing`, `web/store` and `web/admin` with
`NEXT_PUBLIC_API_BASE_URL=/api`, syncs each `out/` directory to its bucket and
invalidates CloudFront.

| Site | S3 bucket | CloudFront behaviour |
| --- | --- | --- |
| Landing | `<account>-landing frontend bucket` | default `/*` |
| Store | `<account>-store frontend bucket` | `/store/*` |
| Admin | `<account>-admin frontend bucket` | `/admin/*` |
| Media | `<account>-media bucket` | `/media/*` |

The admin build also needs
`NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS=https://<media-bucket>.s3.us-east-1.amazonaws.com`
for browser presigned uploads.
