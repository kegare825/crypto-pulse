# CI & branch protection

## Workflows

| Workflow | Trigger | Jobs |
|----------|---------|------|
| **CI** (`.github/workflows/ci.yml`) | push/PR to `main` | pytest, Kafka integration (Testcontainers), dbt parse/compile, dbt-integration, quality (GX), dbt-docs, infra |
| **Smoke E2E** (`.github/workflows/smoke.yml`) | daily 06:00 UTC + manual | Postgres seed → dbt → GX → gold checks |
| **dbt docs Pages** (`.github/workflows/dbt-docs-pages.yml`) | push to `main` + manual | seeded `dbt run` → `dbt docs generate` → deploy to GitHub Pages |

## GitHub Pages (one-time setup)

The Pages workflow deploys via `actions/deploy-pages`. Enable it once:

1. Repo → **Settings** → **Pages**
2. **Source**: select **GitHub Actions**
3. Next push to `main` publishes dbt docs at `https://kegare825.github.io/crypto-pulse/`

## Required checks (GitHub branch protection)

After the first green CI run on `main`, enable branch protection:

1. Repo → **Settings** → **Branches** → **Add rule** for `main`
2. Enable **Require status checks to pass before merging**
3. Select these checks:
   - `Unit tests & contract`
   - `dbt parse & compile`
   - `dbt run & test (Postgres)`
   - `Great Expectations (Postgres)`
   - `Docker & Prometheus rules`
   - `Kafka integration (Testcontainers)`
4. Optional: require `dbt docs generate` if you want docs on every PR

Smoke E2E is **not** required on PRs (nightly only) to keep feedback fast.

## Local parity

```bash
pytest tests/ -v -m "not integration"     # unit + contract tests (no Docker needed)
bash ci/init_postgres.sh
cd dbt && dbt deps --profiles-dir . && dbt run --profiles-dir . && dbt test --profiles-dir .
python quality/validate.py
bash scripts/smoke_test.sh
```

Kafka integration tests (spin up a real broker via Testcontainers, Docker required):

```bash
pip install -r tests/requirements-integration.txt
pytest tests/ -v -m integration
```
