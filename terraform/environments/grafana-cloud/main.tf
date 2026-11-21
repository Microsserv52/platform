provider "grafana" {
  url             = var.grafana_url
  auth            = var.grafana_auth
  sm_access_token = var.grafana_sm_access_token
  sm_url          = var.grafana_sm_url
}

resource "grafana_folder" "platform" {
  title = var.folder_name
  uid   = "platform"
}

resource "grafana_dashboard" "platform" {
  for_each = fileset("${path.module}/../../../observability/grafana/dashboards", "*.json")

  config_json = file("${path.module}/../../../observability/grafana/dashboards/${each.value}")
  folder      = grafana_folder.platform.uid
  overwrite   = true
}

resource "grafana_contact_point" "email" {
  name = "platform-email"

  email {
    addresses    = [var.alert_email]
    single_email = true
  }
}

resource "grafana_notification_policy" "platform" {
  contact_point   = grafana_contact_point.email.name
  group_by        = ["alertname", "service", "severity"]
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"
}

resource "grafana_rule_group" "platform_slo" {
  name             = "platform-slo"
  folder_uid       = grafana_folder.platform.uid
  interval_seconds = 60

  rule {
    name      = "Platform availability fast burn"
    condition = "C"
    for       = "5m"

    data {
      ref_id         = "A"
      datasource_uid = var.prometheus_datasource_uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        expr       = "platform:availability:ratio5m"
        instant    = true
        range      = false
        refId      = "A"
        editorMode = "code"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "A"
        conditions = [{
          evaluator = { type = "lt", params = [0.99] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
          reducer   = { type = "last" }
          type      = "query"
        }]
      })
    }

    annotations = {
      summary     = "Service availability is below 99% for 5 minutes."
      runbook_url = "https://microsserv52.github.io/platform/operations/observability/#alert-runbook"
    }
    labels = {
      severity = "page"
      owner    = "platform"
    }
    no_data_state  = "NoData"
    exec_err_state = "Error"
  }

  rule {
    name      = "Prometheus scrape target down"
    condition = "C"
    for       = "2m"

    data {
      ref_id         = "A"
      datasource_uid = var.prometheus_datasource_uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        expr       = "up{job=~\"gateway|auth|account|order|product|exchange\"} == 0"
        instant    = true
        range      = false
        refId      = "A"
        editorMode = "code"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "A"
        conditions = [{
          evaluator = { type = "gt", params = [0] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
          reducer   = { type = "last" }
          type      = "query"
        }]
      })
    }

    annotations = {
      summary     = "Prometheus cannot scrape a platform service."
      runbook_url = "https://microsserv52.github.io/platform/operations/observability/#alert-runbook"
    }
    labels = {
      severity = "page"
      owner    = "platform"
    }
    no_data_state  = "Alerting"
    exec_err_state = "Error"
  }
}

data "grafana_synthetic_monitoring_probes" "all" {
  count = var.enable_synthetic_checks ? 1 : 0
}

locals {
  synthetic_targets = var.enable_synthetic_checks ? {
    landing = "${var.public_base_url}/"
    store   = "${var.public_base_url}/store/"
    api     = "${var.public_base_url}/api/actuator/health"
  } : {}
  synthetic_probes = var.enable_synthetic_checks ? [
    for name in var.probe_names : data.grafana_synthetic_monitoring_probes.all[0].probes[name]
  ] : []
}

resource "grafana_synthetic_monitoring_check" "edge" {
  for_each = local.synthetic_targets

  job               = "platform-${each.key}"
  target            = each.value
  probes            = local.synthetic_probes
  frequency         = 60000
  timeout           = 5000
  enabled           = true
  alert_sensitivity = "medium"

  labels = {
    service     = "edge"
    environment = "aws"
    check       = each.key
  }

  settings {
    http {
      method              = "GET"
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes  = [200]
    }
  }
}
