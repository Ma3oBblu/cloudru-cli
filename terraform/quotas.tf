// Квоты проекта: читаем, чтобы понять, что реально доступно (включая free tier),
// прежде чем создавать платные ресурсы. Ничего не меняет.
data "cloudru_evolution_organization_quota_usage_collection" "project" {
  subject_type_codes = ["QUOTA_SUBJECT_TYPE_PROJECT"]
  subject_ids        = [var.project_id]
  page_size          = 500
}

data "cloudru_evolution_organization_quota_resource_type_collection" "all" {}

data "cloudru_evolution_organization_quota_usage_collection" "customer" {
  subject_type_codes = ["QUOTA_SUBJECT_TYPE_CUSTOMER"]
  page_size          = 500
}

locals {
  quota_names = {
    for rt in data.cloudru_evolution_organization_quota_resource_type_collection.all.resource_types :
    rt.code => { name = rt.name, product = rt.product_name, unit = rt.unit }
  }

  // Показываем всё, включая нулевые лимиты: именно они объясняют отказы в создании.
  quotas = [
    for u in data.cloudru_evolution_organization_quota_usage_collection.project.usages : {
      product = try(local.quota_names[u.resource_type_code].product, "?")
      resource = try(local.quota_names[u.resource_type_code].name, u.resource_type_code)
      unit     = try(local.quota_names[u.resource_type_code].unit, "")
      limit    = u.individual_limit
      used     = u.individual_usage
    }
  ]
}
