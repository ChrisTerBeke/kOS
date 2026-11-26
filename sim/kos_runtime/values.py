from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any, Callable, Iterator as TypingIterator


def kos_truthy(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return len(value) > 0
    if isinstance(value, (KList, KQueue)):
        return len(value) > 0
    if isinstance(value, Lexicon):
        return len(value) > 0
    return True


def kos_equal(left: Any, right: Any) -> bool:
    if isinstance(left, bool) or isinstance(right, bool):
        return kos_truthy(left) is kos_truthy(right) and _as_bool_or_same(left) == _as_bool_or_same(right)
    if isinstance(left, (int, float)) and isinstance(right, (int, float)):
        return float(left) == float(right)
    if isinstance(left, str) and isinstance(right, str):
        return left == right
    return left == right


def _as_bool_or_same(value: Any) -> Any:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return value


@dataclass
class KVector:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0

    def __add__(self, other: KVector) -> KVector:
        return KVector(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other: KVector) -> KVector:
        return KVector(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, scalar: float) -> KVector:
        return KVector(self.x * scalar, self.y * scalar, self.z * scalar)

    __rmul__ = __mul__

    def __truediv__(self, scalar: float) -> KVector:
        return KVector(self.x / scalar, self.y / scalar, self.z / scalar)

    def dot(self, other: KVector) -> float:
        return self.x * other.x + self.y * other.y + self.z * other.z

    def cross(self, other: KVector) -> KVector:
        return KVector(
            self.y * other.z - self.z * other.y,
            self.z * other.x - self.x * other.z,
            self.x * other.y - self.y * other.x,
        )

    def mag(self) -> float:
        return math.sqrt(self.dot(self))

    def normalized(self) -> KVector:
        m = self.mag()
        if m <= 0:
            return KVector(0.0, 0.0, 0.0)
        return self / m

    def direction(self) -> Direction:
        # Pitch/yaw approximation from vector (z-up, y-north, x-east)
        n = self.normalized()
        mag_xy = math.sqrt(self.x * self.x + self.y * self.y)
        pitch = math.degrees(math.atan2(self.z, mag_xy)) if (mag_xy or self.z) else 0.0
        yaw = math.degrees(math.atan2(self.x, self.y)) if (self.x or self.y) else 0.0
        return Direction(vector=n, pitch=pitch, yaw=yaw, roll=0.0)

    def angle_degrees(self, other: KVector) -> float:
        a = self.normalized()
        b = other.normalized()
        c = max(-1.0, min(1.0, a.dot(b)))
        return math.degrees(math.acos(c))


def as_vector(value: Any) -> KVector:
    if isinstance(value, KVector):
        return value
    if hasattr(value, "x") and hasattr(value, "y") and hasattr(value, "z"):
        return KVector(float(value.x), float(value.y), float(value.z))
    if hasattr(value, "vector"):
        return as_vector(value.vector)
    raise TypeError(f"not a vector: {type(value)!r}")


@dataclass
class Direction:
    vector: KVector = field(default_factory=KVector)
    pitch: float = 0.0
    yaw: float = 0.0
    roll: float = 0.0

    def __post_init__(self) -> None:
        if not isinstance(self.vector, KVector):
            self.vector = as_vector(self.vector)

    @property
    def starvector(self) -> KVector:
        return KVector(1.0, 0.0, 0.0)

    def __add__(self, other: Any) -> Direction:
        if isinstance(other, Direction):
            return Direction(
                vector=self.vector,
                pitch=self.pitch + other.pitch,
                yaw=self.yaw + other.yaw,
                roll=self.roll + other.roll,
            )
        raise TypeError("can only add Direction to Direction")


@dataclass
class Structure:
    """Generic suffix-soundable structure."""

    _fields: dict[str, Any] = field(default_factory=dict)
    _methods: dict[str, Callable[..., Any]] = field(default_factory=dict)

    def get_suffix(self, name: str) -> Any:
        key = name.lower()
        for k, v in self._fields.items():
            if k.lower() == key:
                return v() if callable(v) and not isinstance(v, Delegate) else v
        for k, v in self._methods.items():
            if k.lower() == key:
                return v
        raise AttributeError(name)

    def set_suffix(self, name: str, value: Any) -> None:
        key = name.lower()
        for k in list(self._fields):
            if k.lower() == key:
                self._fields[k] = value
                return
        self._fields[name] = value


class Delegate:
    def __init__(self, fn: Callable[..., Any], env: Any | None = None, name: str = "") -> None:
        self.fn = fn
        self.env = env
        self.name = name

    def __call__(self, *args: Any) -> Any:
        return self.fn(*args)


class UserFunction:
    """Closure over a function body and defining environment."""

    def __init__(self, name: str, body: Any, env: Any) -> None:
        self.name = name
        self.body = body
        self.env = env

    def as_delegate(self) -> Delegate:
        return Delegate(self, self.env, self.name)


class Lexicon:
    def __init__(self, pairs: list[tuple[Any, Any]] | None = None) -> None:
        self._data: dict[Any, Any] = {}
        if pairs:
            for k, v in pairs:
                self._data[k] = v

    def __len__(self) -> int:
        return len(self._data)

    def __getitem__(self, key: Any) -> Any:
        if key in self._data:
            return self._data[key]
        # case-insensitive string keys
        if isinstance(key, str):
            for k, v in self._data.items():
                if isinstance(k, str) and k.lower() == key.lower():
                    return v
        raise KeyError(key)

    def __setitem__(self, key: Any, value: Any) -> None:
        self._data[key] = value

    def get(self, key: Any, default: Any = None) -> Any:
        try:
            return self[key]
        except KeyError:
            return default

    def has_key(self, key: Any) -> bool:
        try:
            self[key]
            return True
        except KeyError:
            return False

    @property
    def length(self) -> int:
        return len(self._data)

    @property
    def keys(self) -> KList:
        return KList(list(self._data.keys()))

    @property
    def values(self) -> KList:
        return KList(list(self._data.values()))

    def get_suffix(self, name: str) -> Any:
        key = name.lower()
        if key == "keys":
            return self.keys
        if key == "values":
            return self.values
        if key == "length":
            return self.length
        if key == "haskey":
            return self.has_key
        if key == "add":
            return self._add
        if key == "remove":
            return self._remove
        # bare key access via suffix for string keys that are identifiers
        if self.has_key(name):
            return self[name]
        raise AttributeError(name)

    def _add(self, key: Any, value: Any) -> None:
        self[key] = value

    def _remove(self, key: Any) -> None:
        if key in self._data:
            del self._data[key]


class KList:
    def __init__(self, items: list[Any] | None = None) -> None:
        self._items: list[Any] = list(items or [])

    def __len__(self) -> int:
        return len(self._items)

    def __iter__(self) -> TypingIterator[Any]:
        return iter(self._items)

    def __getitem__(self, index: int) -> Any:
        return self._items[int(index)]

    def __setitem__(self, index: int, value: Any) -> None:
        self._items[int(index)] = value

    @property
    def length(self) -> int:
        return len(self._items)

    def add(self, value: Any) -> None:
        self._items.append(value)

    def contains(self, value: Any) -> bool:
        return any(kos_equal(v, value) for v in self._items)

    def join(self, sep: str) -> str:
        return str(sep).join(str(x) for x in self._items)

    @property
    def iterator(self) -> KIterator:
        return KIterator(self._items)

    def get_suffix(self, name: str) -> Any:
        key = name.lower()
        if key == "length":
            return self.length
        if key == "add":
            return self.add
        if key == "contains":
            return self.contains
        if key == "join":
            return self.join
        if key == "iterator":
            return self.iterator
        if key == "clear":
            return self._items.clear
        raise AttributeError(name)


class KQueue:
    def __init__(self, items: list[Any] | None = None) -> None:
        self._items: list[Any] = list(items or [])

    def __len__(self) -> int:
        return len(self._items)

    def __iter__(self) -> TypingIterator[Any]:
        return iter(self._items)

    @property
    def length(self) -> int:
        return len(self._items)

    def push(self, value: Any) -> None:
        self._items.append(value)

    def pop(self) -> Any:
        if not self._items:
            raise IndexError("pop from empty queue")
        return self._items.pop(0)

    def peek(self) -> Any:
        return self._items[0]

    def clear(self) -> None:
        self._items.clear()

    def get_suffix(self, name: str) -> Any:
        key = name.lower()
        if key == "length":
            return self.length
        if key == "push":
            return self.push
        if key == "pop":
            return self.pop
        if key == "peek":
            return self.peek
        if key == "clear":
            return self.clear
        if key == "iterator":
            return KIterator(self._items)
        raise AttributeError(name)


class KIterator:
    def __init__(self, items: list[Any]) -> None:
        self._items = list(items)
        self._index = -1

    def next(self) -> bool:
        self._index += 1
        return self._index < len(self._items)

    @property
    def index(self) -> int:
        return self._index

    @property
    def value(self) -> Any:
        return self._items[self._index]

    def get_suffix(self, name: str) -> Any:
        key = name.lower()
        if key == "next":
            return self.next
        if key == "index":
            return self.index
        if key == "value":
            return self.value
        raise AttributeError(name)
