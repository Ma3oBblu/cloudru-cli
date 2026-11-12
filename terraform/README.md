# Инфраструктура Cloud.ru в Terraform

> Последнее обновление: 2026-11-12

Что описано: реестр образов, Managed PostgreSQL (опционально), ВМ под `docker compose`
(сеть, диск, интерфейс, публичный IP, метаданные образа для SSH), чтение квот и спецификаций.

| Файл | Содержимое |
|---|---|
| `versions.tf` | провайдер `registry.terraform.io/cloudru/cloud` 2.1.6 |
| `providers.tf` | ключи только из окружения (`AUTH_KEY_ID`/`AUTH_SECRET`) |
| `variables.tf` | проект, PostgreSQL, ВМ |
| `data.tf` | зоны, подсети, версии и спецификации PostgreSQL |
| `quotas.tf` | квоты проекта и организации (read-only) |
| `main.tf` | реестр, кластер PostgreSQL, пользователь БД |
| `vm.tf` | каталоги образов/флейворов/типов дисков + слоты метаданных |
| `vm_resources.tf` | группа безопасности и правила, диск, интерфейс, IP, ВМ |
| `outputs.tf` | id кластера и ВМ, публичный IP, доступные спеки и квоты |

Порядок:

```bash
cp tofu.tfrc.example tofu.tfrc      # путь к локальному зеркалу провайдера
cp terraform.tfvars.example terraform.tfvars
set -a && . ~/.config/cloudru/env && set +a
tofu init && tofu plan
```

Переключатель `enable_managed_pg` (по умолчанию `false`) решает, создавать ли Managed PostgreSQL:
если площадка не выделяет ёмкость под DBaaS, инфраструктура поднимается без неё (БД в контейнере на
ВМ), а кластер включается позже одной переменной.

Перед `apply` стоит прочитать `tofu output quotas_customer`: нулевые лимиты организации
(vCPU, RAM, диски, инстансы) означают, что ресурс не будет создан, сколько бы ни было свободно на
уровне проекта. Подробности — [../docs/api-notes.md](../docs/api-notes.md).
