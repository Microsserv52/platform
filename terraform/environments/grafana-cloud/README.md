# Grafana Cloud environment

Terraform manages the Grafana Cloud resources that cannot be file-provisioned:

- the `Platform` folder and the five dashboards from `observability/grafana/dashboards`;
- the email contact point and default notification policy;
- two Grafana-managed alert rules (availability fast burn and scrape target down);
- Synthetic Monitoring HTTP checks for the landing page, store and API health.

## Credentials

The provider reads standard environment variables:

```bash
export TF_VAR_grafana_url="https://example.grafana.net"
export TF_VAR_grafana_auth="$GRAFANA_SERVICE_ACCOUNT_TOKEN"
export TF_VAR_grafana_sm_access_token="$GRAFANA_SM_ACCESS_TOKEN"
export TF_VAR_grafana_sm_url="$GRAFANA_SM_URL"
```

`grafana_auth` and `grafana_sm_access_token` are sensitive. Do not write them to
`terraform.tfvars`, Git, CI logs or the repository. Use a secret store or the
CI environment.

## Apply

```bash
terraform -chdir=terraform/environments/grafana-cloud init
terraform -chdir=terraform/environments/grafana-cloud validate
terraform -chdir=terraform/environments/grafana-cloud plan
terraform -chdir=terraform/environments/grafana-cloud apply
```

The environment is not applied by this repository. Synthetic checks require
Synthetic Monitoring to be installed on the stack and the probe names to exist.
List the available probes with the Grafana Cloud UI or the
`grafana_synthetic_monitoring_probes` data source.

The Prometheus datasource UID in Grafana Cloud may not be `prometheus`; set
`prometheus_datasource_uid` to the UID shown in **Connections → Data sources**.

## Related

- [Observability](../../../docs/operations/observability.md)
- [Grafana on AWS](../../../docs/operations/grafana-aws.md)
- [AWS observability and edge security](../../../docs/operations/observability-aws-security.md)
