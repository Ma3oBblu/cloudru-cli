variable "project_id" {
  description = "UUID проекта в Cloud.ru Evolution (консоль → проект → настройки)"
  type        = string
}

variable "object_storage_tenant_id" {
  description = "ID тенанта Object Storage (консоль → Object Storage). Нужен только когда появится S3-бакет; можно оставить пустым"
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Префикс в именах ресурсов"
  type        = string
  default     = "finances"
}

variable "pg_version" {
  description = "Версия PostgreSQL. Локальная разработка и миграции проверены на 16"
  type        = string
  default     = "16"
}

variable "enable_managed_pg" {
  description = "Создавать Managed PostgreSQL. Ложь — вариант A (БД в контейнере на ВМ)"
  type        = bool
  default     = false
}

variable "pg_spec_id" {
  description = "ID спецификации кластера (1 vCPU / 2 ГБ / standard). Список печатает `tofu output pg_specs`"
  type        = string
  default     = ""
}

variable "pg_storage_gb" {
  description = "Размер диска с данными, ГБ (WAL на Standard-кластере площадка не выделяет отдельно)"
  type        = number
  default     = 10
}

variable "pg_database" {
  description = "Имя базы, создаваемой при подъёме кластера"
  type        = string
  default     = "finances"
}

variable "pg_user" {
  description = "Имя прикладного пользователя БД (создаётся провайдером)"
  type        = string
  default     = "finances"
}

variable "pg_password" {
  description = "Пароль прикладного пользователя. НЕ в git: задавать через TF_VAR_pg_password или *.auto.tfvars (chmod 600)"
  type        = string
  sensitive   = true
}

variable "subnet_id" {
  description = "ID подсети для кластера. Пусто — берётся подсеть по умолчанию из проекта"
  type        = string
  default     = ""
}

variable "registry_type" {
  description = "Тип реестра образов"
  type        = string
  default     = "DOCKER"
}

// --- Вариант A: ВМ с docker compose ---

variable "vm_zone" {
  description = "Зона доступности для ВМ"
  type        = string
  default     = "ru.AZ-1"
}

variable "vm_flavor_id" {
  description = "Флейвор ВМ. lowcost10-2-4 = 2 vCPU (доля 1:10) / 4 ГБ — самый дешёвый под эту нагрузку"
  type        = string
  default     = "82d31572-23e0-4937-a6af-45ddae64ba87"
}

variable "vm_disk_gb" {
  description = "Размер загрузочного диска, ГБ"
  type        = number
  default     = 20
}

variable "vm_login" {
  description = "Логин на ВМ (слот метаданных образа «name»)"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Публичный SSH-ключ, который кладётся в метаданные образа"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_source_cidr" {
  description = "Откуда разрешён SSH (ваш внешний IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}
