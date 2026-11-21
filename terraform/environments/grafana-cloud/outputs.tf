output "folder_uid" {
  value = grafana_folder.platform.uid
}

output "dashboard_uids" {
  value = { for name, dashboard in grafana_dashboard.platform : name => dashboard.uid }
}

output "synthetic_check_ids" {
  value = { for name, check in grafana_synthetic_monitoring_check.edge : name => check.id }
}
