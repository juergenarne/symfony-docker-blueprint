#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================
# CONFIGURATION
# ============================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYMFONY_DIR="$BASE_DIR/symfony"
BACKUP_DIR="$BASE_DIR/backups"

DEFAULT_BRANCH="main/prod"

WEB_SERVICE="web"
DB_SERVICE="db"
WORKER_SERVICE="worker"

DRY_RUN=false
BRANCH="$DEFAULT_BRANCH"

# ============================================
# COLORS
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

info() {
    echo -e "${BLUE}➜ $1${RESET}"
}

success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

error() {
    echo -e "${RED}✗ $1${RESET}" >&2
}

# ============================================
# ERROR HANDLING
# ============================================

on_error() {
    local exit_code=$?

    error "Deployment fehlgeschlagen!"
    error "Zeile: $1"
    error "Exit-Code: $exit_code"

    echo
    warning "Ein automatisches Rollback wurde NICHT ausgeführt."
    warning "Prüfe den Zustand der Anwendung."

    exit "$exit_code"
}

trap 'on_error $LINENO' ERR

# ============================================
# ARGUMENTS
# ============================================

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            echo "Usage: ./deploy.sh [branch] [--dry-run]"
            exit 0
            ;;
        -*)
            error "Unbekannte Option: $arg"
            exit 1
            ;;
        *)
            BRANCH="$arg"
            ;;
    esac
done

# ============================================
# START
# ============================================

echo
echo "============================================"
echo "       SYMFONY PRODUCTION DEPLOYMENT"
echo "============================================"
echo
echo "Branch:  $BRANCH"
echo "Dry-run: $DRY_RUN"
echo

cd "$BASE_DIR"

# ============================================
# 1. PREREQUISITES
# ============================================

info "Prüfe Voraussetzungen..."

command -v git >/dev/null
command -v docker >/dev/null

docker compose version >/dev/null

test -d "$SYMFONY_DIR/.git"
test -f "$SYMFONY_DIR/composer.json"
test -f "$BASE_DIR/docker-compose.yml"

# .env is not in git - without the real values the containers would be recreated with wrong DB credentials
if [[ ! -f "$BASE_DIR/.env" ]]; then
    error ".env fehlt! Vorlage: cp .env.dist .env - und die echten Werte eintragen."
    exit 1
fi

if grep -qE '^MYSQL_(ROOT_)?PASSWORD=(CHANGE_ME|password)?$' "$BASE_DIR/.env"; then
    error ".env enthält noch Platzhalter-Passwörter (CHANGE_ME/password)!"
    exit 1
fi

success "Voraussetzungen erfüllt"

# ============================================
# 2. GIT STATUS
# ============================================

info "Prüfe Git-Repository..."

cd "$SYMFONY_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    error "Lokale Änderungen im Symfony-Repository!"
    echo
    git status --short
    echo
    error "Bitte Änderungen zuerst sichern."
    exit 1
fi

success "Git-Working-Tree sauber"

# ============================================
# 3. DRY RUN
# ============================================

if [[ "$DRY_RUN" == true ]]; then

    echo
    warning "DRY-RUN: Es werden keine Änderungen vorgenommen."
    echo

    echo "Folgende Schritte würden ausgeführt:"
    echo
    echo "1. Git-Branch $BRANCH aktualisieren"
    echo "2. MariaDB-Backup erstellen"
    echo "3. Composer-Abhängigkeiten installieren"
    echo "4. Importmap-Abhängigkeiten installieren"
    echo "5. Symfony Assets kompilieren"
    echo "6. Doctrine-Migrationen ausführen"
    echo "7. Symfony Cache aktualisieren"
    echo "8. Web-Container und Mail-Worker neu starten"
    echo "9. Anwendung überprüfen"

    echo
    success "Dry-run abgeschlossen"
    exit 0
fi

# ============================================
# 4. CONTAINER CHECK
# ============================================

cd "$BASE_DIR"

info "Prüfe Docker-Container..."

WEB_RUNNING="$(docker compose ps --status running -q "$WEB_SERVICE")"
DB_RUNNING="$(docker compose ps --status running -q "$DB_SERVICE")"

if [[ -z "$WEB_RUNNING" ]]; then
    error "Web-Container läuft nicht!"
    exit 1
fi

if [[ -z "$DB_RUNNING" ]]; then
    error "Datenbank-Container läuft nicht!"
    exit 1
fi

success "Web und Datenbank laufen"

# ============================================
# 5. FETCH GIT
# ============================================

info "Hole neuesten Git-Stand..."

cd "$SYMFONY_DIR"

git fetch origin "$BRANCH"

TARGET_COMMIT="$(git rev-parse FETCH_HEAD)"
CURRENT_COMMIT="$(git rev-parse HEAD)"

echo "Aktuell: $CURRENT_COMMIT"
echo "Ziel:    $TARGET_COMMIT"

if [[ "$CURRENT_COMMIT" == "$TARGET_COMMIT" ]]; then
    success "Code bereits aktuell"
else
    git checkout --detach "$TARGET_COMMIT"
    success "Code aktualisiert"
fi

# ============================================
# 6. DATABASE BACKUP
# ============================================

cd "$BASE_DIR"

info "Erstelle MariaDB-Backup..."

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/mariadb_${TIMESTAMP}.sql"

# Zugangsdaten werden aus der Container-Umgebung gelesen.
# Sie werden nicht im Skript gespeichert.

docker compose exec -T "$DB_SERVICE" sh -c '
    exec mariadb-dump \
        -h 127.0.0.1 \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        --events \
        "$MYSQL_DATABASE"
' > "$BACKUP_FILE"

if [[ ! -s "$BACKUP_FILE" ]]; then
    error "Datenbank-Backup ist leer!"
    exit 1
fi

chmod 600 "$BACKUP_FILE"

success "Backup erstellt: $BACKUP_FILE"

# ============================================
# 7. COMPOSER
# ============================================

info "Installiere Composer-Abhängigkeiten..."

docker compose exec -T \
    -e APP_ENV=prod \
    -e APP_DEBUG=0 \
    "$WEB_SERVICE" \
    composer install \
        --no-dev \
        --prefer-dist \
        --optimize-autoloader \
        --no-interaction \
        --no-progress

success "Composer abgeschlossen"

# ============================================
# 8. IMPORTMAP
# ============================================

info "Installiere Importmap-Abhängigkeiten..."

docker compose exec -T \
    -e APP_ENV=prod \
    -e APP_DEBUG=0 \
    "$WEB_SERVICE" \
    php bin/console importmap:install --env=prod

success "Importmap aktualisiert"

# ============================================
# 9. ASSET MAPPER
# ============================================

info "Kompiliere Frontend-Assets..."

docker compose exec -T \
    -e APP_ENV=prod \
    -e APP_DEBUG=0 \
    "$WEB_SERVICE" \
    php bin/console asset-map:compile --env=prod

success "Frontend-Assets kompiliert"

# ============================================
# 10. DATABASE MIGRATIONS
# ============================================

info "Führe Doctrine-Migrationen aus..."

docker compose exec -T \
    -e APP_ENV=prod \
    -e APP_DEBUG=0 \
    "$WEB_SERVICE" \
    php bin/console doctrine:migrations:migrate \
        --no-interaction \
        --env=prod

success "Migrationen abgeschlossen"

# ============================================
# 11. SYMFONY CACHE
# ============================================

info "Aktualisiere Symfony Cache..."

docker compose exec -T \
    -e APP_ENV=prod \
    -e APP_DEBUG=0 \
    "$WEB_SERVICE" \
    php bin/console cache:clear --env=prod

docker compose exec -T \
    -e APP_ENV=prod \
    -e APP_DEBUG=0 \
    "$WEB_SERVICE" \
    php bin/console cache:warmup --env=prod

success "Cache aktualisiert"

# ============================================
# 12. RESTART WEB CONTAINER + MAIL WORKER
# ============================================

info "Starte Web-Container neu..."

docker compose restart "$WEB_SERVICE"

success "Web-Container neu gestartet"

info "Starte Mail-Worker (neu)..."

# Legt den Worker beim ersten Deploy an, danach Neustart, damit er den neuen Code lädt.
docker compose up -d "$WORKER_SERVICE"
docker compose restart "$WORKER_SERVICE"

success "Mail-Worker gestartet"

# ============================================
# 13. HEALTH CHECK
# ============================================

info "Prüfe Anwendung..."

sleep 3

docker compose ps

if [[ -z "$(docker compose ps --status running -q "$WORKER_SERVICE")" ]]; then
    warning "Mail-Worker läuft nicht - Mails werden nicht verschickt!"
    warning "Log: docker compose logs --tail=50 $WORKER_SERVICE"
    exit 1
fi

success "Mail-Worker läuft"

HTTP_CODE="$(curl -k -L -s -o /dev/null -w '%{http_code}' \
    --max-time 20 \
    https://buerofueralles.berlin || true)"

echo
echo "HTTP Status: $HTTP_CODE"

if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
    success "Website erreichbar"
else
    warning "Website liefert HTTP $HTTP_CODE"
    warning "Bitte Anwendung prüfen!"
    exit 1
fi

# ============================================
# FINISHED
# ============================================

echo
echo "============================================"
echo -e "${GREEN}       DEPLOYMENT ERFOLGREICH${RESET}"
echo "============================================"
echo
echo "Branch:  $BRANCH"
echo "Commit:  $TARGET_COMMIT"
echo "Backup:  $BACKUP_FILE"
echo
