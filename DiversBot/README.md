# DiversBot — Telegram-бот для сбора данных об устрицах

Telegram-бот на Ruby для дайверов: сбор наблюдений об устрицах с фотографиями и сохранение в PostgreSQL. Данные предназначены для последующего просмотра учёными через веб-сайт (в разработке).

## Возможности

- Пошаговый диалог с инструкцией при `/start`
- Сбор даты наблюдения, места, типа встречи, глубины, фото и описания субстрата
- Три способа указания места:
  - **Интерактивная карта** (Telegram Web App + Leaflet/OpenStreetMap)
  - **Координаты** вручную с проверкой точки на карте
  - **Текстовое описание** акватории
- Загрузка фото плотности поселения, субстрата и дополнительных снимков с подписями
- Защита от спама (лимит сообщений в минуту, дневной лимит отчётов, cooldown)
- Хранение данных в PostgreSQL для интеграции с сайтом

## Требования

- Ruby >= 3.2
- PostgreSQL >= 13
- Токен Telegram-бота от [@BotFather](https://t.me/BotFather)
- HTTPS-хостинг для Web App карты (опционально, для выбора точки на карте)

## Быстрый старт

### 1. Установка зависимостей

```bash
cd DiversBot
bundle install
```

### 2. База данных

Создайте базу PostgreSQL:

```sql
CREATE DATABASE divers_data;
```

### 3. Конфигурация

Скопируйте пример конфигурации и заполните значения:

```bash
cp .env.example .env
```

| Переменная | Описание |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Токен бота от BotFather |
| `DATABASE_URL` | Строка подключения PostgreSQL |
| `WEB_APP_URL` | HTTPS-URL файла `web/map_picker.html` (необязательно) |
| `SPAM_MAX_MESSAGES_PER_MINUTE` | Лимит сообщений в минуту (по умолчанию 20) |
| `SPAM_MAX_REPORTS_PER_DAY` | Лимит отчётов в сутки на пользователя (по умолчанию 10) |
| `SPAM_COOLDOWN_SECONDS` | Минимальный интервал между сообщениями (по умолчанию 1) |

### 4. Миграции

```bash
bundle exec rake db:migrate
# или
ruby db/migrate.rb
```

### 5. Запуск бота

```bash
ruby bin/bot
```

Бот работает в режиме long polling. Для production рекомендуется запуск через systemd, Docker или аналогичный процесс-менеджер.

## Web App для карты

Файл `web/map_picker.html` — мини-приложение Telegram для ручного выбора точки на карте.

**Требования Telegram:** URL должен быть доступен по HTTPS.

### Варианты размещения

1. **Статический хостинг** (GitHub Pages, Netlify, Vercel и т.п.) — загрузите `web/map_picker.html`
2. **Локально для теста** — используйте ngrok или cloudflared:

```bash
# Пример с Python
cd web
python -m http.server 8080

# В другом терминале (ngrok)
ngrok http 8080
```

Укажите полученный HTTPS-URL в `.env`:

```
WEB_APP_URL=https://xxxx.ngrok.io/map_picker.html
```

Если `WEB_APP_URL` не задан, бот предложит только отправку текущей геопозиции (кнопка «Отправить геопозицию»).

## Сценарий работы бота

```
/start → Инструкция → «Начать отчёт»
  → Дата наблюдения (ДД.ММ.ГГГГ)
  → Способ указания места (карта / координаты / описание)
  → Тип встречи (единичная / множественная + радиус)
  → Глубина + точность (приблизительная / точная)
  → Фото плотности поселения (мин. 1) → «Готово»
  → Тип субстрата → фото субстрата (опционально)
  → Доп. информация (опционально)
  → Доп. фото с подписями (опционально) → «Завершить отчёт»
  → Сохранение в БД
```

Команды:
- `/start` — инструкция и начало
- `/cancel` — отмена текущего отчёта
- `/help` — показать инструкцию

## Структура базы данных

### `reports` — основные отчёты

| Поле | Тип | Описание |
|---|---|---|
| `observation_date` | date | Дата наблюдения |
| `location_type` | string | `map_point`, `coordinates`, `text_description` |
| `latitude`, `longitude` | float | Координаты (если указаны) |
| `location_description` | text | Текстовое описание места |
| `encounter_type` | string | `single` или `multiple_in_radius` |
| `encounter_radius_m` | float | Радиус (для множественной встречи) |
| `depth_m` | float | Глубина в метрах |
| `depth_is_approximate` | boolean | Приблизительная / точная |
| `substrate_type` | text | Тип субстрата |
| `additional_info` | text | Дополнительная информация |
| `telegram_user_id` | bigint | ID пользователя Telegram |

### `report_photos` — фотографии

| Поле | Тип | Описание |
|---|---|---|
| `report_id` | FK | Связь с отчётом |
| `telegram_file_id` | string | ID файла в Telegram |
| `photo_type` | string | `density`, `substrate`, `additional` |
| `caption` | text | Подпись (для доп. фото) |

### `user_sessions` — состояние диалога

Хранит текущий шаг и промежуточные данные (JSONB) для каждого пользователя.

## Структура проекта

```
DiversBot/
├── bin/bot                  # Точка входа
├── config/boot.rb           # Загрузка зависимостей
├── db/
│   ├── migrate.rb
│   └── migrations/
├── lib/divers_bot/
│   ├── bot.rb               # Запуск Telegram-клиента
│   ├── database.rb
│   ├── models/              # Report, ReportPhoto, UserSession
│   └── services/
│       ├── conversation.rb  # Логика диалога
│       ├── messages.rb      # Тексты сообщений
│       └── spam_guard.rb    # Защита от спама
├── web/map_picker.html      # Web App для карты
├── .env.example
├── Gemfile
└── README.md
```

## Дальнейшее развитие

- [ ] Модерация отчётов
- [ ] Примеры фотографий в инструкции
- [ ] Webhook вместо long polling для production
- [ ] Интеграция с сайтом DiversWebSite
- [ ] Скачивание и хранение фото на диск/S3 (сейчас хранится `file_id` Telegram)

## Лицензия

Внутренний проект DiversData.
