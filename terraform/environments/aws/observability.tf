# Grafana secret containers only. Secret values are written out of band with
# scripts/create-grafana-secrets.sh; they never enter Terraform state.

resource "aws_secretsmanager_secret" "grafana_admin" {
  count       = var.enable_observability ? 1 : 0
  name        = "platform/grafana/admin"
  description = "Grafana break-glass admin password and username"
  tags        = merge(local.tags, { Name = "${local.name}-grafana-admin" })
}

resource "aws_secretsmanager_secret" "grafana_alerting" {
  count       = var.enable_observability ? 1 : 0
  name        = "platform/grafana/alerting"
  description = "Grafana alert notification recipients"
  tags        = merge(local.tags, { Name = "${local.name}-grafana-alerting" })
}
