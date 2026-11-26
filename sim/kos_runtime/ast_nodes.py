from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Node:
    line: int = 0
    column: int = 0


@dataclass
class Script(Node):
    statements: list[Any] = field(default_factory=list)


@dataclass
class Block(Node):
    statements: list[Any] = field(default_factory=list)


@dataclass
class FunctionDef(Node):
    name: str = ""
    body: Block | None = None


@dataclass
class Parameter(Node):
    name: str = ""
    default: Any | None = None


@dataclass
class LocalDecl(Node):
    name: str = ""
    value: Any = None
    global_: bool = False


@dataclass
class SetStmt(Node):
    target: Any = None
    value: Any = None


@dataclass
class IfStmt(Node):
    condition: Any = None
    then_body: Any = None
    else_body: Any | None = None


@dataclass
class UntilStmt(Node):
    condition: Any = None
    body: Any = None


@dataclass
class ForStmt(Node):
    name: str = ""
    iterable: Any = None
    body: Any = None


@dataclass
class ReturnStmt(Node):
    value: Any | None = None


@dataclass
class LockStmt(Node):
    name: str = ""
    expression: Any = None


@dataclass
class UnlockStmt(Node):
    name: str = ""


@dataclass
class OnStmt(Node):
    condition: Any = None
    body: Any = None


@dataclass
class WaitStmt(Node):
    value: Any = None
    until: bool = False


@dataclass
class StageStmt(Node):
    pass


@dataclass
class FlagStmt(Node):
    which: str = ""  # rcs|sas|abort
    enabled: bool = True


@dataclass
class PrintStmt(Node):
    value: Any = None
    at: tuple[Any, Any] | None = None


@dataclass
class ClearScreenStmt(Node):
    pass


@dataclass
class SwitchStmt(Node):
    volume: Any = None


@dataclass
class ListInStmt(Node):
    what: str = ""
    target: str = ""


@dataclass
class RunStmt(Node):
    kind: str = "runOncePath"
    args: list[Any] = field(default_factory=list)


@dataclass
class ExprStmt(Node):
    value: Any = None


@dataclass
class BinaryOp(Node):
    op: str = ""
    left: Any = None
    right: Any = None


@dataclass
class UnaryOp(Node):
    op: str = ""
    operand: Any = None


@dataclass
class Suffix(Node):
    base: Any = None
    name: str = ""
    call_args: list[Any] | None = None


@dataclass
class Delegate(Node):
    base: Any = None


@dataclass
class Call(Node):
    name: str = ""
    args: list[Any] = field(default_factory=list)


@dataclass
class Name(Node):
    value: str = ""


@dataclass
class Number(Node):
    value: float = 0.0


@dataclass
class String(Node):
    value: str = ""


@dataclass
class Boolean(Node):
    value: bool = False


@dataclass
class LexiconLiteral(Node):
    pairs: list[tuple[Any, Any]] = field(default_factory=list)


@dataclass
class ListLiteral(Node):
    items: list[Any] = field(default_factory=list)


@dataclass
class QueueLiteral(Node):
    items: list[Any] = field(default_factory=list)


@dataclass
class Index(Node):
    base: Any = None
    index: Any = None


@dataclass
class BreakStmt(Node):
    pass
