"""dbt models as Software-Defined Assets.

Replaces the previous ops-based `dbt run` / `dbt test` steps with
`@dbt_assets`, which parses `dbt/target/manifest.json` and gives every
silver/gold model its own node and real lineage in the Dagster UI instead of
one opaque "dbt run" step.

Deliberately does NOT use `from __future__ import annotations`: Dagster's
context-parameter validator checks the raw `context: AssetExecutionContext`
annotation by class identity, and PEP 563 postponed evaluation would turn
that into the plain string "AssetExecutionContext", which fails the check
with `DagsterInvalidDefinitionError` at import time.
"""

from dagster import AssetExecutionContext
from dagster_dbt import DbtCliResource, dbt_assets

from orchestration.project import dbt_project


@dbt_assets(manifest=dbt_project.manifest_path)
def crypto_pulse_dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    """`dbt build` (run + test per model) via the Dagster dbt integration."""
    yield from dbt.cli(["build"], context=context).stream()
