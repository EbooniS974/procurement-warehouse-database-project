import importlib
from pathlib import Path
import sys
import types


def _load_db_module(monkeypatch):
    sys.modules.pop("ui.db", None)

    fake_pandas = types.ModuleType("pandas")
    fake_pandas.DataFrame = object
    fake_pandas.read_sql = lambda *args, **kwargs: None
    monkeypatch.setitem(sys.modules, "pandas", fake_pandas)

    return importlib.import_module("ui.db")


def _clear_db_env(monkeypatch) -> None:
    for key in [
        "DB_CONNECTION_STRING",
        "DB_DRIVER",
        "DB_SERVER",
        "DB_NAME",
        "DB_TRUSTED_CONNECTION",
        "DB_USERNAME",
        "DB_PASSWORD",
        "DB_ENCRYPT",
        "DB_TRUST_SERVER_CERTIFICATE",
        "DB_CONNECTION_TIMEOUT",
    ]:
        monkeypatch.delenv(key, raising=False)


def test_is_configured_reads_project_root_dotenv(monkeypatch, tmp_path: Path):
    db = _load_db_module(monkeypatch)
    env_file = tmp_path / ".env"
    env_file.write_text(
        "\n".join(
            [
                "DB_SERVER=localhost,14333",
                "DB_NAME=ProcurementWarehouseDB",
            ]
        ),
        encoding="utf-8",
    )

    _clear_db_env(monkeypatch)
    monkeypatch.setattr(db, "DEFAULT_ENV_FILE", env_file)
    monkeypatch.setattr(db, "_get_streamlit_secret", lambda name: None)

    assert db.is_configured() is True


def test_build_connection_string_supports_sql_auth_and_tls_options(monkeypatch, tmp_path: Path):
    db = _load_db_module(monkeypatch)
    _clear_db_env(monkeypatch)
    monkeypatch.setattr(db, "DEFAULT_ENV_FILE", tmp_path / ".env")
    monkeypatch.setattr(db, "_get_streamlit_secret", lambda name: None)

    monkeypatch.setenv("DB_SERVER", "localhost,14333")
    monkeypatch.setenv("DB_NAME", "ProcurementWarehouseDB")
    monkeypatch.setenv("DB_DRIVER", "{ODBC Driver 18 for SQL Server}")
    monkeypatch.setenv("DB_TRUSTED_CONNECTION", "no")
    monkeypatch.setenv("DB_USERNAME", "sa")
    monkeypatch.setenv("DB_PASSWORD", "Str0ngPassw0rd!2026")
    monkeypatch.setenv("DB_ENCRYPT", "yes")
    monkeypatch.setenv("DB_TRUST_SERVER_CERTIFICATE", "yes")
    monkeypatch.setenv("DB_CONNECTION_TIMEOUT", "5")

    connection_string = db._build_connection_string()

    assert "Driver={ODBC Driver 18 for SQL Server}" in connection_string
    assert "Server=localhost,14333" in connection_string
    assert "Database=ProcurementWarehouseDB" in connection_string
    assert "UID=sa" in connection_string
    assert "PWD=Str0ngPassw0rd!2026" in connection_string
    assert "Encrypt=yes" in connection_string
    assert "TrustServerCertificate=yes" in connection_string
    assert "Connection Timeout=5" in connection_string


def test_parse_server_endpoint_supports_comma_and_colon_formats(monkeypatch):
    db = _load_db_module(monkeypatch)

    assert db._parse_server_endpoint("localhost,14333") == ("localhost", 14333)
    assert db._parse_server_endpoint("localhost:14333") == ("localhost", 14333)
    assert db._parse_server_endpoint("localhost") == ("localhost", None)


def test_get_connection_falls_back_to_pytds_without_odbc_driver(monkeypatch, tmp_path: Path):
    db = _load_db_module(monkeypatch)
    _clear_db_env(monkeypatch)
    monkeypatch.setattr(db, "DEFAULT_ENV_FILE", tmp_path / ".env")
    monkeypatch.setattr(db, "_get_streamlit_secret", lambda name: None)
    monkeypatch.setattr(db, "_has_pyodbc_driver", lambda: False)

    fake_pytds = types.ModuleType("pytds")
    captured = {}

    def fake_connect(**kwargs):
        captured.update(kwargs)
        return object()

    fake_pytds.connect = fake_connect
    monkeypatch.setitem(sys.modules, "pytds", fake_pytds)

    monkeypatch.setenv("DB_SERVER", "localhost,14333")
    monkeypatch.setenv("DB_NAME", "ProcurementWarehouseDB")
    monkeypatch.setenv("DB_TRUSTED_CONNECTION", "no")
    monkeypatch.setenv("DB_USERNAME", "sa")
    monkeypatch.setenv("DB_PASSWORD", "secret")

    db.get_connection()

    assert captured["server"] == "localhost"
    assert captured["port"] == 14333
    assert captured["database"] == "ProcurementWarehouseDB"
    assert captured["user"] == "sa"
    assert captured["password"] == "secret"


def test_prepare_sql_for_driver_rewrites_qmark_params_for_pytds(monkeypatch):
    db = _load_db_module(monkeypatch)
    monkeypatch.setattr(db, "_has_pyodbc_driver", lambda: False)

    prepared_sql = db._prepare_sql_for_driver(
        "EXEC dbo.usp_Test @ParamA = ?, @ParamB = ?;",
        [1, 2],
    )

    assert prepared_sql == "EXEC dbo.usp_Test @ParamA = %s, @ParamB = %s;"
