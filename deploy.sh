#!/usr/bin/env bash
set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SYMFONY_DIR="${BASE_DIR}/symfony"
ENV_FILE="${BASE_DIR}/.env"

# === Load .env file and extract APP_NAME ===
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ .env file not found!${RESET}"
    exit 1
fi
APP_NAME=$(grep -E '^APP_NAME=' "$ENV_FILE" | cut -d '=' -f2 | tr -d '"')
WEB_CONTAINER="${APP_NAME}-apache"

# === Check for dry-run mode ===
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🔍 Dry-run mode enabled — no commands will be executed.${RESET}"
else
    DRY_RUN=false
fi

echo -e "${YELLOW}=== Symfony Deployment Script ===${RESET}"
cd "$SYMFONY_DIR"

# 1️⃣ Check for local changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}⚠️  There are uncommitted changes in ./symfony!${RESET}"
    echo "Please commit, stash or reset before deploying."
    exit 1
fi

# 2️⃣ Ask for branch
read -rp "🔀 Enter branch to deploy [master]: " BRANCH
BRANCH=${BRANCH:-master}

# 3️⃣ Pull latest code
echo -e "${GREEN}→ Pulling latest changes from branch '${BRANCH}'...${RESET}"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull origin "$BRANCH"

# 4️⃣ Ensure container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${WEB_CONTAINER}$"; then
    echo -e "${YELLOW}⚠️ Web container '${WEB_CONTAINER}' is not running.${RESET}"
    echo -e "${YELLOW}→ Starting container...${RESET}"
    docker compose up -d "${WEB_CONTAINER}" || docker start "${WEB_CONTAINER}"
fi

# 5️⃣ Run commands inside container
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Would run inside container '${WEB_CONTAINER}':${RESET}"
    cat <<EOF
composer install --no-dev --optimize-autoloader --no-interaction
rm -rf public/assets
bin/console asset-map:compile
bin/console cache:clear --no-warmup
bin/console cache:warmup
bin/console doctrine:migrations:migrate --no-interaction
docker restart ${WEB_CONTAINER}
EOF
else
    echo -e "${GREEN}→ Running Symfony maintenance commands inside '${WEB_CONTAINER}'...${RESET}"
    docker exec -i "${WEB_CONTAINER}" bash -c "
        cd /var/www/html &&
        composer install --no-dev --optimize-autoloader --no-interaction &&
        rm -rf public/assets || true &&
        bin/console asset-map:compile &&
        bin/console cache:clear --no-warmup &&
        bin/console cache:warmup &&
        bin/console doctrine:migrations:migrate --no-interaction
    "

    echo -e "${GREEN}→ Restarting web container '${WEB_CONTAINER}'...${RESET}"
    docker restart "${WEB_CONTAINER}"
    echo -e "${GREEN}✅ Deployment complete!${RESET}"
fi
