---
icon: lucide/link
---

# Service URLs

Environment: AWS account `730335608828`, region `us-east-1`, EKS cluster
`platform`. The frontend and API are published through CloudFront.

## Public endpoints

| Endpoint | URL | Status |
| --- | --- | --- |
| Landing | `https://d15ogksm4jp6sl.cloudfront.net/` | Verified 200, CloudFront static S3 export |
| Store | `https://d15ogksm4jp6sl.cloudfront.net/store/` | Verified 200, CloudFront static S3 export |
| Admin | `https://d15ogksm4jp6sl.cloudfront.net/admin/` | Verified 200, CloudFront static S3 export |
| API | `https://d15ogksm4jp6sl.cloudfront.net/api` | Verified 200, CloudFront `/api/*` → Gateway NLB |
| API health | `https://d15ogksm4jp6sl.cloudfront.net/api/actuator/health` | Verified 200; prefix stripped |
| Gateway NLB origin | `http://platform-gateway-ecaafe88209b53bc.elb.us-east-1.amazonaws.com` | CloudFront-only security group; direct access times out |
| Documentation | `https://microsserv52.github.io/platform/` | Published from `main` |

CloudFront terminates TLS for viewers and forwards `/api/*` to the NLB over
HTTP. The CloudFront function strips the `/api` prefix, so the Gateway receives
`/products`, `/auth/login`, `/session/login`, etc.

The function also adds an `x-site` header (`landing`, `store`, `admin`) and the
site cache policy includes it in the cache key. Without that header, all three
static sites rewrote to `/index.html` and shared one cache entry, so every route
returned the first cached site.

There is no custom domain or ACM certificate yet; the CloudFront hostname is
the public application URL.

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

## AWS service endpoints

| Service | Endpoint |
| --- | --- |
| EKS API | `https://E809E54F1ACAC4DACB972ABD6A78E62F.gr7.us-east-1.eks.amazonaws.com` |
| ECR | `730335608828.dkr.ecr.us-east-1.amazonaws.com` |
| RDS PostgreSQL | `platform-postgres.cf0a6omck937.us-east-1.rds.amazonaws.com:5432` |
| ElastiCache Redis | `platform-redis.wkuz0g.0001.use1.cache.amazonaws.com:6379` |
| CloudFront | `E2HCWED02TM6CL` / `d15ogksm4jp6sl.cloudfront.net` |
| Gateway NLB | `platform-gateway-ecaafe88209b53bc.elb.us-east-1.amazonaws.com` |

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
| Landing | `platform-landing-730335608828` | default `/*` |
| Store | `platform-store-730335608828` | `/store/*` |
| Admin | `platform-admin-730335608828` | `/admin/*` |
| Media | `platform-media-730335608828` | `/media/*` |

The admin build also needs
`NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS=https://platform-media-730335608828.s3.us-east-1.amazonaws.com`
for browser presigned uploads.
