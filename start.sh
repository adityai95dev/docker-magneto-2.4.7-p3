#!/bin/bash
set -e
source .env

docker compose stop php nginx mariadb redis opensearch || true

docker compose up -d php nginx mariadb redis opensearch

