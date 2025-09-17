#!/bin/bash

set -euo pipefail

# Choose docker compose command (v2: `docker compose`, v1: `docker-compose`)
COMPOSE="docker compose"
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
fi

find . | grep -E "(__pycache__|\.tox|\.eggs|\.pyc|\.pyo$)" | xargs rm -rf || true

$COMPOSE -f docker-compose2.yml down -v || true

# Toggle Docker build cache by WEKO_USE_CACHE only.
# Default: no-cache (historical behavior). Set WEKO_USE_CACHE=1 to enable cache.
NO_CACHE_FLAG="--no-cache"
case "${WEKO_USE_CACHE:-}" in
  1|true|TRUE|yes|YES) NO_CACHE_FLAG="" ;;
  *) NO_CACHE_FLAG="--no-cache" ;;
esac

if [ -n "${NO_CACHE_FLAG}" ]; then
  echo "[INFO] Building images (no-cache: on)"
else
  echo "[INFO] Building images (no-cache: off; using cache)"
fi
DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 $COMPOSE -f docker-compose2.yml build ${NO_CACHE_FLAG} --force-rm

# Initialize resources
$COMPOSE -f docker-compose2.yml run --rm web ./scripts/populate-instance.sh
docker cp scripts/demo/item_type.sql $($COMPOSE -f docker-compose2.yml ps -q postgresql):/tmp/item_type.sql
$COMPOSE -f docker-compose2.yml exec postgresql psql -U invenio -d invenio -f /tmp/item_type.sql
docker cp scripts/demo/indextree.sql $($COMPOSE -f docker-compose2.yml ps -q postgresql):/tmp/indextree.sql
$COMPOSE -f docker-compose2.yml exec postgresql psql -U invenio -d invenio -f /tmp/indextree.sql
$COMPOSE -f docker-compose2.yml run --rm web invenio workflow init action_status,Action
docker cp scripts/demo/defaultworkflow.sql $($COMPOSE -f docker-compose2.yml ps -q postgresql):/tmp/defaultworkflow.sql
$COMPOSE -f docker-compose2.yml exec postgresql psql -U invenio -d invenio -f /tmp/defaultworkflow.sql
docker cp scripts/demo/doi_identifier.sql $($COMPOSE -f docker-compose2.yml ps -q postgresql):/tmp/doi_identifier.sql
$COMPOSE -f docker-compose2.yml exec postgresql psql -U invenio -d invenio -f /tmp/doi_identifier.sql
docker cp postgresql/ddl/W-OA-user_activity_log.sql $($COMPOSE -f docker-compose2.yml ps -q postgresql):/tmp/W-OA-user_activity_log.sql
$COMPOSE -f docker-compose2.yml exec postgresql psql -U invenio -d invenio -f /tmp/W-OA-user_activity_log.sql
# docker cp scripts/demo/resticted_access.sql $($COMPOSE -f docker-compose2.yml ps -q postgresql):/tmp/resticted_access.sql
# $COMPOSE -f docker-compose2.yml exec postgresql psql -U invenio -d invenio -f /tmp/resticted_access.sql

$COMPOSE -f docker-compose2.yml run --rm web invenio assets build
$COMPOSE -f docker-compose2.yml run --rm web invenio collect -v

# Start services
$COMPOSE -f docker-compose2.yml up -d
