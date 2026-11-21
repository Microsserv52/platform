---
icon: lucide/link
---

# Service URLs

Environment: AWS account `730335608828`, region `us-east-1`, EKS cluster
`platform`. The infrastructure is live, but there is **no public API ingress**
and the static frontends are not published yet.

## Public endpoints

| Endpoint | URL | Status |
| --- | --- | --- |
| Frontend CDN | `https://d15ogksm4jp6sl.cloudfront.net` | Distribution deployed; buckets not synced, so the root returns an S3 error until a frontend is published |
| Frontend routes | `https://d15ogksm4jp6sl.cloudfront.net/`, `/store/`, `/admin/` | Reserved by the CloudFront path behaviors; not populated |
| Public API | — | **Not exposed**; no ingress controller or load balancer is installed |
| Documentation | `https://microsserv52.github.io/platform/` | Published from `main`; these branch docs appear after merge |

There is no custom domain or ACM certificate in the current environment. The
CloudFront domain is the only public hostname.

## Access from a workstation

The API is reachable through the Gateway Service only:

```bash
kubectl -n platform port-forward svc/gateway 8080:8080
curl http://localhost:8080/actuator/health
curl http://localhost:8080/products
```

This is the URL used for the load tests and smoke checks. It is not an internet
endpoint.

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

The Gateway strips `/api`; callers use `/products`, `/auth/login`,
`/session/login`, not `/api/products`.

## AWS service endpoints

| Service | Endpoint |
| --- | --- |
| EKS API | `https://E809E54F1ACAC4DACB972ABD6A78E62F.gr7.us-east-1.eks.amazonaws.com` |
| ECR | `730335608828.dkr.ecr.us-east-1.amazonaws.com` |
| RDS PostgreSQL | `platform-postgres.cf0a6omck937.us-east-1.rds.amazonaws.com:5432` |
| ElastiCache Redis | `platform-redis.wkuz0g.0001.use1.cache.amazonaws.com:6379` |
| CloudFront | `E2HCWED02TM6CL` / `d15ogksm4jp6sl.cloudfront.net` |

RDS and ElastiCache are in private subnets and are not publicly accessible.

## Missing public URL

To make the application available on the internet, one of these is still
required:

1. Install ingress-nginx or the AWS Load Balancer Controller, wait for its
   external address, and use that as the API origin; or
2. Set `TF_VAR_cloudfront_api_origin_domain` to the ingress hostname and deploy
   the frontends with `scripts/deploy-aws.sh --skip-terraform --skip-images --frontends`.

Until then, the EKS workloads and CloudFront distribution are live but the
application is not reachable as a public website.
