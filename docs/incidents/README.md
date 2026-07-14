# Incident postmortems

Operational incidents worth documenting for portfolio reviewers and future maintainers. Each file follows a lightweight blameless postmortem format: impact, timeline, root cause, fix, and prevention.

| Date | Incident | Severity |
|------|----------|----------|
| [2026-07-13](2026-07-13-flink-dlq-classcastexception.md) | Flink DLQ validation crash-loop (`Integer` → `Double`) | High — streaming job unavailable |

When adding a new postmortem, use `YYYY-MM-DD-short-slug.md` and link it here.
