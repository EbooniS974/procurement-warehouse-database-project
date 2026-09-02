# Procurement and Warehouse Database Project

This repository contains a SQL Server based procurement and warehouse management system plus a Streamlit interface for exploring and executing the project workflows.

## What is in the repo

- `sql/01_schema_and_security.sql`
  Creates the database, tables, keys, inheritance model, roles, users, and constraints.
- `sql/02_business_logic.sql`
  Creates functions, views, triggers, stored procedures, and grants.
- `sql/03_seed_and_demo_queries.sql`
  Inserts sample data and includes the outer join demo queries.
- `ui/`
  Streamlit application with dashboard, suppliers, requests, offers/orders, warehouse, administration, approval workflow, budget tracking, quality control, and vendor claims modules.
- `docs/final-report.pdf`
  Final report.
- `scripts/start_local_demo_db.sh`
  Starts a local SQL Server Docker container, loads the SQL scripts, and writes a `.env` file for the UI.
- `scripts/create_share_zip.sh`
  Creates a clean zip archive for sharing the project without local secrets or virtualenv files.
- `scripts/verify_sql_server_docker.sh`
  Verifies the SQL scripts on SQL Server in Docker.

## Prerequisites

- Python `3.12` or similar modern Python version
- `pip`
- Docker, if you want the fastest local setup

Optional:

- Microsoft SQL Server, if you want to run against your own server instead of Docker
- Microsoft ODBC Driver for SQL Server, if you want `pyodbc` based connectivity

Python dependencies installed from `requirements.txt` include:

- `streamlit`
- `pandas`
- `pyodbc`
- `python-tds`

The UI can also connect with `python-tds` when SQL authentication is used and no ODBC driver is available.

## Quick Start

The simplest working path is Docker plus the helper script.

1. Create and activate a virtual environment.

```bash
python3 -m venv .venv
source .venv/bin/activate
```

2. Install Python dependencies.

```bash
pip install -r requirements.txt
```

3. Start the local demo SQL Server and load the project schema and sample data.

```bash
./scripts/start_local_demo_db.sh
```

What this does:

- pulls SQL Server 2022 Docker image if needed
- starts a local container on port `14333`
- runs all SQL scripts in the correct order
- creates a project-root `.env` file for the Streamlit UI

4. Start the UI from the repository root.

```bash
streamlit run ui/app.py
```

5. Open the local URL shown by Streamlit, usually:

```text
http://localhost:8501
```

If the setup is correct, the dashboard widgets should show real values instead of `N/A`.

If you only want to inspect the academic deliverable and not run the software, open:

```text
docs/final-report.pdf
```

## Everyday Run Commands

After the first setup, your normal workflow is usually:

```bash
source .venv/bin/activate
streamlit run ui/app.py
```

If the Docker database is not running, start it again:

```bash
docker start procurement-sqlserver-demo
```

If you want to rebuild the whole demo database from scratch:

```bash
./scripts/start_local_demo_db.sh
```

## Share as Zip

If you want to send this project to someone else, use the share script instead of zipping the whole folder manually:

```bash
./scripts/create_share_zip.sh
```

This creates:

```text
dist/procurement-warehouse-database-project.zip
```

The archive excludes local-only files and folders:

- `.env`
- `.venv`
- `__pycache__`
- `.pytest_cache`

Do not send `.env` if it contains a real password or connection string.

## Run After Unzipping

For the person receiving the zip:

1. Unzip the archive.
2. Open a terminal in the extracted project folder.
3. Create and activate a virtual environment.
4. Install dependencies.
5. Start the demo database or connect to an existing SQL Server.
6. Run Streamlit.

Minimal command sequence:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
./scripts/start_local_demo_db.sh
streamlit run ui/app.py
```

## Manual Database Setup

If you already have SQL Server and want to use it directly, run these scripts in order:

1. `sql/01_schema_and_security.sql`
2. `sql/02_business_logic.sql`
3. `sql/03_seed_and_demo_queries.sql`

Target DBMS is Microsoft SQL Server.

After that, configure the UI connection.

## UI Connection Configuration

The UI looks for database settings in this order:

1. shell environment variables
2. Streamlit secrets
3. project-root `.env` file

The easiest option is:

```bash
cp .env.example .env
```

Then edit `.env` for your SQL Server if needed.

Example `.env`:

```bash
DB_SERVER=localhost,14333
DB_NAME=ProcurementWarehouseDB
DB_DRIVER={ODBC Driver 18 for SQL Server}
DB_TRUSTED_CONNECTION=no
DB_USERNAME=sa
DB_PASSWORD=CHANGE_ME_LOCAL_PASSWORD
DB_ENCRYPT=yes
DB_TRUST_SERVER_CERTIFICATE=yes
```

### Option A: SQL authentication

Use:

```bash
DB_TRUSTED_CONNECTION=no
DB_USERNAME=sa
DB_PASSWORD=your_password
```

This works with:

- `pyodbc`, if an ODBC SQL Server driver is installed
- `python-tds`, if no ODBC driver is available

### Option B: Trusted connection

Use:

```bash
DB_TRUSTED_CONNECTION=yes
```

This path requires a working ODBC SQL Server driver because trusted connections are handled through `pyodbc`.

## Running the UI

Always run from the repository root:

```bash
streamlit run ui/app.py
```

If you change code or configuration, stop the Streamlit process and start it again.

## What the UI shows when something is wrong

### Dashboard shows `N/A`

This means the app started, but no live database connection is configured.

Check:

- `.env` exists in the project root
- `DB_SERVER` and `DB_NAME` are correct
- SQL Server is actually running
- if using SQL authentication, username and password are correct

### The page shows SQL text instead of table results

This is the same root cause: the app is in offline mode because the database connection is missing or invalid.

### First Docker start takes a long time

That is normal on the first run because SQL Server image download is large.

### SQL Server container is running but UI still cannot connect

Check:

```bash
cat .env
docker ps
```

For the local demo setup, you should typically see:

- container name: `procurement-sqlserver-demo`
- database port: `14333`
- `DB_SERVER=localhost,14333`

## Verification

Run the project checks:

```bash
pytest tests/test_project_artifacts.py tests/test_ui_db_config.py -q
```

Run live SQL Server verification in Docker:

```bash
./scripts/verify_sql_server_docker.sh
```

## Rebuilding the Report PDF

This is optional. The repository already includes a ready-to-submit PDF at `docs/final-report.pdf`.

Only rebuild if you modify the report or diagrams.

System tools required for rebuild:

- `graphviz` for `dot`
- `pandoc`
- a LaTeX engine compatible with `xelatex`

Python package requirement for rebuild:

- `Pillow`

To regenerate the diagrams and the report PDF:

```bash
./docs/build-final-report.sh
```

## Useful Files

- [README.md](/home/batu/Desktop/databaseproje/README.md)
- [.env.example](/home/batu/Desktop/databaseproje/.env.example)
- [scripts/start_local_demo_db.sh](/home/batu/Desktop/databaseproje/scripts/start_local_demo_db.sh)
- [scripts/verify_sql_server_docker.sh](/home/batu/Desktop/databaseproje/scripts/verify_sql_server_docker.sh)
- [ui/app.py](/home/batu/Desktop/databaseproje/ui/app.py)
- [ui/db.py](/home/batu/Desktop/databaseproje/ui/db.py)
