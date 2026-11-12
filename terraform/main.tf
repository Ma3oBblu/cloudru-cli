// Реестр образов: без него Container Apps не запускает ничего (образы только из Artifact Registry).
resource "cloudru_evolution_artifact_registry_registry" "images" {
  name          = "${var.name_prefix}-images"
  project_id    = var.project_id
  registry_type = var.registry_type
  is_public     = false

  retention_policy_is_enabled = true
  retention_policy = {
    only_untagged = false
    action        = "DELETE"
    constraint    = "OLDER_THAN"
    value         = 30
    unit          = "d"
    on            = "LAST_PULLED_AT"
  }
}

// Managed PostgreSQL: 1 узел, минимальная спецификация, автобэкап раз в сутки.
// Остановить кластер на простой можно только через API/консоль — в провайдере нет action-ресурсов.
resource "cloudru_evolution_postgresql_cluster" "main" {
  count = var.enable_managed_pg && local.pg_spec_id != "" ? 1 : 0

  name             = "${var.name_prefix}-pg"
  description      = "finances: леджер и отчёты"
  project_id       = var.project_id
  version          = var.pg_version
  instances        = 1
  subnet_ids       = local.subnet_ids
  specification_id = local.pg_spec_id

  // pg_wal_gb только для Business-кластеров: Standard отвечает
  // InvalidArgument «standard cluster does not support pg_wal_gb».
  storage = {
    pg_data_gb = var.pg_storage_gb
  }

  initial_database = var.pg_database

  pooler_config = {
    enabled   = true
    pool_mode = "TRANSACTION"
  }

  backup = {
    schedule              = "0 3 * * *"
    retention_policy_days = 7
  }

  maintenance_window = {
    anytime = {}
  }
}

resource "cloudru_evolution_postgresql_user" "app" {
  count = var.enable_managed_pg && local.pg_spec_id != "" ? 1 : 0

  cluster_id = cloudru_evolution_postgresql_cluster.main[0].id
  name       = var.pg_user
  password   = var.pg_password
}
