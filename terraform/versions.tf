terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudru = {
      // Хост указан явно: OpenTofu по умолчанию ищет провайдера в registry.opentofu.org,
      // а бинарник мы кладём в локальное зеркало под registry.terraform.io.
      source  = "registry.terraform.io/cloudru/cloud"
      version = "2.1.6"
    }
  }
}
