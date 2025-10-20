#!/bin/bash
set -euo pipefail

echo "🚀 Starte Docker-Container..."

# Container bauen (wenn nötig) und starten
docker compose up -d --build

echo "✅ Container gestartet!"
docker compose ps
docker compose logs -f
