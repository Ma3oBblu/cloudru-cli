// Всё, что нужно прочитать у площадки перед созданием ресурсов.
// Список зон и подсетей проекта — чтобы не зашивать UUID руками.

data "cloudru_evolution_compute_zone_collection" "all" {
  project_id = var.project_id
}

data "cloudru_evolution_compute_subnet_collection" "all" {
  project_id = var.project_id
  page_size  = 100
}

data "cloudru_evolution_postgresql_version_collection" "all" {}

data "cloudru_evolution_postgresql_specification_collection" "all" {
  version_name = var.pg_version
}

locals {
  // Подсети по умолчанию: одна на зону, кластер у нас одноузловой.
  default_subnets = [for s in data.cloudru_evolution_compute_subnet_collection.all.subnets : s.id if s.default]
  subnet_ids      = var.subnet_id != "" ? [var.subnet_id] : [local.default_subnets[0]]

  // Кандидаты для «минимального» кластера: стандартный режим, без горячего резерва.
  // deployment_mode приходит в верхнем регистре ("STANDARD"), standby — флаг горячего резерва.
  pg_specs = [
    for s in data.cloudru_evolution_postgresql_specification_collection.all.specifications :
    s if upper(s.deployment_mode) == "STANDARD" && s.allow_primary_standby == false
  ]

  // Пусто — значит фильтр не нашёл подходящей спеки; тогда кластер не создаётся,
  // а `tofu output pg_specs_all` показывает, что реально предлагает площадка.
  pg_spec_id = var.pg_spec_id != "" ? var.pg_spec_id : try(local.pg_specs[0].id, "")
}
