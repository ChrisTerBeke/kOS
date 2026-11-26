from __future__ import annotations

import math
from typing import Any

from kos_runtime.env import Environment
from kos_runtime.values import (
    Direction,
    KList,
    KQueue,
    KVector,
    Lexicon,
    Structure,
    as_vector,
)


def install_builtins(env: Environment, host: Any) -> None:
    def _deg_sin(x: float) -> float:
        return math.sin(math.radians(float(x)))

    def _deg_cos(x: float) -> float:
        return math.cos(math.radians(float(x)))

    def _deg_tan(x: float) -> float:
        return math.tan(math.radians(float(x)))

    def _arcsin(x: float) -> float:
        return math.degrees(math.asin(max(-1.0, min(1.0, float(x)))))

    def _arccos(x: float) -> float:
        return math.degrees(math.acos(max(-1.0, min(1.0, float(x)))))

    def _arctan(x: float) -> float:
        return math.degrees(math.atan(float(x)))

    def _arctan2(y: float, x: float) -> float:
        return math.degrees(math.atan2(float(y), float(x)))

    def _heading(dir_deg: float, pitch_deg: float, roll_deg: float = 0.0) -> Direction:
        if hasattr(host, "heading"):
            d = host.heading(float(dir_deg), float(pitch_deg))
            vec = as_vector(getattr(d, "vector", d))
            return Direction(
                vector=vec,
                pitch=float(getattr(d, "pitch", pitch_deg)),
                yaw=float(getattr(d, "yaw", dir_deg)),
                roll=float(roll_deg) + float(getattr(d, "roll", 0.0)),
            )
        # Local ENU-ish fallback matching sim_host.math3d.heading_direction
        heading = math.radians(float(dir_deg))
        pitch = math.radians(float(pitch_deg))
        horizontal = math.cos(pitch)
        vec = KVector(
            horizontal * math.sin(heading),
            horizontal * math.cos(heading),
            math.sin(pitch),
        ).normalized()
        return Direction(vector=vec, pitch=float(pitch_deg), yaw=float(dir_deg), roll=float(roll_deg))

    def _r(pitch: float, yaw: float, roll: float) -> Direction:
        return Direction(vector=KVector(0.0, 0.0, 1.0), pitch=float(pitch), yaw=float(yaw), roll=float(roll))

    def _vang(a: Any, b: Any) -> float:
        return as_vector(a).angle_degrees(as_vector(b))

    def _vxcl(exclude: Any, vector: Any) -> KVector:
        n = as_vector(exclude).normalized()
        v = as_vector(vector)
        return v - n * v.dot(n)

    def _vcrs(a: Any, b: Any) -> KVector:
        return as_vector(a).cross(as_vector(b))

    def _vdot(a: Any, b: Any) -> float:
        return as_vector(a).dot(as_vector(b))

    def _lexicon(*args: Any) -> Lexicon:
        if len(args) % 2 != 0:
            raise TypeError("lexicon() expects key/value pairs")
        pairs = list(zip(args[0::2], args[1::2]))
        return Lexicon(pairs)

    def _list(*args: Any) -> KList:
        return KList(list(args))

    def _queue(*args: Any) -> KQueue:
        return KQueue(list(args))

    def _hudtext(
        text: Any,
        delay: Any = 5,
        style: Any = 2,
        size: Any = 12,
        colour: Any = None,
        echo: Any = False,
    ) -> None:
        # UI sink: log via print binding if present
        sink = getattr(host, "hudtext", None)
        if callable(sink):
            sink(str(text), delay, style, size, colour, echo)
            return
        # no-op / stdout for tests
        print(f"[hudtext] {text}")

    def _exists(path: Any) -> bool:
        return bool(host.path_exists(str(path)))

    def _copypath(src: Any, dst: Any) -> None:
        host.copy_path(str(src), str(dst))

    def _deletepath(path: Any) -> None:
        host.delete_path(str(path))

    def _volume(vol_id: Any) -> Any:
        return host.volume(int(vol_id))

    def _print_at(value: Any, x: Any = None, y: Any = None) -> None:
        sink = getattr(host, "print", None)
        if callable(sink):
            sink(value, x, y)
            return
        print(value)

    def _clearscreen() -> None:
        sink = getattr(host, "clear_screen", None)
        if callable(sink):
            sink()

    constant = Structure(
        _fields={
            "g0": 9.80665,
            "e": math.e,
            "pi": math.pi,
            "degToRad": math.pi / 180.0,
            "radToDeg": 180.0 / math.pi,
        }
    )

    colors = {
        "white": Structure(_fields={"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}),
        "black": Structure(_fields={"r": 0.0, "g": 0.0, "b": 0.0, "a": 1.0}),
        "red": Structure(_fields={"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0}),
        "green": Structure(_fields={"r": 0.0, "g": 1.0, "b": 0.0, "a": 1.0}),
        "blue": Structure(_fields={"r": 0.0, "g": 0.0, "b": 1.0, "a": 1.0}),
        "yellow": Structure(_fields={"r": 1.0, "g": 1.0, "b": 0.0, "a": 1.0}),
    }

    builtins: dict[str, Any] = {
        "sin": _deg_sin,
        "cos": _deg_cos,
        "tan": _deg_tan,
        "arcsin": _arcsin,
        "arccos": _arccos,
        "arctan": _arctan,
        "arctan2": _arctan2,
        "abs": abs,
        "sqrt": math.sqrt,
        "ln": math.log,
        "log10": math.log10,
        "min": min,
        "max": max,
        "round": round,
        "floor": math.floor,
        "ceiling": math.ceil,
        "mod": lambda a, b: float(a) % float(b),
        "heading": _heading,
        "r": _r,
        "vang": _vang,
        "vectorangle": _vang,
        "vxcl": _vxcl,
        "vcrs": _vcrs,
        "vdot": _vdot,
        "lexicon": _lexicon,
        "list": _list,
        "queue": _queue,
        "hudtext": _hudtext,
        "exists": _exists,
        "copypath": _copypath,
        "deletepath": _deletepath,
        "volume": _volume,
        "constant": constant,
        "unchar": lambda n: chr(int(n)),
        "char": lambda s: ord(str(s)[0]) if s else 0,
    }
    builtins.update(colors)

    for name, value in builtins.items():
        env.define(name, value)

    # Host-facing print/clear helpers used by VM statements
    env.define("__print__", _print_at)
    env.define("__clearscreen__", _clearscreen)

