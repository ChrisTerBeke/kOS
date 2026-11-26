from __future__ import annotations

from pathlib import Path

from kos_runtime.parser import parse_script
from kos_runtime.vm import VirtualMachine
from sim_host.host import SimHost


class MockHost:
    """Minimal host for language unit tests."""

    def __init__(self) -> None:
        self.time_seconds = 0.0
        self.mission_time = 0.0
        self._throttle = 0.0
        self._steering = None
        self._throttle_evaluator = None
        self._steering_evaluator = None
        self._scripts: dict[str, str] = {}
        self.printed: list[str] = []

        class _Ship:
            altitude = 0.0
            apoapsis = 0.0
            periapsis = 0.0
            mass = 1.0
            available_thrust = 0.0
            maxthrust = 0.0
            vertical_speed = 0.0
            groundspeed = 0.0
            q = 0.0
            body = type("B", (), {"mu": 1.0, "radius": 600000.0, "atm_height": 70000.0, "rotation_period": 21600.0})()
            orbit = type("O", (), {"apoapsis": 0.0, "periapsis": 0.0, "eccentricity": 0.0, "inclination": 0.0})()
            geoposition = type("G", (), {"lat": 0.0, "lng": -74.0})()
            facing = type("D", (), {"vector": type("V", (), {"x": 0, "y": 0, "z": 1})(), "pitch": 90, "yaw": 0, "roll": 0})()
            prograde = facing
            srfprograde = facing
            up = facing
            north = facing
            deltav_vacuum = 0.0

            def engines(self):
                return []

            def modules_named(self, name: str):
                return []

        self.ship = _Ship()
        self.body = self.ship.body

    def advance(self, dt: float) -> None:
        if self._throttle_evaluator:
            self._throttle = float(self._throttle_evaluator())
        self.time_seconds += dt
        self.mission_time += dt

    def eta_apoapsis(self) -> float:
        return 0.0

    def eta_periapsis(self) -> float:
        return 0.0

    def set_throttle_lock(self, expression) -> None:
        pass

    def set_steering_lock(self, expression) -> None:
        pass

    def set_throttle_evaluator(self, fn) -> None:
        self._throttle_evaluator = fn

    def set_steering_evaluator(self, fn) -> None:
        self._steering_evaluator = fn

    def evaluate_throttle(self) -> float:
        if self._throttle_evaluator:
            return float(self._throttle_evaluator())
        return self._throttle

    def evaluate_steering(self):
        if self._steering_evaluator:
            return self._steering_evaluator()
        return self.ship.facing

    def stage(self) -> None:
        pass

    def set_rcs(self, enabled: bool) -> None:
        pass

    def set_sas(self, enabled: bool) -> None:
        pass

    def set_abort(self, enabled: bool) -> None:
        pass

    def neutralize_controls(self) -> None:
        pass

    def volume(self, id: int):
        return type("Vol", (), {"create": lambda p: None, "open": lambda p: type("F", (), {"writeln": lambda t: None})(), "exists": lambda p: False})()

    def switch_to(self, volume) -> None:
        pass

    def resolve_path(self, path: str) -> str:
        return path

    def read_script(self, path: str) -> str:
        return self._scripts[path]

    def path_exists(self, path: str) -> bool:
        return path in self._scripts

    def copy_path(self, src: str, dst: str) -> None:
        pass

    def delete_path(self, path: str) -> None:
        pass

    def push_terminal_char(self, ch: str) -> None:
        pass

    def terminal_has_char(self) -> bool:
        return False

    def terminal_get_char(self) -> str:
        return ""

    def snapshot(self) -> dict:
        return {"time": self.time_seconds}


def test_parse_set_and_function():
    script = parse_script("set x to 1.\nfunction f { return 2. }\n", "t.ks")
    assert len(script.statements) == 2


def test_arithmetic_and_wait():
    host = MockHost()
    vm = VirtualMachine(host)
    vm.run_source("set x to 1 + 2. wait 0.1.")
    assert vm.global_env.get("x") == 3
    assert abs(host.time_seconds - 0.1) < 1e-9


def test_function_return():
    host = MockHost()
    vm = VirtualMachine(host)
    vm.run_source(
        """
        function add {
            parameter a.
            parameter b.
            return a + b.
        }
        set y to add(3, 4).
        """
    )
    assert vm.global_env.get("y") == 7


def test_lexicon_delegate():
    host = MockHost()
    vm = VirtualMachine(host)
    vm.run_source(
        """
        function make {
            local n is 1.
            function getN {
                return n.
            }
            return lexicon("getN", getN@).
        }
        local obj is make().
        set z to obj:getN().
        """
    )
    assert vm.global_env.get("z") == 1


def test_comparisons():
    host = MockHost()
    vm = VirtualMachine(host)
    vm.run_source(
        """
        set a to 1 = 1.
        set b to 1 <> 2.
        set c to true and false.
        set d to not false.
        """
    )
    assert vm.global_env.get("a") is True
    assert vm.global_env.get("b") is True
    assert vm.global_env.get("c") is False
    assert vm.global_env.get("d") is True


def test_lock_throttle_evaluator():
    host = MockHost()
    vm = VirtualMachine(host)
    vm.run_source(
        """
        local t is 0.5.
        lock throttle to t.
        wait 0.05.
        """
    )
    assert abs(host.evaluate_throttle() - 0.5) < 1e-9


def test_run_once_path_cache(tmp_path: Path):
    host = MockHost()
    host._scripts["lib.ks"] = "global HIT is HIT + 1."
    host._scripts["main.ks"] = """
        global HIT is 0.
        runOncePath("lib.ks").
        runOncePath("lib.ks").
    """
    # bootstrap HIT for lib
    vm = VirtualMachine(host)
    vm.global_env.define("HIT", 0)
    # lib increments — need HIT defined before first runOnce
    host._scripts["lib.ks"] = "set HIT to HIT + 1."
    vm.run_path("main.ks")
    assert vm.global_env.get("HIT") == 1


def test_tiny_script_against_simhost():
    root = Path(__file__).resolve().parents[3]
    vehicle = Path(__file__).resolve().parents[2] / "vehicles" / "f9_like.yaml"
    host = SimHost.from_vehicle_yaml(vehicle, archive_root=root)
    vm = VirtualMachine(host)
    t0 = host.time_seconds
    vm.run_source("set x to 1 + 2. wait 0.1.")
    assert vm.global_env.get("x") == 3
    assert host.time_seconds >= t0 + 0.1
