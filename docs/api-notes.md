# Cloud.ru Evolution: заметки по API

> Последнее обновление: 2026-11-12

Всё ниже проверено на живом проекте (ноябрь 2026), а не взято из документации: часть поведения
документацией не описана, часть расходится с ожиданиями.

## Оглавление

- [Аутентификация](#аутентификация)
- [Managed PostgreSQL: REST](#managed-postgresql-rest)
- [Managed PostgreSQL: gRPC](#managed-postgresql-grpc)
- [Удаление и force-флаг](#удаление-и-force-флаг)
- [Квоты: два уровня](#квоты-два-уровня)
- [Free tier](#free-tier)
- [Terraform-провайдер](#terraform-провайдер)
- [Compute: что не поддерживается](#compute-что-не-поддерживается)

## Аутентификация

```bash
curl -s --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=$KEY_ID" \
  --data-urlencode "client_secret=$KEY_SECRET" \
  https://id.cloud.ru/auth/system/openid/token
```

- Работает `grant_type=client_credentials` и `access_key`; клиент — Key ID, секрет — Key Secret
  сервисного аккаунта.
- **Токен с `auth.iam.cloud.ru` API отвергает**: `401 Jwt issuer is not configured`. Использовать
  только `id.cloud.ru`.
- Дальше — `Authorization: Bearer <access_token>`.

## Managed PostgreSQL: REST

База: `https://postgresql.api.cloud.ru`

| Действие | Запрос | Замечание |
|---|---|---|
| список | `GET /v1/clusters?project_id=<uuid>` | проект — именно query-параметром |
| кластер | `GET /v1/clusters/{id}` | проект — заголовком `x-project-id` |
| создание | `POST /v1/clusters?project_id=<uuid>` + JSON | 200 = операция принята, не готовность |
| удаление | `DELETE /v1/clusters/{id}` | см. ниже про force |
| операция | `GET /v1/operations/{id}` | здесь лежит настоящая причина отказа |

Грабли шлюза:

- **Query-параметры на item-путях ломают запрос**: `GET /v1/clusters/{id}?project_id=…` → `415`.
  Проект передаётся заголовком `x-project-id`.
- **Действия не маршрутизируются**: `POST /v1/clusters/{id}/stop` → `415 invalid gRPC request
  content-type`; с `Content-Type: application/grpc` шлюз уходит в gRPC и отвечает
  `unknown service v1/clusters/…`.
- **`done: true` в операции ≠ успех**: смотреть `error.message`. Типовые значения:
  `acquire_quota failed` (нет ёмкости), `inappropriate service status: "FAILED"`.
- **Тело ошибки валидации пустое.** `POST /v1/clusters` на неполном теле отвечает `400` с
  `content-length: 0`, а текст лежит в заголовке `grpc-message` (`initial_database: field is required`).
  Без чтения заголовка видно только голый «400» — и следующий шаг делается вслепую.
- **`initial_database` обязателен.** Минимально достаточное тело создания:
  `{name, version, instances, specification_id, storage:{pg_data_gb}, subnet_ids:[…], initial_database}`.
- **`project_id` — только query-параметром.** Без него шлюз отвечает
  `invalid GetByProjectAndProductRequest.ProjectId: value must be a valid UUID`, даже если проект есть
  в заголовке `x-project-id`.

## Managed PostgreSQL: gRPC

Хост: `postgresql.api.cloud.ru:443`. Сервис: `cloudru.dbaas.postgresql.v1.ClusterService`.

| Метод | Назначение |
|---|---|
| `Get` | кластер по id |
| `Suspend` / `Resume` | остановка и запуск (REST их не отдаёт) |
| `Delete` | удаление (см. force) |
| `Switchover` | переключение мастера |

- **Рефлексия выключена**: `grpcurl` без `-proto` отвечает `server does not support the reflection
  API`. Нужен локальный `proto/pg_min.proto`; передавать `-import-path` вместе с `-proto`.
- Запрос: `cluster_id` — поле 1. Ответы декодируются как пустые сообщения: для действий важен код.
- Метаданные: `Authorization: Bearer …` и `x-project-id: <uuid>`.

## Удаление и force-флаг

Объект в статусе `FAILED` (остаётся после неудачного создания) удаляется только с force:

```
delete standard postgres: … service with "FAILED" status may be delete only with force flag
```

Перебрано и **не работает**: `?force=true` (415), тело `{"force":true}` (игнорируется), заголовок
`x-force: true` (игнорируется), bool-поля 2–6 в gRPC-запросе `Delete`. Вывод: force-флаг доступен
внутреннему пути площадки, снаружи — только через поддержку. В консоли кнопка удаления у таких
объектов тоже недоступна.

## Квоты: два уровня

Читаются Terraform-провайдером: `cloudru_evolution_organization_quota_usage_collection`
(`subject_type_codes`, `subject_ids`) + `cloudru_evolution_organization_quota_resource_type_collection`
для расшифровки кодов.

| Уровень | `subject_type_code` | Что показывает |
|---|---|---|
| Проект | `QUOTA_SUBJECT_TYPE_PROJECT` | лимиты внутри проекта; у свежего проекта по БД часто `-1` (безлимит) |
| Организация | `QUOTA_SUBJECT_TYPE_CUSTOMER` | реальные лимиты пула: vCPU, RAM, диски, инстансы |

Наблюдённая картина (свежий проект, ноябрь 2026):

- проект: Managed PostgreSQL vCPU / RAM / диски / инстансы — `-1`, потребление 0;
- организация: **Compute vCPU 0, RAM 0, общий объём дисков 0**; Managed PostgreSQL «Инстансы» 0,
  «RAM» 0, «Инстансы Free Tier» 1;
- итог: создание кластера падает на `acquire_quota failed`, создание диска ВМ — на
  `organization_quota_exceeded`. Безлимит на уровне проекта при этом ни на что не влияет.

Практический вывод: заявка «увеличьте квоту» бесполезна, если нули на уровне организации — это
отсутствие свободных мощностей, а не лимит аккаунта (поддержка Cloud.ru подтверждает приостановку
выдачи ресурсов при высокой нагрузке).

## Free tier

Строка «Инстансы Free Tier = 1» существует, но гарантией не является: `POST /v1/clusters` с
`free_tier=true` (и с `freeTier=true`) принимается с кодом 200, операция стартует, а через секунду
падает тем же `acquire_quota failed`. Проверять free tier так же, как платный ресурс: одной пробой.

Перепроверено 2026-11-12 в 21:43 МСК: квоты организации те же (Free Tier 1, Инстансы/RAM/vCPU/диски 0),
проба — `acquire_quota failed`, причём **платный** вариант (без `free_tier`) падает тем же сообщением.
То есть free tier не «спит» отдельно: не хватает ёмкости пула, и платный заказ не спасает.

Цена пробы: каждая неудачная попытка оставляет кластер в статусе `FAILED`, который `DELETE` не берёт
(`may be delete only with force flag`) — чистит поддержка. Одна попытка = один объект, поэтому
проверять одной пробой, а не циклом.

## Terraform-провайдер

- Источник: `registry.terraform.io/cloudru/cloud`, версия 2.1.6; бинарники — в GitHub-релизах
  `cloud-ru/evo-terraform` (`terraform-provider-cloud_2.1.6_<os>_<arch>`).
- Реестр провайдеров доступен не с каждой машины → локальное зеркало
  `~/.terraform.d/plugins/registry.terraform.io/cloudru/cloud/2.1.6/darwin_arm64/` +
  `provider_installation { filesystem_mirror … }`.
- **`source` указывать с хостом** (`registry.terraform.io/cloudru/cloud`): OpenTofu по умолчанию
  ищет в `registry.opentofu.org` и зеркало не находит.
- Поля, на которых легко ошибиться: память флейвора — `ram` (не `memory`); `deployment_mode`
  приходит в верхнем регистре (`STANDARD`); тип интерфейса — полный enum
  `INTERFACE_TYPE_REGULAR`; `pg_wal_gb` недопустим для Standard-кластера.
- Действий жизненного цикла (stop/start) в провайдере нет — только gRPC, см. выше.

## Compute: что не поддерживается

- `user_data` при создании ВМ не принимается: вход настраивается слотами метаданных образа
  (`name`, `public_key`, `hostname` — их id берутся из `cloudru_evolution_compute_image_collection`).
- Провижининг внутри ВМ — после создания по SSH.
- Сетевые ресурсы (группы безопасности, интерфейс, публичный IP) создаются независимо от квоты на
  vCPU/диски, поэтому «сеть получилась, ВМ нет» — нормальная картина при нулевых квотах.
