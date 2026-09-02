from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable, Sequence

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV_FILE = PROJECT_ROOT / ".env"


def _load_dotenv_file(path: Path | None = None) -> None:
    path = path or DEFAULT_ENV_FILE
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            os.environ.setdefault(key, value)


def _get_streamlit_secret(name: str) -> str | None:
    try:
        import streamlit as st
    except Exception:
        return None

    try:
        value = st.secrets.get(name)
        if value not in (None, ""):
            return str(value)

        database_section = st.secrets.get("database")
        if database_section and name in database_section:
            value = database_section.get(name)
            if value not in (None, ""):
                return str(value)
    except Exception:
        return None

    return None


def _get_setting(name: str, default: str | None = None) -> str | None:
    _load_dotenv_file()

    env_value = os.getenv(name)
    if env_value not in (None, ""):
        return env_value

    secret_value = _get_streamlit_secret(name)
    if secret_value not in (None, ""):
        return secret_value

    return default


def _parse_server_endpoint(server: str) -> tuple[str, int | None]:
    if "," in server:
        host, port = server.rsplit(",", 1)
    elif ":" in server:
        host, port = server.rsplit(":", 1)
    else:
        return server, None

    host = host.strip()
    port = port.strip()
    return host, int(port) if port else None


def _prepare_sql_for_driver(sql: str, params: Sequence[object] | None = None) -> str:
    if not params:
        return sql

    if _has_pyodbc_driver():
        return sql

    return sql.replace("?", "%s")


def _build_connection_string() -> str:
    connection_string = _get_setting("DB_CONNECTION_STRING")
    if connection_string:
        return connection_string

    driver = _get_setting("DB_DRIVER", "{ODBC Driver 18 for SQL Server}")
    server = _get_setting("DB_SERVER")
    database = _get_setting("DB_NAME")

    if not server or not database:
        raise RuntimeError(
            "Database connection is not configured. Create a .env file or set DB_CONNECTION_STRING or DB_SERVER and DB_NAME."
        )

    trusted = (_get_setting("DB_TRUSTED_CONNECTION", "yes") or "yes").lower()
    username = _get_setting("DB_USERNAME")
    password = _get_setting("DB_PASSWORD")
    encrypt = _get_setting("DB_ENCRYPT")
    trust_server_certificate = _get_setting("DB_TRUST_SERVER_CERTIFICATE")
    timeout = _get_setting("DB_CONNECTION_TIMEOUT")

    parts = [f"Driver={driver}", f"Server={server}", f"Database={database}"]
    if trusted in {"yes", "true", "1"}:
        parts.append("Trusted_Connection=yes")
    else:
        if not username or not password:
            raise RuntimeError(
                "SQL authentication requires DB_USERNAME and DB_PASSWORD."
            )
        parts.extend([f"UID={username}", f"PWD={password}"])

    if encrypt:
        parts.append(f"Encrypt={encrypt}")
    if trust_server_certificate:
        parts.append(f"TrustServerCertificate={trust_server_certificate}")
    if timeout:
        parts.append(f"Connection Timeout={timeout}")

    return ";".join(parts) + ";"


def is_configured() -> bool:
    if _get_setting("DB_CONNECTION_STRING"):
        return True
    return bool(_get_setting("DB_SERVER") and _get_setting("DB_NAME"))


def get_configuration_status_message() -> str:
    if _get_setting("DB_CONNECTION_STRING"):
        return "Database connection is configured through DB_CONNECTION_STRING."

    server = _get_setting("DB_SERVER")
    database = _get_setting("DB_NAME")
    if server and database:
        return f"Database connection is configured for server '{server}' and database '{database}'."

    return (
        "Database connection is not configured. Create a project-root .env file or set "
        "DB_CONNECTION_STRING, or set DB_SERVER and DB_NAME."
    )


def _has_pyodbc_driver() -> bool:
    try:
        import pyodbc
    except Exception:
        return False

    return bool(pyodbc.drivers())


def _connect_with_pyodbc():
    import pyodbc

    return pyodbc.connect(_build_connection_string())


def _connect_with_pytds():
    import pytds

    server = _get_setting("DB_SERVER")
    database = _get_setting("DB_NAME")
    trusted = (_get_setting("DB_TRUSTED_CONNECTION", "yes") or "yes").lower()

    if trusted in {"yes", "true", "1"}:
        raise RuntimeError(
            "No usable ODBC driver was found. Trusted SQL Server connections require pyodbc with a Microsoft ODBC driver."
        )

    username = _get_setting("DB_USERNAME")
    password = _get_setting("DB_PASSWORD")
    if not username or not password or not server or not database:
        raise RuntimeError(
            "SQL authentication requires DB_SERVER, DB_NAME, DB_USERNAME, and DB_PASSWORD."
        )

    host, port = _parse_server_endpoint(server)
    timeout = _get_setting("DB_CONNECTION_TIMEOUT")

    return pytds.connect(
        server=host,
        port=port or 1433,
        database=database,
        user=username,
        password=password,
        timeout=int(timeout) if timeout else None,
        autocommit=True,
    )


def get_connection():
    if _has_pyodbc_driver():
        return _connect_with_pyodbc()

    return _connect_with_pytds()


def query_dataframe(sql: str, params: Sequence[object] | None = None) -> pd.DataFrame:
    with get_connection() as connection:
        cursor = connection.cursor()
        prepared_sql = _prepare_sql_for_driver(sql, params)
        cursor.execute(prepared_sql, list(params or ()))

        if cursor.description is None:
            return pd.DataFrame()

        columns = [column[0] for column in cursor.description]
        rows = cursor.fetchall()
        return pd.DataFrame.from_records(rows, columns=columns)


def execute_statement(sql: str, params: Iterable[object] | None = None) -> None:
    with get_connection() as connection:
        cursor = connection.cursor()
        param_list = list(params or ())
        prepared_sql = _prepare_sql_for_driver(sql, param_list)
        cursor.execute(prepared_sql, param_list)
        connection.commit()
