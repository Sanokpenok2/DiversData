# DiversData

Проект сбора данных об устрицах: Telegram-бот для дайверов и веб-сайт для учёных.

## GitHub Pages (Web App для карты)

Web App размещается в папке `docs/` и публикуется через GitHub Actions.

### Публикация (один раз)

1. Создайте репозиторий на GitHub, например `DiversData`.
2. В корне проекта выполните:

```powershell
cd c:\Users\User\RubymineProjects\DiversData
git init
git add .
git commit -m "Initial commit with DiversBot and GitHub Pages"
git branch -M main
git remote add origin https://github.com/<ваш-логин>/DiversData.git
git push -u origin main
```

3. На GitHub откройте репозиторий → **Settings** → **Pages**.
4. В разделе **Build and deployment** → **Source** выберите **GitHub Actions**.
5. После push workflow `.github/workflows/pages.yml` автоматически опубликует сайт (1–3 минуты).

### URL для бота

После публикации Web App будет доступен по адресу:

```
https://<ваш-логин>.github.io/DiversData/
```

Добавьте в `DiversBot/.env`:

```
WEB_APP_URL=https://<ваш-логин>.github.io/DiversData/
```

Проверка: откройте URL в браузере — должна загрузиться карта OpenStreetMap.

## Компоненты

| Папка | Описание |
|-------|----------|
| `DiversBot/` | Telegram-бот на Ruby + PostgreSQL |
| `DiversWebSite/` | Веб-сайт для учёных (в разработке) |
| `docs/` | Web App для выбора точки на карте (GitHub Pages) |

Подробнее о боте: [DiversBot/README.md](DiversBot/README.md)
