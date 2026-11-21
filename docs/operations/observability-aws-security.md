---
icon: lucide/shield-check
---

# AWS observability and edge security

The observability backends are self-hosted on AWS. Edge security uses AWS
controls only.

## Hosted backends

| Component | Local Compose | AWS EKS |
| --- | --- | --- |
| Prometheus | yes | yes, 15-day local retention |
| Mimir | yes | yes, filesystem PVC; remote-write target |
| Loki | yes | yes, filesystem PVC |
| Tempo | yes | yes, filesystem PVC |
| Pyroscope | yes | yes, filesystem PVC |
| Grafana | yes | yes, ClusterIP + ALB/Cognito when published |
| Alloy | yes | yes, OTel/Faro/logs collector |
| Blackbox | yes | yes, synthetic probes |

Prometheus scrapes the services and remote-writes to Mimir. Alloy receives OTLP
traces and Faro browser telemetry, and reads Kubernetes pod logs. Grafana queries
Prometheus, Mimir, Loki, Tempo and Pyroscope.

## Edge logs

AWS-native log sources:

| Source | Destination | Status |
| --- | --- | --- |
| CloudFront standard logs | private S3 + Athena | Not enabled |
| AWS WAF logs | CloudWatch Logs or S3 | Not enabled; WAF not attached |
| ALB access logs | S3 + Athena | Not enabled |
| VPC flow logs | CloudWatch Logs or S3 | Not enabled |
| Application logs | Alloy → Loki | Implemented |
| OTel traces | Alloy → Tempo | Implemented for Java services |
| Faro browser telemetry | Alloy `faro.receiver` | Local/path ready |

Do not send cookies, authorization headers, signed upload query strings or
personal data to edge logs. Use S3 lifecycle rules and a retention budget.

## Protection

- AWS Shield Standard protects CloudFront and the NLB.
- AWS WAF is documented but not attached; add managed rules and rate limits first
  in count mode.
- The Gateway NLB accepts only the CloudFront origin-facing prefix list.
- RDS and ElastiCache are private.
- Grafana is ClusterIP and requires Cognito at the ALB when published.
- No third-party edge proxy, tunnel, Access policy or Logpush job is required.

See [AWS edge security](../infrastructure/aws-edge-security.md) and
[Grafana on AWS](grafana-aws.md).
