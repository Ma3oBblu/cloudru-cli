output "pg_cluster_id" {
  description = "ID кластера PostgreSQL — нужен для stop/start через API"
  value       = try(cloudru_evolution_postgresql_cluster.main[0].id, "")
}

output "vm_public_ip" {
  description = "Публичный IP ВМ"
  value       = try(cloudru_evolution_compute_external_ip.eip.ip_address, "")
}

output "vm_id" {
  description = "ID виртуальной машины"
  value       = try(cloudru_evolution_compute_vm.main.id, "")
}

output "vm_image_metadata" {
  description = "Слоты метаданных выбранного образа (нужны для SSH-доступа: user_data площадка не принимает)"
  value = [
    for m in try(local.base_image.image_metadata, []) : {
      id         = m.id
      name       = m.name
      mandatory  = m.mandatory_group
      default    = m.default_value
      field_type = m.field_type
    }
  ]
}

output "vm_disk_types" {
  description = "Типы дисков проекта"
  value       = [for d in data.cloudru_evolution_compute_disk_type_collection.all.disk_types : { id = d.id, name = d.name }]
}

output "vm_images" {
  description = "Образы Ubuntu, доступные в проекте"
  value = [
    for i in local.ubuntu_images : {
      id   = i.id
      name = i.name
    }
  ]
}

output "vm_flavors_2x4" {
  description = "Флейворы 2 vCPU / 4 ГБ"
  value = [
    for f in local.flavors_2x4 : {
      id     = f.id
      name   = f.name
      cpu    = f.cpu
      ram    = f.ram
      share  = f.oversubscription
    }
  ]
}

output "vm_security_groups" {
  description = "Существующие группы безопасности проекта"
  value = [
    for g in data.cloudru_evolution_compute_security_group_collection.all.security_groups : {
      id   = g.id
      name = g.name
    }
  ]
}

output "quotas_customer" {
  description = "Квоты уровня клиента (организации) — включая объём дисков и прочие лимиты пула"
  value = [
    for u in data.cloudru_evolution_organization_quota_usage_collection.customer.usages : {
      product  = try(local.quota_names[u.resource_type_code].product, "?")
      resource = try(local.quota_names[u.resource_type_code].name, u.resource_type_code)
      unit     = try(local.quota_names[u.resource_type_code].unit, "")
      limit    = u.individual_limit
      used     = u.individual_usage
      aggregate = u.aggregated_usage
    }
  ]
}

output "quotas" {
  description = "Квоты проекта, у которых лимит больше нуля (включая free tier)"
  value       = local.quotas
}

output "pg_versions" {
  description = "Какие версии PostgreSQL предлагает площадка"
  value       = [for v in data.cloudru_evolution_postgresql_version_collection.all.versions : v.name]
}

output "pg_specs_all" {
  description = "Все спецификации PostgreSQL без фильтров — чтобы понять, что доступно под нужную версию"
  value = [
    for s in data.cloudru_evolution_postgresql_specification_collection.all.specifications : {
      id         = s.id
      name       = s.display_name
      cpu        = s.cpu
      memory_gb  = s.memory
      min_disk   = s.min_storage_gb
      mode       = s.deployment_mode
      standby    = s.allow_primary_standby
      flavor     = s.flavor_type
      max_hosts  = s.max_hosts
    }
  ]
}

output "pg_specs" {
  description = "Доступные спецификации (deployment_mode=standard, без hot standby) — выбрать pg_spec_id"
  value = [
    for s in local.pg_specs : {
      id         = s.id
      name       = s.display_name
      cpu        = s.cpu
      memory_gb  = s.memory
      min_disk   = s.min_storage_gb
      max_hosts  = s.max_hosts
    }
  ]
}

output "pg_connection_hint" {
  description = "Ориентир для FINANCES_DATABASE_URL (хост и порт уточняются в консоли после создания)"
  value       = "postgres://${var.pg_user}:***@<host из консоли>:5432/${var.pg_database}?sslmode=require"
}

output "registry_id" {
  description = "ID реестра образов (для docker login и terraform-импорта)"
  value       = cloudru_evolution_artifact_registry_registry.images.id
}

output "subnets" {
  description = "Подсети проекта: id, имя, зона, признак default"
  value = [
    for s in data.cloudru_evolution_compute_subnet_collection.all.subnets : {
      id      = s.id
      name    = s.name
      zone    = try(s.zone.name, "")
      default = s.default
      cidr    = s.subnet_address
    }
  ]
}

output "zones" {
  description = "Зоны доступности проекта"
  value       = [for z in data.cloudru_evolution_compute_zone_collection.all.zones : z.name]
}
