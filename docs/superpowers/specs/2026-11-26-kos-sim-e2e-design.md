# kOS offline E2E simulator — design

**Date:** 2026-11-26  
**Status:** Draft for review  
**Repo:** ChrisTerBeke/kOS  

## Goal

Run the real KerboScript mission scripts (starting with full `f9_test`: countdown → ascent → circularize → Hohmann) **outside KSP**, in CI, by interpreting `.ks` files on a Python KerboScript/kOS runtime backed by a pluggable physics host.

Success for a green E2E run: mission completes without abort, final orbit within tolerances, and flight invariants hold for the whole trajectory.

## Decisions (locked)

| Topic | Choice |
| --- | --- |
| Where tests run | Outside KSP (Python + GitHub Actions) |
| Relation to scripts | Interpret real `.ks` (source of truth unchanged) |
| First E2E mission | Full `f9_test` |
| Physics fidelity | Closer to KSP: 2-body Kerbin, atmosphere/drag, Isp curves, limited attitude — not pixel-perfect |
| Language of stack | Python 3.12+ |
| Pass criteria | Orbit tolerances **and** flight invariants |
| Architecture style | Layered VM + pluggable `KosHost` / `SimHost` |
| Language coverage | **Full** KerboScript/kOS language set (phased builtins; no silent gaps) |

## Architecture

```
programs/*.ks  (unchanged)
        ↓
kos-sim CLI + pytest harness
        ↓
┌─────────────────────┐     ┌─────────────────────┐
│ KerboScript runtime │────▶│ KosHost API         │
│ lexer→AST→bytecode  │     │ ship/body/time/eta  │
│ VM, locks, triggers │     │ volumes, stage, UI  │
└─────────────────────┘     └──────────┬──────────┘
                                       ↓ implements
                            ┌─────────────────────┐
                            │ SimHost (physics)   │
                            │ Kerbin, atmosphere, │
                            │ stages, attitude    │
                            └─────────────────────┘
```

### Hard boundaries

1. **Runtime** knows language semantics only — no orbital math inside the VM.
2. **KosHost** is the only world surface the VM uses — swap implementations without changing the runtime.
3. **SimHost** owns physics and craft state.
4. **Harness / pytest** owns pass/fail.

## Components

### Package layout

```
sim/
  kos_runtime/     # full-language frontend + VM
  kos_host/        # abstract host bindings / protocols
  sim_host/        # Kerbin-ish physics + craft implementation
  vehicles/        # craft fixtures (e.g. f9_like.yaml)
  harness/         # kos-sim CLI, boot helpers, assertions
  tests/           # language conformance + E2E
```

### 1. `kos_runtime` — full KerboScript/kOS language

**Goal:** Implement the published kOS/KerboScript language, not only the subset used by this repo today.

**Pipeline:** Lexer → Parser → AST → Bytecode compiler → VM.

**Must cover (language):**

- Syntax and grammar per kOS docs (statements, expressions, blocks)
- Types: scalars, strings, booleans, structures, lexicons, lists, queues, stacks, unique sets
- Flow control: `if`/`else`, `until`, `for`, `break`/`preserve` as applicable
- Functions, user delegates, `@` delegates, closures / lock expressions
- `parameter`, locals/globals, `run` / `runPath` / `runOncePath`
- Locks: `lock` / `unlock` (steering, throttle, and general locks)
- Triggers: `on` / `when` … `then` / `preserve`
- `wait` / `wait until`
- File and volume I/O
- Bound variables and suffix sounding across the standard binding set (`ship`, `body`, `core`, `addons`, …)
- Standard built-in function library

**Phasing (language completeness without blocking E2E):**

1. **Spec-complete frontend early** — lexer/parser/AST aimed at the full grammar.
2. **VM + builtins grow to full semantics** — missing opcode or builtin raises an explicit `NotImplementedError` (test-visible), never silent no-op.
3. **Conformance suite** — synthetic `.ks` language tests, separate from mission E2E.
4. **Host surface** — `KosHost` exposes the full binding surface; `SimHost` may stub rare suffixes until needed, with stubs documented and failing loudly if a script depends on unimplemented behavior that matters.

### 2. `kos_host` — abstract world API

Protocol/ABC surface used by the VM. Includes (non-exhaustive):

- Clock / universe time
- Bodies (at least Kerbin with µ, radius, rotation, atmosphere parameters)
- Ship: mass, position/velocity or orbital elements, altitude, apoapsis/periapsis, eccentricity, inclination, dynamic pressure, available thrust, engines, facing/steering vectors
- Flight control: steering and throttle locks; RCS/SAS flags; abort
- Parts/modules: launch clamps, procedural fairings, engines (ignition/flameout/Isp/thrust)
- Staging
- Volumes / archive file system
- Terminal input (scriptable)
- UI sinks: `print`, `clearScreen`, `hudtext` (log or no-op)

The VM must not import `sim_host`.

### 3. `sim_host` — physics world

Implements `kos_host` with fidelity “closer to KSP” for CI gating:

- Kerbin **two-body** gravity (Vis-viva / Cowell-style integration as implementation detail)
- **Exponential atmosphere** + aerodynamic drag on a point-mass (or simple reference area) model
- Engine **Isp vacuum / ASL** curves and thrust that varies with pressure
- **Staged** vehicle: wet/dry masses, fuel drain, `stage` advances stage model
- **Limited attitude dynamics**: steer toward locked steering direction with lag / rate limit (enough for gravity-turn AoA limiting to matter; not full aero torque)
- Module events: release clamps, deploy fairings
- Simulated time advances on `wait` (and host-driven yields); **no wall-clock sleep** in CI

### 4. `vehicles/` — craft fixtures

Declarative YAML/JSON, e.g. `f9_like.yaml`:

- Stage list: mass, fuel, engines (thrust, Isp ASL/vac), decouplers
- Fairings / clamps as named modules matching what scripts query (`ModuleProceduralFairing`, `LaunchClamp`)
- Launch site latitude/longitude for azimuth math

### 5. `harness` — CLI + pytest

- `kos-sim` CLI: load vehicle, mount archive root to repo scripts, run entry program, optional max sim-time
- pytest E2E: boot → `start(f9_test)` → inject Enter → run to completion → assert

## Execution model

### Boot (mirrors real usage)

1. Build `SimHost` from vehicle fixture + Kerbin constants.
2. Mount repo archive (`boot/`, `start.ks`, `programs/`) as volume `0:`.
3. Run `boot.ks` (copy `start.ks` to flight computer volume as needed).
4. Run `run start(f9_test).` (or harness-equivalent entry).
5. Inject terminal Enter when the script awaits it.
6. Continue until main sets finished / VM halt / timeout.

### Cooperative time stepping

```
VM runs until wait N   (main loop uses wait 0.2)
  → KosHost.advance(N)
      → evaluate locked steering / throttle
      → integrate physics for N seconds (fixed substeps)
      → refresh ship / orbit / eta suffixes
  → VM resumes
```

### Locks and triggers

- `lock steering to expr` / `lock throttle to expr`: host re-evaluates expressions each physics substep (or each `wait` boundary).
- `on abort`: register handler; host can raise abort for dedicated tests. Auto abort-detection in main remains optional for v1 E2E happy path.

### Telemetry I/O

`volume(0):create` / `open` / `writeln` write under a temp sim archive directory so CSV side effects are assertable in tests.

## Error handling

| Class | Behavior |
| --- | --- |
| Parse/compile error | Fail fast with `file:line` into `.ks` |
| Runtime error | Fail test; report VM stack + ship snapshot (alt, Ap/Pe, throttle, active maneuver if available) |
| Physics fault (NaN, alt < 0) | Raise `SimFault`; fail test |
| Timeout | Fail as hang (sim-time and/or step budget); dump same snapshot |
| Unimplemented language/host feature | Explicit error naming the missing feature |

## Assertions (`f9_test` E2E)

**Completion**

- Program finishes cleanly (main loop exit); abort not asserted as success.

**Orbit tolerances** (defaults; overridable in test config)

- Final apoapsis and periapsis within **±5 km of 140 km**
- Eccentricity below a configured threshold consistent with that band
- Inclination within **±2° of 25°**

**Invariants** (sampled every host advance)

- Altitude ≥ 0  
- Throttle ∈ [0, 1]  
- Fairing deploy count ≤ 1  
- Staging event count within an expected range for the vehicle fixture  
- No NaN/Inf in core state  
- Optional: telemetry CSV exists with header + ≥1 data row  

## CI

- GitHub Actions on pull requests: Python 3.12, install `sim` package, run `pytest sim/tests`
- No KSP dependency
- On failure, upload trajectory / snapshot artifacts

## Testing strategy (beyond one E2E)

1. **Language conformance** — `sim/tests/language/` synthetic `.ks` exercising grammar and builtins as they land.
2. **Host unit tests** — physics integration, staging, atmosphere, Isp without the VM.
3. **Mission E2E** — `f9_test` as the flagship integration test.
4. **Regression** — scenarios that previously hung (e.g. `OrbitChange` completion) as focused VM+host tests.

## Out of scope (v1)

- Pixel-perfect KSP aerodynamics / craft aero torque
- Multi-body / SOI transitions
- Real KSP GUI, telnet, or in-game CPU hardware limits
- Replacing in-game playtesting for craft tuning (sim gates logic; flight still validates feel)

## Implementation order (high level)

1. Scaffold `sim/` package, `KosHost` protocols, empty VM entrypoints.
2. Lexer/parser aimed at full grammar + bytecode for core control flow.
3. Minimal `SimHost` + vehicle fixture sufficient for countdown/clamps.
4. Grow runtime + host until `f9_test` runs end-to-end.
5. Assertions + GitHub Actions.
6. Language conformance suite expansion toward full builtin coverage.

## Open parameters (tunable, not blocking)

- Exact integrator (RK4 vs semi-analytic coast + burn)
- Attitude lag gains
- Default timeout (recommend large sim-time budget, e.g. hours of Kerbin time capped by wall CI minutes via fast-forward `wait`)
- Precise eccentricity threshold derived from ±5 km band
