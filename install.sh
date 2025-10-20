#!/usr/bin/env bash
set -e  # exit immediately on error

# === Colors for pretty output ===
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

# === Base directories ===
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SYMFONY_DIR="${BASE_DIR}/symfony"

echo -e "${YELLOW}=== Symfony Project Installer ===${RESET}"

# 1️⃣ Check if symfony directory exists
if [ ! -d "$SYMFONY_DIR" ]; then
    echo -e "${YELLOW}The 'symfony' directory does not exist — creating it...${RESET}"
    mkdir -p "$SYMFONY_DIR"
fi

# 2️⃣ Check if symfony directory is empty
if [ -z "$(ls -A "$SYMFONY_DIR")" ]; then
    echo -e "${YELLOW}The 'symfony' directory is empty.${RESET}"
    echo
    read -rp "🔗 Please enter the Git repository URL to clone: " REPO_URL

    if [ -z "$REPO_URL" ]; then
        echo -e "${RED}No repository URL provided. Exiting.${RESET}"
        exit 1
    fi

    # 3️⃣ Clone repository
    echo -e "${GREEN}→ Cloning repository into ${SYMFONY_DIR}...${RESET}"
    git clone "$REPO_URL" "$SYMFONY_DIR"

    # 4️⃣ Done
    echo -e "${GREEN}✅ Repository cloned successfully!${RESET}"
else
    echo -e "${GREEN}✅ The 'symfony' directory is not empty — skipping clone.${RESET}"
fi
