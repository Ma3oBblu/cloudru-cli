# cloudru-cli

> Последнее обновление: 2026-11-12

Маленький CLI к Cloud.ru Evolution: управление Managed PostgreSQL и чтение квот.
Плюс Terraform-описание инфраструктуры и заметки по API, которые пришлось выяснить опытом.

## Оглавление

- [Зачем](#зачем)
- [Установка](#установка)
- [Конфигурация](#конфигурация)
- [Команды](#команды)
- [Terraform](#terraform)
- [Что выяснено про API](#что-выяснено-про-api)
- [Структура](#структура)

## Зачем

У Cloud.ru нет общей CLI, а действия жизненного цикла Managed PostgreSQL доступны только по gRPC
(рефлексия выключена) и не маршрутизируются REST-шлюзом. Этот репозиторий закрывает дырку: тонкая
обёртка над проверенными эндпоинтами + протокол для gRPC-методов, чтобы не собирать это заново
каждый раз.

## Установка

Зависимости: `curl`, `python3`, `grpcurl` (нужен только для `suspend`/`resume`).

```bash
brew install grpcurl        # macOS
git clone <этот-репозиторий> ~/src/cloudru-cli
ln -s ~/src/cloudru-cli/bin/cloudru /usr/local/bin/cloudru
cloudru --help
```

## Конфигурация

Ключи доступа не хранятся в репозитории. Положите их в `~/.config/cloudru/env` (chmod 600) или
экспортируйте в окружение:

```bash
mkdir -p ~/.config/cloudru && chmod 700 ~/.config/cloudru
cp .env.example ~/.config/cloudru/env
$EDITOR ~/.config/cloudru/env
chmod 600 ~/.config/cloudru/env
```

| Переменная | Что это |
|---|---|
| `CLOUDRU_KEY_ID` / `CLOUDRU_SECRET` | Key ID и Key Secret сервисного аккаунта (старые имена `AUTH_KEY_ID`/`AUTH_SECRET` тоже читаются) |
| `CLOUDRU_PROJECT_ID` | UUID проекта Evolution |
| `TF_VAR_pg_password` | пароль прикладного пользователя БД (только для Terraform) |
| `CLOUDRU_PG_PROTO` | путь к proto (по умолчанию `proto/pg_min.proto`) |

Токен кэшируется в `~/.cache/cloudru/token` (файл 600) и перевыпускается до истечения.

## Команды

```bash
cloudru whoami                  # проект и срок действия токена
cloudru pg list                 # кластеры: имя, статус, версия, id
cloudru pg get finances-pg      # статус, спека, диски, подсети, DSN
cloudru pg suspend finances-pg  # остановить: платятся только диски
cloudru pg resume finances-pg   # запустить (1–3 минуты)
cloudru pg delete <id>          # удалить (FAILED-объекты так не удаляются, см. ниже)
cloudru token                   # access-токен для пайпов
```

Имя ищется по кластерам проекта; при неоднозначности (у Cloud.ru бывают дубли имён после неудачных
созданий) команда просит указать `id`.

## Terraform

В `terraform/` — инфраструктура сервиса: реестр образов, Managed PostgreSQL, ВМ под `docker compose`
(сеть, диск, интерфейс, публичный IP, метаданные образа для SSH), чтение квот и спек.

```bash
cd terraform
cp ../.env.example ../.env      # или используйте ~/.config/cloudru/env
set -a && . ~/.config/cloudru/env && set +a
cp tofu.tfrc.example tofu.tfrc   # и поправьте путь к локальному зеркалу провайдера
cp terraform.tfvars.example terraform.tfvars
tofu init && tofu plan
```

Провайдер `cloudru/cloud` 2.1.6 ставится из локального зеркала: бинарники есть в GitHub-релизах
`cloud-ru/evo-terraform`. Причина — `registry.terraform.io` доступен не с каждой машины.

## Что выяснено про API

Подробно — [docs/api-notes.md](docs/api-notes.md). Коротко:

- токен для API выдаёт `id.cloud.ru`, токен с `auth.iam.cloud.ru` отвергается (401 «Jwt issuer is
  not configured»);
- операции по кластеру требуют заголовок `x-project-id`, а query-параметры на item-путях шлюз
  ломает (415);
- stop/start — только gRPC (`ClusterService/Suspend|Resume`), рефлексия выключена, нужен локальный
  proto;
- `FAILED`-объект удаляется только с force-флагом, который через REST не передаётся — чистит
  поддержка;
- free tier — квота, а не гарантия: при нулевых квотах организации создание падает на
  `acquire_quota failed` даже с `free_tier=true`.

## Структура

```
bin/cloudru            единый CLI (bash, без сборки)
proto/pg_min.proto     минимальные определения ClusterService
terraform/             инфраструктура (провайдер cloudru/cloud 2.1.6)
docs/api-notes.md      проверенные эндпоинты, квирки, квоты
```
