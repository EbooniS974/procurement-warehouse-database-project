from importlib import import_module
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def _read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def test_required_project_files_exist():
    expected_files = [
        "README.md",
        ".env.example",
        "requirements.txt",
        "docs/project-report.md",
        "scripts/create_share_zip.sh",
        "scripts/start_local_demo_db.sh",
        "sql/01_schema_and_security.sql",
        "sql/02_business_logic.sql",
        "sql/03_seed_and_demo_queries.sql",
        "ui/__init__.py",
        "ui/app.py",
        "ui/db.py",
        "ui/modules.py",
    ]

    missing = [path for path in expected_files if not (ROOT / path).exists()]
    assert not missing, f"Missing project files: {missing}"


def test_sql_scripts_cover_required_database_objects():
    sql_bundle = "\n".join(
        _read(path)
        for path in [
            "sql/01_schema_and_security.sql",
            "sql/02_business_logic.sql",
            "sql/03_seed_and_demo_queries.sql",
        ]
    )

    assert len(re.findall(r"CREATE\s+(?:OR\s+ALTER\s+)?VIEW\b", sql_bundle, re.IGNORECASE)) >= 5
    assert len(re.findall(r"CREATE\s+(?:OR\s+ALTER\s+)?FUNCTION\b", sql_bundle, re.IGNORECASE)) >= 5
    assert len(re.findall(r"CREATE\s+(?:OR\s+ALTER\s+)?TRIGGER\b", sql_bundle, re.IGNORECASE)) >= 5
    assert len(re.findall(r"CREATE\s+ROLE\b", sql_bundle, re.IGNORECASE)) >= 3
    assert "SERIALIZABLE" in sql_bundle.upper()
    assert "REPEATABLE READ" in sql_bundle.upper()
    assert "READ COMMITTED" in sql_bundle.upper()


def test_query_examples_include_outer_join_types():
    sql_text = _read("sql/03_seed_and_demo_queries.sql").upper()

    assert "LEFT OUTER JOIN" in sql_text
    assert "RIGHT OUTER JOIN" in sql_text
    assert "FULL OUTER JOIN" in sql_text


def test_report_covers_required_sections():
    report = _read("docs/project-report.md")
    required_headings = [
        "# Procurement and Warehouse Database Project Report",
        "## 1. User Requirements",
        "## 2. Entity-Relationship Diagram",
        "## 3. Functional Dependencies",
        "## 4. Normalization",
        "## 5. Database Schema",
        "## 6. Database Implementation",
        "## 7. User Interface",
        "## 8. Query Development",
        "## 9. Functions",
        "## 10. Triggers",
        "## 11. Views",
        "## 12. Transactions",
        "## 13. Concurrency Control",
        "## 14. Inheritance",
        "## 15. Privileges and Roles",
        "## 16. Additional Business Rules",
        "## 17. SQL Statement Inventory",
    ]

    for heading in required_headings:
        assert heading in report


def test_report_avoids_file_inventory_noise_in_body():
    report = _read("docs/project-report.md")

    forbidden_phrases = [
        "Overview diagram files:",
        "Security subsystem diagram files:",
        "Procurement subsystem diagram files:",
        "Warehouse subsystem diagram files:",
        "Full diagram files:",
    ]

    for phrase in forbidden_phrases:
        assert phrase not in report


def test_report_avoids_assignment_meta_language():
    report = _read("docs/project-report.md").lower()

    forbidden_phrases = [
        "requirements of the assignment",
        "minimum requirement of",
        "in accordance with the project requirements",
        "explicitly requested in the requirements",
        "requirements of the project",
    ]

    for phrase in forbidden_phrases:
        assert phrase not in report


def test_ui_exposes_at_least_five_modules():
    module_registry = import_module("ui.modules")
    modules = module_registry.MODULES

    assert len(modules) >= 5
    assert all("key" in module and "title" in module for module in modules)


def test_ui_exposes_extended_module_suite():
    module_registry = import_module("ui.modules")
    module_keys = {module["key"] for module in module_registry.MODULES}

    assert {
        "approval_workflow",
        "budget_tracking",
        "quality_control",
        "vendor_claims",
    } <= module_keys


def test_streamlit_entrypoint_bootstraps_project_root_before_ui_imports():
    app_source = _read("ui/app.py")

    assert "from pathlib import Path" in app_source
    assert "import sys" in app_source
    assert "ROOT = Path(__file__).resolve().parents[1]" in app_source
    assert "sys.path.insert(0, str(ROOT))" in app_source
    assert app_source.index("ROOT = Path(__file__).resolve().parents[1]") < app_source.index("from ui.db import")
