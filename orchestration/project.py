"""Points Dagster at the dbt project so it can build the asset graph from the manifest."""

from __future__ import annotations

from pathlib import Path

from dagster_dbt import DbtProject

DBT_PROJECT_DIR = Path(__file__).joinpath("..", "..", "dbt").resolve()

dbt_project = DbtProject(project_dir=DBT_PROJECT_DIR)

# No-op outside `dagster dev` — production containers prepare the manifest
# explicitly via `dbt parse` in transform/entrypoint.sh and run-transform.sh
# before this module (and its manifest_path read) is imported.
dbt_project.prepare_if_dev()
