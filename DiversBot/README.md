# DiversBot — бот MAX для сбора данных об устрицах

Чат-бот на Ruby для мессенджера [MAX](https://max.ru): сбор наблюдений об устрицах от дайверов с фотографиями и сохранение в PostgreSQL. Данные предназначены для последующего просмотра учёными через веб-сайт (в разработке).

## Возможности

- Пошаговый диалог с инструкцией при `/start`
- Сбор даты наблюдения, места, типа встречи, глубины, фото и описания субстрата
- Три способа указания места:
  - **Интерактивная карта** (мини-приложение MAX + OpenLayers)
  - **Координаты** вручную с проверкой точки на карте
  - **Текстовое описание** акватории
- Загрузка фото плотности поселения, субстрата и дополнительных снимков
- Защита от спама (лимит сообщений в минуту, дневной лимит отчётов, cooldown)
- Хранение данных в PostgreSQL для интеграции с сайтом

## Требования

- Ruby >= 3.2
- PostgreSQL >= 13
- Токен чат-бота MAX ([platform.max.ru](https://platform.max.ru))
- HTTPS-хостинг для мини-приложения карты (опционально)

## Быстрый старт

### 1. Установка зависимостей

```bash
cd DiversBot
bundle install
```

### 2. База данных

```sql
CREATE DATABASE divers_data;
```

### 3. Конфигурация

```bash
cp .env.example .env
```

| Переменная | Описание |
|---|---|
| `MAX_BOT_TOKEN` | Токен бота из кабинета MAX для партнёров |
| `MAX_API_BASE_URL` | URL API (по умолчанию `https://platform-api2.max.ru/`) |
| `DATABASE_URL` | Строка подключения PostgreSQL |
| `WEB_APP_URL` | HTTPS-URL карты (необязательно) |
| `SPAM_MAX_MESSAGES_PER_MINUTE` | Лимит сообщений в минуту (по умолчанию 20) |
| `SPAM_MAX_REPORTS_PER_DAY` | Лимит отчётов в сутки (по умолчанию 10) |
| `SPAM_COOLDOWN_SECONDS` | Минимальный интервал между сообщениями (по умолчанию 1) |

### 4. Миграции

```bash
bundle exec rake db:migrate
# или
ruby db/migrate.rb
```

Если база была создана для Telegram-версии, миграция `002_rename_for_max.rb` переименует колонки автоматически.

### 5. Запуск бота

```bash
ruby bin/bot
```

Бот работает в режиме long polling (удобно для разработки). Для production MAX рекомендует [webhook](https://dev.max.ru/docs-api/methods/POST/subscriptions).

## Мини-приложение для карты

Файл `web/map_picker.html` — мини-приложение MAX для выбора точки на карте (регион: Крым, Чёрное и Азовское море).

**Требования:** URL должен быть доступен по HTTPS. Подключите мини-приложение в настройках бота на [platform.max.ru](https://platform.max.ru).

### Размещение

- **GitHub Pages:** скопируйте `docs/index.html` в репозиторий и укажите `WEB_APP_URL`
- **Локально:** любой HTTPS-хостинг статики

Режим браузера (`?browser=1`) — для копирования координат, если мини-приложение недоступно.

## Схема БД

### `user_sessions`

| Колонка | Тип | Описание |
|---|---|---|
| `max_user_id` | bigint | ID пользователя MAX |
| `state` | string | Текущий шаг диалога |
| `data` | jsonb | Черновик отчёта и ID сообщений |

### `reports`

| Колонка | Тип | Описание |
|---|---|---|
| `max_user_id` | bigint | ID пользователя MAX |
| `observation_date` | date | Дата наблюдения |
| `location_type` | string | `map_point`, `coordinates`, `text_description` |
| `latitude`, `longitude` | float | Координаты |
| `encounter_type` | string | `single` или `multiple_in_radius` |
| `depth_m` | float | Глубина в метрах |
| `substrate_type` | text | Описание субстрата |

### `report_photos`

| Колонка | Тип | Описание |
|---|---|---|
| `attachment_token` | string | Токен вложения MAX для повторной отправки |
| `photo_type` | string | `density`, `substrate`, `additional` |

## Структура проекта

```
DiversBot/
├── bin/bot                  # Точка входа
├── config/boot.rb           # Загрузка окружения
├── db/migrations/           # Миграции Sequel
├── lib/divers_bot/
│   ├── bot.rb               # Long polling MAX API
│   ├── messenger/           # Парсинг входящих обновлений
│   ├── models/              # UserSession, Report, ReportPhoto
│   └── services/            # Диалог, тексты, сводка
└── web/map_picker.html      # Карта для мини-приложения
```

## API MAX

- Документация: [dev.max.ru/docs-api](https://dev.max.ru/docs-api)
- Ruby-клиент: [max_bot_api](https://rubygems.org/gems/max_bot_api)
- MAX Bridge (мини-приложения): [dev.max.ru/docs/webapps/bridge](https://dev.max.ru/docs/webapps/bridge)

## TODO

- [ ] Webhook-режим для production (Rack/Sinatra)
- [ ] Скачивание и хранение фото на диск/S3 (сейчас хранится токен MAX)
- [ ] Веб-сайт для просмотра данных учёными
