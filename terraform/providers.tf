// Провайдер Cloud.ru Evolution. Ключи доступа не хранятся в конфигурации:
// провайдер берёт их из окружения AUTH_KEY_ID / AUTH_SECRET (см. ~/.cloudru/env).
provider "cloudru" {
  project_id = var.project_id

  // Object Storage (S3) в Cloud.ru пока в одном регионе.
  region                     = "ru-central-1"
  object_storage_tenant_id   = var.object_storage_tenant_id

  // auth_key_id / auth_secret намеренно не заданы — только из окружения.
}
