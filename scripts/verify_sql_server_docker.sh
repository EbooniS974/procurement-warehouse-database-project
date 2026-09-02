#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_NAME="${CONTAINER_NAME:-procurement-sqlserver-verification}"
IMAGE="${IMAGE:-mcr.microsoft.com/mssql/server:2022-latest}"
SA_PASSWORD="${SA_PASSWORD:-CHANGE_ME_LOCAL_PASSWORD}"
HOST_PORT="${HOST_PORT:-14333}"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup EXIT

cleanup

docker pull "$IMAGE" >/dev/null

docker run -d \
  --name "$CONTAINER_NAME" \
  -e ACCEPT_EULA=Y \
  -e MSSQL_PID=Developer \
  -e MSSQL_SA_PASSWORD="$SA_PASSWORD" \
  -p "${HOST_PORT}:1433" \
  -v "$ROOT_DIR/sql:/work/sql:ro" \
  "$IMAGE" >/dev/null

echo "Waiting for SQL Server to accept connections..."

for _ in $(seq 1 60); do
  if docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -Q "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -i /work/sql/01_schema_and_security.sql
docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -i /work/sql/02_business_logic.sql
docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -i /work/sql/03_seed_and_demo_queries.sql

echo
echo "Verification summary:"
docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -d ProcurementWarehouseDB -W -s "|" -Q "
SELECT 'tables' AS metric, COUNT(*) AS value FROM sys.tables
UNION ALL
SELECT 'views', COUNT(*) FROM sys.views
UNION ALL
SELECT 'functions', COUNT(*) FROM sys.objects WHERE type IN ('FN','IF','TF')
UNION ALL
SELECT 'procedures', COUNT(*) FROM sys.procedures
UNION ALL
SELECT 'triggers', COUNT(*) FROM sys.triggers
UNION ALL
SELECT 'roles', COUNT(*) FROM sys.database_principals WHERE name IN ('procurement_clerk', 'warehouse_clerk', 'reporting_analyst');
"
