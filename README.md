# spacebot-docker

Локальный запуск Spacebot через Docker Compose.

## Что делает конфиг

Сервис `spacebot`:
- поднимается из образа `ghcr.io/spacedriveapp/spacebot:full`;
- слушает порт `19898`;
- монтирует Docker socket (`/var/run/docker.sock`);
- монтирует папку с проектами в контейнер по пути:
  `/data/agents/main/workspace/projects`.

## Как избежать хардкода пути

В `docker-compose.yml` используется переменная:

```yaml
- ${PROJECTS_DIR:-./..}:/data/agents/main/workspace/projects
```

Это означает:
- если `PROJECTS_DIR` задана в `.env` или в окружении, будет использована она;
- если нет, берется дефолт `./..` (родительская папка текущего проекта).

## Настройка `.env`

Пример:

```env
OPENROUTER_API_KEY=your_key_here
PROJECTS_DIR=./..
```

Для другой машины можно указать абсолютный путь, например:

```env
PROJECTS_DIR=/home/user/PROJECTS
```

## Запуск

```bash
docker compose up -d
```

Проверка:

```bash
docker compose ps
docker compose logs -f spacebot
```

Остановка:

```bash
docker compose down
```

