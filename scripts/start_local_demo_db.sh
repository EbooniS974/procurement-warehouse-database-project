#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_NAME="${CONTAINER_NAME:-procurement-sqlserver-demo}"
IMAGE="${IMAGE:-mcr.microsoft.com/mssql/server:2022-latest}"
SA_PASSWORD="${SA_PASSWORD:-CHANGE_ME_LOCAL_PASSWORD}"
HOST_PORT="${HOST_PORT:-14333}"
DB_NAME="ProcurementWarehouseDB"

cleanup_existing_container() {
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    docker rm -f "$CONTAINER_NAME" >/dev/null
  fi
}

cleanup_existing_container

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

docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -i /work/sql/01_schema_and_security.sql >/dev/null
docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -i /work/sql/02_business_logic.sql >/dev/null
docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -I -i /work/sql/03_seed_and_demo_queries.sql >/dev/null

cat > "$ROOT_DIR/.env" <<EOF
DB_SERVER=localhost,${HOST_PORT}
DB_NAME=${DB_NAME}
DB_DRIVER={ODBC Driver 18 for SQL Server}
DB_TRUSTED_CONNECTION=no
DB_USERNAME=sa
DB_PASSWORD=${SA_PASSWORD}
DB_ENCRYPT=yes
DB_TRUST_SERVER_CERTIFICATE=yes
EOF

echo
echo "Local demo database is ready."
echo "Container: $CONTAINER_NAME"
echo "Database:  $DB_NAME"
echo "Port:      $HOST_PORT"
echo
echo "A .env file was written to $ROOT_DIR/.env."
echo "Start the UI with:"
echo "  streamlit run ui/app.py"
