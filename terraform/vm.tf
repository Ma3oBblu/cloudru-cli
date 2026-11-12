// Вариант A: одна ВМ с docker compose (api + web + postgres) — обход DBaaS,
// который сейчас не выделяет ёмкость.
//
// Шаг 1: каталоги (образы, флейворы, типы дисков, группы безопасности) и метаданные образа.
// Ресурсы ВМ добавляются после выбора image/flavor/disk_type из output-ов.

data "cloudru_evolution_compute_image_collection" "all" {
  project_id = var.project_id
  page_size  = 200
}

data "cloudru_evolution_compute_flavor_collection" "all" {
  project_id = var.project_id
  page_size  = 200
}

data "cloudru_evolution_compute_security_group_collection" "all" {
  project_id = var.project_id
  page_size  = 100
}

data "cloudru_evolution_compute_disk_type_collection" "all" {
  project_id = var.project_id
  page_size  = 100
}

locals {
  ubuntu_images = [
    for i in data.cloudru_evolution_compute_image_collection.all.images :
    i if can(regex("(?i)ubuntu.*(24|22)", i.name))
  ]

  // Чистый серверный образ: без "gpu", "desktop", "nextcloud" и прочих преднастроек.
  base_image = try(
    one([for i in local.ubuntu_images : i if i.name == "Ubuntu-24.04"]),
    try(one([for i in local.ubuntu_images : i if i.name == "ubuntu-24.04"]), null)
  )

  // Флейворы 2 vCPU / 4 ГБ; цена зависит от гарантированной доли (share).
  flavors_2x4 = [
    for f in data.cloudru_evolution_compute_flavor_collection.all.flavors :
    f if f.cpu == 2 && f.ram == 4
  ]

  // Слоты метаданных образа по имени: так не зашиваем UUID площадки.
  meta_by_name       = { for m in try(local.base_image.image_metadata, []) : m.name => m.id }
  meta_login_id      = local.meta_by_name["name"]
  meta_public_key_id = local.meta_by_name["public_key"]
  meta_hostname_id   = local.meta_by_name["hostname"]
}
