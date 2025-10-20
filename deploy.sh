#!/usr/bin/env bash
set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SYMFONY_DIR="${BASE_DIR}/symfony"
WEB_CONTAINER=$(docker compose ps -q web)

echo -e "${YELLOW}=== Symfony Deployment Script ===${RESET}"

# 1️⃣ Check if there are local changes
cd "$SYMFONY_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}⚠️  There are uncommitted changes in ./symfony!${RESET}"
    echo "Please commit, stash or reset before deploying."
    exit 1
fi

# 2️⃣ Ask for branch to deploy
read -rp "🔀 Enter branch to deploy [master]: " BRANCH
BRANCH=${BRANCH:-master}

# 3️⃣ Pull latest code
echo -e "${GREEN}→ Pulling latest changes from branch '${BRANCH}'...${RESET}"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull origin "$BRANCH"

# 4️⃣ Run deployment commands inside Docker container
echo -e "${GREEN}→ Running composer install inside container...${RESET}"
docker compose exec -T web bash -c "cd /var/www/html && composer install --no-dev --optimize-autoloader --no-interaction"

echo -e "${GREEN}→ Clearing and rebuilding assets & cache...${RESET}"
docker compose exec -T web bash -c "
    cd /var/www/html &&
    rm -rf public/assets || true &&
    bin/console asset-map:compile &&
    bin/console cache:clear --no-warmup &&
    bin/console cache:warmup &&
    bin/console doctrine:migrations:migrate --no-interaction
"

# 5️⃣ Restart the web container
echo -e "${GREEN}→ Restarting web container...${RESET}"
docker compose restart web

echo -e "${GREEN}✅ Deployment complete!${RESET}"
