# kos-sim

Offline KerboScript/kOS runtime and Kerbin physics host for CI E2E tests.

## Setup

```bash
cd sim
pip install -e ".[dev]"
```

## Tests

```bash
pytest -q
```

## Run a mission

From the repository root:

```bash
kos-sim f9_test --repo .
```

## Layout

- `kos_runtime/` — KerboScript parser + VM
- `kos_host/` — host protocols
- `sim_host/` — Kerbin physics + craft
- `vehicles/` — YAML craft fixtures
- `harness/` — CLI + E2E runner
- `tests/` — unit + language + E2E
