#!/usr/bin/env python3
"""Create or update the Crypto Pulse Metabase collection and dashboard from exports/."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
EXPORTS_DIR = ROOT / "exports"
DEFAULT_MANIFEST = EXPORTS_DIR / "crypto-pulse-prices-dashboard.json"


class MetabaseClient:
    def __init__(self, base_url: str, session_id: str) -> None:
        self.base_url = base_url.rstrip("/")
        self.session_id = session_id

    def _request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
    ) -> Any:
        url = f"{self.base_url}{path}"
        data = None
        headers = {
            "Content-Type": "application/json",
            "X-Metabase-Session": self.session_id,
        }
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")

        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8")
                return json.loads(body) if body else None
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {path} failed ({exc.code}): {detail}") from exc

    def get(self, path: str) -> Any:
        return self._request("GET", path)

    def post(self, path: str, payload: dict[str, Any]) -> Any:
        return self._request("POST", path, payload)

    def put(self, path: str, payload: dict[str, Any]) -> Any:
        return self._request("PUT", path, payload)


def login(base_url: str, email: str, password: str) -> MetabaseClient:
    payload = json.dumps({"username": email, "password": password}).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/session",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = json.loads(response.read().decode("utf-8"))
    session_id = body.get("id")
    if not session_id:
        raise RuntimeError("Metabase login did not return a session id")
    return MetabaseClient(base_url, session_id)


def find_database_id(client: MetabaseClient) -> int:
    databases = client.get("/api/database")
    items = databases.get("data", databases) if isinstance(databases, dict) else databases
    if not isinstance(items, list):
        raise RuntimeError("Unexpected /api/database response")

    for db in items:
        name = str(db.get("name", "")).lower()
        details = db.get("details") or {}
        dbname = str(details.get("dbname", "")).lower()
        if "cryptopulse" in name or dbname == "cryptopulse":
            return int(db["id"])

    raise RuntimeError(
        "PostgreSQL database 'cryptopulse' not found in Metabase. "
        "Add it first (host postgres, schema gold only). See metabase/README.md"
    )


def find_by_name(items: list[dict[str, Any]], name: str) -> dict[str, Any] | None:
    for item in items:
        if item.get("name") == name:
            return item
    return None


def ensure_collection(client: MetabaseClient, manifest: dict[str, Any]) -> int:
    spec = manifest["collection"]
    collections = client.get("/api/collection")
    existing = find_by_name(collections, spec["name"])
    if existing:
        print(f"Collection exists: {spec['name']} (id={existing['id']})")
        return int(existing["id"])

    created = client.post(
        "/api/collection",
        {
            "name": spec["name"],
            **(
                {"description": spec["description"]}
                if spec.get("description", "").strip()
                else {}
            ),
            "color": "#509EE3",
        },
    )
    print(f"Created collection: {spec['name']} (id={created['id']})")
    return int(created["id"])


def load_sql(relative_path: str) -> str:
    path = ROOT / relative_path
    return path.read_text(encoding="utf-8").strip()


def ensure_card(
    client: MetabaseClient,
    database_id: int,
    collection_id: int,
    card_spec: dict[str, Any],
) -> int:
    cards = client.get("/api/card")
    existing = find_by_name(cards, card_spec["name"])
    sql = load_sql(card_spec["sql_file"])
    payload: dict[str, Any] = {
        "name": card_spec["name"],
        "collection_id": collection_id,
        "dataset_query": {
            "database": database_id,
            "type": "native",
            "native": {"query": sql},
        },
        "display": card_spec.get("display", "table"),
        "visualization_settings": card_spec.get("visualization_settings", {}),
    }
    description = card_spec.get("description", "").strip()
    if description:
        payload["description"] = description

    if existing:
        updated = client.put(f"/api/card/{existing['id']}", payload)
        print(f"Updated card: {card_spec['name']} (id={updated['id']})")
        return int(updated["id"])

    created = client.post("/api/card", payload)
    print(f"Created card: {card_spec['name']} (id={created['id']})")
    return int(created["id"])


def ensure_dashboard(
    client: MetabaseClient,
    collection_id: int,
    manifest: dict[str, Any],
    card_ids: list[tuple[int, dict[str, Any]]],
) -> int:
    spec = manifest["dashboard"]
    dashboards = client.get("/api/dashboard")
    existing = find_by_name(dashboards, spec["name"])

    dashcards = []
    for index, (card_id, card_spec) in enumerate(card_ids):
        layout = card_spec["layout"]
        dashcards.append(
            {
                "id": -(index + 1),
                "card_id": card_id,
                "row": layout["row"],
                "col": layout["col"],
                "size_x": layout["size_x"],
                "size_y": layout["size_y"],
                "series": [],
                "parameter_mappings": [],
                "visualization_settings": card_spec.get("visualization_settings", {}),
            }
        )

    payload: dict[str, Any] = {
        "name": spec["name"],
        "collection_id": collection_id,
        "dashcards": dashcards,
    }
    dash_description = spec.get("description", "").strip()
    if dash_description:
        payload["description"] = dash_description

    if existing:
        dashboard_id = int(existing["id"])
        client.put(f"/api/dashboard/{dashboard_id}", payload)
        print(f"Updated dashboard: {spec['name']} (id={dashboard_id})")
        return dashboard_id

    created = client.post("/api/dashboard", payload)
    dashboard_id = int(created["id"])
    print(f"Created dashboard: {spec['name']} (id={dashboard_id})")
    return dashboard_id


def list_manifests() -> list[Path]:
    override = os.environ.get("METABASE_MANIFEST")
    if override:
        path = Path(override)
        if not path.is_absolute():
            path = ROOT / path
        return [path]

    manifests = sorted(EXPORTS_DIR.glob("*-dashboard.json"))
    if not manifests:
        raise FileNotFoundError(f"No manifests in {EXPORTS_DIR}")
    return manifests


def apply_manifest(
    client: MetabaseClient,
    database_id: int,
    collection_id: int,
    manifest_path: Path,
) -> int:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    print(f"\n--- Manifest: {manifest_path.name} ---")

    card_ids: list[tuple[int, dict[str, Any]]] = []
    for card_spec in manifest["cards"]:
        card_id = ensure_card(client, database_id, collection_id, card_spec)
        card_ids.append((card_id, card_spec))

    return ensure_dashboard(client, collection_id, manifest, card_ids)


def main() -> int:
    base_url = os.environ.get("METABASE_URL", "http://localhost:3000")
    email = os.environ.get("METABASE_EMAIL")
    password = os.environ.get("METABASE_PASSWORD")

    if not email or not password:
        print(
            "Set METABASE_EMAIL and METABASE_PASSWORD (your Metabase admin account).\n"
            "Example:\n"
            "  METABASE_EMAIL=you@example.com METABASE_PASSWORD=secret "
            "python metabase/setup_dashboard.py",
            file=sys.stderr,
        )
        return 1

    manifest_paths = list_manifests()
    print(f"Found {len(manifest_paths)} dashboard manifest(s)")

    client = login(base_url, email, password)
    database_id = find_database_id(client)
    print(f"Using database id={database_id}")

    first = json.loads(manifest_paths[0].read_text(encoding="utf-8"))
    collection_id = ensure_collection(client, first)

    dashboard_urls: list[str] = []
    for manifest_path in manifest_paths:
        dashboard_id = apply_manifest(client, database_id, collection_id, manifest_path)
        dashboard_urls.append(f"{base_url}/dashboard/{dashboard_id}")

    print("\nDone. Dashboards:")
    for url in dashboard_urls:
        print(f"  {url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
