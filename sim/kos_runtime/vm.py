from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from kos_runtime import ast_nodes as ast
from kos_runtime.builtins import install_builtins
from kos_runtime.env import Environment
from kos_runtime.parser import parse_script
from kos_runtime.values import (
    Delegate,
    Direction,
    KList,
    KQueue,
    KVector,
    Lexicon,
    Structure,
    UserFunction,
    as_vector,
    kos_equal,
    kos_truthy,
)


class ReturnSignal(Exception):
    def __init__(self, value: Any = None) -> None:
        self.value = value


class BreakSignal(Exception):
    pass


@dataclass
class OnTrigger:
    condition: Any
    body: Any
    env: Environment
    last_value: Any = None


class VirtualMachine:
    def __init__(self, host: Any) -> None:
        self.host = host
        self.global_env = Environment()
        install_builtins(self.global_env, host)
        self._run_once_cache: set[str] = set()
        self._on_triggers: list[OnTrigger] = []
        self._locks: dict[str, tuple[Any, Environment]] = {}
        self._current_env = self.global_env
        self._arg_stack: list[list[Any]] = []
        self._bind_host_globals()

    # ---- public API ----

    def run_path(self, path: str, args: list[Any] | None = None) -> Any:
        source = self.host.read_script(path)
        script = parse_script(source, filename=path)
        return self.run_script(script, args=args, path=path)

    def run_script(self, script: ast.Script, args: list[Any] | None = None, path: str = "") -> Any:
        env = self.global_env
        # File-level `parameter` stmts (anywhere) consume from this arg list in order.
        self._arg_stack.append(list(args or []))
        try:
            result = None
            for stmt in script.statements:
                result = self.exec_stmt(stmt, env)
                self._poll_triggers(env)
            return result
        finally:
            self._arg_stack.pop()

    def run_source(self, source: str, filename: str = "<string>", args: list[Any] | None = None) -> Any:
        script = parse_script(source, filename=filename)
        return self.run_script(script, args=args, path=filename)

    # ---- statement execution ----

    def _expand_stmt(self, stmt: Any) -> list[Any]:
        if isinstance(stmt, ast.Block) and stmt.statements and all(
            isinstance(s, ast.Parameter) for s in stmt.statements
        ):
            return list(stmt.statements)
        return [stmt]

    def exec_stmt(self, stmt: Any, env: Environment) -> Any:
        for s in self._expand_stmt(stmt):
            result = self._exec_one(s, env)
        return result

    def _exec_one(self, stmt: Any, env: Environment) -> Any:
        self._current_env = env

        if isinstance(stmt, ast.Block):
            return self.exec_block(stmt, env)

        if isinstance(stmt, ast.FunctionDef):
            fn = UserFunction(stmt.name, stmt.body, env)
            env.define(stmt.name, fn)
            return fn

        if isinstance(stmt, ast.Parameter):
            # File-level parameters consume runPath/runOncePath args; function
            # parameters are bound in call_user_function before the body runs.
            if self._arg_stack:
                args = self._arg_stack[-1]
                if args:
                    env.define(stmt.name, args.pop(0))
                    return None
            if stmt.default is not None:
                env.define(stmt.name, self.eval_expr(stmt.default, env))
            elif not env.has(stmt.name):
                env.define(stmt.name, None)
            return None

        if isinstance(stmt, ast.LocalDecl):
            value = self.eval_expr(stmt.value, env)
            if stmt.global_:
                self.global_env.define(stmt.name, value)
            else:
                env.define(stmt.name, value)
            return value

        if isinstance(stmt, ast.SetStmt):
            value = self.eval_expr(stmt.value, env)
            self.assign(stmt.target, value, env)
            return value

        if isinstance(stmt, ast.IfStmt):
            if kos_truthy(self.eval_expr(stmt.condition, env)):
                return self.exec_stmt(stmt.then_body, env)
            if stmt.else_body is not None:
                return self.exec_stmt(stmt.else_body, env)
            return None

        if isinstance(stmt, ast.UntilStmt):
            result = None
            while not kos_truthy(self.eval_expr(stmt.condition, env)):
                try:
                    result = self.exec_stmt(stmt.body, env)
                except BreakSignal:
                    break
                self._poll_triggers(env)
            return result

        if isinstance(stmt, ast.ForStmt):
            iterable = self.eval_expr(stmt.iterable, env)
            items = self._as_iterable(iterable)
            result = None
            for item in items:
                env.define(stmt.name, item)
                try:
                    result = self.exec_stmt(stmt.body, env)
                except BreakSignal:
                    break
                self._poll_triggers(env)
            return result

        if isinstance(stmt, ast.ReturnStmt):
            value = self.eval_expr(stmt.value, env) if stmt.value is not None else None
            raise ReturnSignal(value)

        if isinstance(stmt, ast.BreakStmt):
            raise BreakSignal()

        if isinstance(stmt, ast.LockStmt):
            self._locks[stmt.name.lower()] = (stmt.expression, env)
            name = stmt.name.lower()
            if name == "throttle":
                expr, lock_env = stmt.expression, env

                def throttle_eval(e: Any = expr, le: Environment = lock_env) -> float:
                    return float(self.eval_expr(e, le))

                if hasattr(self.host, "set_throttle_evaluator"):
                    self.host.set_throttle_evaluator(throttle_eval)
                else:
                    self.host.set_throttle_lock(throttle_eval())
            elif name == "steering":
                expr, lock_env = stmt.expression, env

                def steering_eval(e: Any = expr, le: Environment = lock_env) -> Any:
                    return self.eval_expr(e, le)

                if hasattr(self.host, "set_steering_evaluator"):
                    self.host.set_steering_evaluator(steering_eval)
                else:
                    self.host.set_steering_lock(steering_eval())
            return None

        if isinstance(stmt, ast.UnlockStmt):
            name = stmt.name.lower()
            self._locks.pop(name, None)
            if name == "throttle":
                if hasattr(self.host, "set_throttle_evaluator"):
                    self.host.set_throttle_evaluator(None)
                self.host.set_throttle_lock(None)
            elif name == "steering":
                if hasattr(self.host, "set_steering_evaluator"):
                    self.host.set_steering_evaluator(None)
                self.host.set_steering_lock(None)
            return None

        if isinstance(stmt, ast.OnStmt):
            initial = self.eval_expr(stmt.condition, env)
            self._on_triggers.append(
                OnTrigger(condition=stmt.condition, body=stmt.body, env=env, last_value=initial)
            )
            return None

        if isinstance(stmt, ast.WaitStmt):
            if stmt.until:
                while not kos_truthy(self.eval_expr(stmt.value, env)):
                    self.host.advance(0.1)
                    self._poll_triggers(env)
            else:
                seconds = float(self.eval_expr(stmt.value, env))
                # cooperative stepping in chunks so locks/triggers update
                remaining = max(0.0, seconds)
                while remaining > 1e-12:
                    step = min(remaining, 0.2)
                    self.host.advance(step)
                    remaining -= step
                    self._poll_triggers(env)
            return None

        if isinstance(stmt, ast.StageStmt):
            self.host.stage()
            return None

        if isinstance(stmt, ast.FlagStmt):
            which = stmt.which.lower()
            if which == "rcs":
                self.host.set_rcs(stmt.enabled)
            elif which == "sas":
                self.host.set_sas(stmt.enabled)
            elif which == "abort":
                self.host.set_abort(stmt.enabled)
            else:
                raise NotImplementedError(f"flag {which}")
            return None

        if isinstance(stmt, ast.PrintStmt):
            value = self.eval_expr(stmt.value, env)
            printer = env.get("__print__")
            if stmt.at is not None:
                x = self.eval_expr(stmt.at[0], env)
                y = self.eval_expr(stmt.at[1], env)
                printer(value, x, y)
            else:
                printer(value)
            return None

        if isinstance(stmt, ast.ClearScreenStmt):
            env.get("__clearscreen__")()
            return None

        if isinstance(stmt, ast.SwitchStmt):
            volume = self.eval_expr(stmt.volume, env)
            self.host.switch_to(volume)
            return None

        if isinstance(stmt, ast.ListInStmt):
            what = stmt.what.lower()
            if what == "engines":
                engines = self.host.ship.engines()
                env.set(stmt.target, KList(list(engines)))
            else:
                raise NotImplementedError(f"list {what} in")
            return None

        if isinstance(stmt, ast.RunStmt):
            return self._exec_run(stmt, env)

        if isinstance(stmt, ast.ExprStmt):
            return self.eval_expr(stmt.value, env)

        raise NotImplementedError(f"statement {type(stmt).__name__}")

    def exec_block(self, block: ast.Block, env: Environment) -> Any:
        # kOS blocks share the enclosing function/file scope (no block-local set/local).
        result = None
        for stmt in block.statements:
            result = self.exec_stmt(stmt, env)
            self._poll_triggers(env)
        return result

    def _exec_run(self, stmt: ast.RunStmt, env: Environment) -> Any:
        kind = stmt.kind.lower()
        args = [self.eval_expr(a, env) for a in stmt.args]
        if not args:
            raise TypeError("run requires a path")
        path = str(args[0])
        rest = args[1:]
        resolved = self._resolve_script_key(path)
        if kind == "runoncepath":
            if resolved in self._run_once_cache:
                return None
            self._run_once_cache.add(resolved)
            return self.run_path(path, args=rest)
        if kind in {"runpath", "run"}:
            return self.run_path(path, args=rest)
        raise NotImplementedError(f"run kind {kind}")

    def _resolve_script_key(self, path: str) -> str:
        try:
            return self.host.resolve_path(path)
        except Exception:
            return path

    # ---- expressions ----

    def eval_expr(self, expr: Any, env: Environment) -> Any:
        if expr is None:
            return None

        if isinstance(expr, ast.Number):
            return expr.value

        if isinstance(expr, ast.String):
            return expr.value

        if isinstance(expr, ast.Boolean):
            return expr.value

        if isinstance(expr, ast.Name):
            return self.lookup_name(expr.value, env)

        if isinstance(expr, ast.UnaryOp):
            operand = self.eval_expr(expr.operand, env)
            if expr.op == "not":
                return not kos_truthy(operand)
            if expr.op == "-":
                if isinstance(operand, KVector) or hasattr(operand, "x"):
                    v = as_vector(operand)
                    return KVector(-v.x, -v.y, -v.z)
                return -float(operand)
            if expr.op == "+":
                return operand
            raise NotImplementedError(f"unary op {expr.op}")

        if isinstance(expr, ast.BinaryOp):
            return self.eval_binary(expr, env)

        if isinstance(expr, ast.Call):
            return self.eval_call(expr.name, [self.eval_expr(a, env) for a in expr.args], env)

        if isinstance(expr, ast.Suffix):
            return self.eval_suffix(expr, env)

        if isinstance(expr, ast.Delegate):
            base = self.eval_expr(expr.base, env)
            if isinstance(base, UserFunction):
                return base.as_delegate()
            if isinstance(base, Delegate):
                return base
            if callable(base):
                return Delegate(base, env)
            raise TypeError(f"cannot take delegate of {type(base)!r}")

        if isinstance(expr, ast.Index):
            base = self.eval_expr(expr.base, env)
            index = self.eval_expr(expr.index, env)
            if isinstance(base, Lexicon):
                return base[index]
            if isinstance(base, KList):
                return base[int(index)]
            if isinstance(base, dict):
                return base[index]
            if isinstance(base, (list, tuple)):
                return base[int(index)]
            # try suffix getitem
            if hasattr(base, "__getitem__"):
                return base[index]
            raise TypeError(f"cannot index {type(base)!r}")

        if isinstance(expr, ast.LexiconLiteral):
            pairs = [(self.eval_expr(k, env), self.eval_expr(v, env)) for k, v in expr.pairs]
            return Lexicon(pairs)

        if isinstance(expr, ast.ListLiteral):
            return KList([self.eval_expr(i, env) for i in expr.items])

        if isinstance(expr, ast.QueueLiteral):
            return KQueue([self.eval_expr(i, env) for i in expr.items])

        raise NotImplementedError(f"expression {type(expr).__name__}")

    def eval_binary(self, expr: ast.BinaryOp, env: Environment) -> Any:
        op = expr.op
        if op == "and":
            left = self.eval_expr(expr.left, env)
            if not kos_truthy(left):
                return False
            return kos_truthy(self.eval_expr(expr.right, env))
        if op == "or":
            left = self.eval_expr(expr.left, env)
            if kos_truthy(left):
                return True
            return kos_truthy(self.eval_expr(expr.right, env))

        left = self.eval_expr(expr.left, env)
        right = self.eval_expr(expr.right, env)

        if op == "=":
            return kos_equal(left, right)
        if op == "<>":
            return not kos_equal(left, right)
        if op in {">", "<", ">=", "<="}:
            lv, rv = float(left), float(right)
            if op == ">":
                return lv > rv
            if op == "<":
                return lv < rv
            if op == ">=":
                return lv >= rv
            return lv <= rv

        if op == "+":
            if isinstance(left, str) or isinstance(right, str):
                return str(left) + str(right)
            if isinstance(left, Direction) or isinstance(right, Direction):
                ldir = left if isinstance(left, Direction) else self._as_direction(left)
                rdir = right if isinstance(right, Direction) else self._as_direction(right)
                return ldir + rdir
            if self._is_vectorish(left) or self._is_vectorish(right):
                return as_vector(left) + as_vector(right)
            return float(left) + float(right)

        if op == "-":
            if self._is_vectorish(left) or self._is_vectorish(right):
                return as_vector(left) - as_vector(right)
            return float(left) - float(right)

        if op == "*":
            if self._is_vectorish(left) and not self._is_vectorish(right):
                return as_vector(left) * float(right)
            if self._is_vectorish(right) and not self._is_vectorish(left):
                return as_vector(right) * float(left)
            return float(left) * float(right)

        if op == "/":
            if self._is_vectorish(left):
                return as_vector(left) / float(right)
            return float(left) / float(right)

        if op == "^":
            # KerboScript power — keep results real (frac power of negatives → |x|^y)
            base = float(left)
            exp = float(right)
            if base < 0 and abs(exp - round(exp)) > 1e-12:
                return -(abs(base) ** exp)
            return base ** exp

        raise NotImplementedError(f"binary op {op}")

    def eval_call(self, name: str, args: list[Any], env: Environment) -> Any:
        callee = self.lookup_name(name, env)
        return self.call_value(callee, args, env)

    def call_value(self, callee: Any, args: list[Any], env: Environment) -> Any:
        if isinstance(callee, UserFunction):
            return self.call_user_function(callee, args)
        if isinstance(callee, Delegate):
            return self.call_value(callee.fn, args, env)
        if callable(callee):
            return callee(*args)
        raise TypeError(f"object is not callable: {type(callee)!r}")

    def call_user_function(self, fn: UserFunction, args: list[Any]) -> Any:
        local = fn.env.child()
        body = fn.body
        if body is None:
            return None
        stmts = list(body.statements)
        # Push args so Parameter stmts inside the function consume them.
        # Also pre-bind leading parameters for clarity / defaults.
        self._arg_stack.append(list(args))
        try:
            result = None
            for stmt in stmts:
                result = self.exec_stmt(stmt, local)
            return result
        except ReturnSignal as ret:
            return ret.value
        finally:
            self._arg_stack.pop()

    _AUTO_SUFFIXES = frozenset(
        {
            "normalized",
            "direction",
            "vector",
            "mag",
            "sqrmagnitude",
            "starvector",
            "forevector",
            "topvector",
            "vacuum",
            "next",
            "haschar",
            "length",
            "iterator",
            "keys",
            "values",
            "index",
            "value",
        }
    )

    def eval_suffix(self, expr: ast.Suffix, env: Environment) -> Any:
        base = self.eval_expr(expr.base, env)
        value = self.sound_suffix(base, expr.name, env)
        if expr.call_args is not None:
            args = [self.eval_expr(a, env) for a in expr.call_args]
            return self.call_value(value, args, env)
        # kOS property-like suffixes (e.g. iterator:next) invoke with no ()
        key = expr.name.lower()
        if (
            key in self._AUTO_SUFFIXES
            and callable(value)
            and not isinstance(value, (UserFunction, Delegate))
        ):
            try:
                return self._coerce_value(value(), key)
            except TypeError:
                pass
        return value

    def sound_suffix(self, base: Any, name: str, env: Environment) -> Any:
        key = name.lower()

        # Native wrappers
        if hasattr(base, "get_suffix"):
            try:
                return self._coerce_value(base.get_suffix(name), key)
            except AttributeError:
                pass

        # dict-like
        if isinstance(base, dict):
            for k, v in base.items():
                if str(k).lower() == key:
                    return self._coerce_value(v, key)

        # object attribute sounding (case-insensitive, camel/snake)
        if base is not None:
            attr = self._find_attr(base, name)
            if attr is not None:
                if callable(attr) and not isinstance(attr, (UserFunction, Delegate)):
                    return attr
                return self._coerce_value(attr, key)

        raise AttributeError(f"suffix :{name} on {type(base)!r}")

    def _coerce_value(self, value: Any, suffix: str = "") -> Any:
        if isinstance(value, (KVector, Direction, Lexicon, KList, KQueue, Structure, UserFunction, Delegate)):
            return value
        if suffix == "vector" or (
            hasattr(value, "x") and hasattr(value, "y") and hasattr(value, "z") and not hasattr(value, "pitch")
        ):
            try:
                return as_vector(value)
            except TypeError:
                return value
        if hasattr(value, "vector") and hasattr(value, "pitch"):
            return self._wrap_direction(value)
        return value

    def _find_attr(self, obj: Any, name: str) -> Any | None:
        key = name.lower()
        # direct
        if hasattr(obj, name):
            return getattr(obj, name)
        # case-insensitive
        for attr in dir(obj):
            if attr.lower() == key and not attr.startswith("_"):
                return getattr(obj, attr)
        # snake_case from camelCase
        snake = self._to_snake(name)
        if hasattr(obj, snake):
            return getattr(obj, snake)
        # camelCase variants
        camel = name[:1].lower() + name[1:] if name else name
        if hasattr(obj, camel):
            return getattr(obj, camel)
        # known aliases
        aliases = {
            "rotationperiod": "rotation_period",
            "geoPosition": "geoposition",
            "geoposition": "geoposition",
            "availablethrust": "available_thrust",
            "verticalspeed": "vertical_speed",
            "srfprograde": "srfprograde",
            "modulesnamed": "modules_named",
            "hasevent": "has_event",
            "doevent": "do_event",
            "haschar": "terminal_has_char",
            "getchar": "terminal_get_char",
        }
        alias = aliases.get(key)
        if alias and hasattr(obj, alias):
            return getattr(obj, alias)
        # nested atm on body
        if key == "atm" and hasattr(obj, "atm_height"):
            return Structure(
                _fields={
                    "height": getattr(obj, "atm_height"),
                }
            )
        return None

    @staticmethod
    def _to_snake(name: str) -> str:
        out: list[str] = []
        for i, ch in enumerate(name):
            if ch.isupper() and i > 0:
                out.append("_")
                out.append(ch.lower())
            else:
                out.append(ch.lower())
        return "".join(out)

    # ---- assignment ----

    def assign(self, target: Any, value: Any, env: Environment) -> None:
        if isinstance(target, ast.Name):
            env.set(target.value, value)
            return
        if isinstance(target, ast.Suffix):
            base = self.eval_expr(target.base, env)
            if isinstance(base, Lexicon):
                base[target.name] = value
                return
            if isinstance(base, Structure):
                base.set_suffix(target.name, value)
                return
            if target.call_args is not None:
                raise TypeError("cannot assign to call")
            for candidate in (target.name, self._to_snake(target.name), target.name.lower()):
                try:
                    setattr(base, candidate, value)
                    return
                except Exception:
                    continue
            raise AttributeError(f"cannot assign :{target.name}")
        if isinstance(target, ast.Index):
            base = self.eval_expr(target.base, env)
            index = self.eval_expr(target.index, env)
            if isinstance(base, Lexicon):
                base[index] = value
                return
            if isinstance(base, KList):
                base[int(index)] = value
                return
            base[index] = value
            return
        raise NotImplementedError(f"assign to {type(target).__name__}")

    # ---- name lookup / host bindings ----

    def lookup_name(self, name: str, env: Environment) -> Any:
        key = name.lower()
        if env.has(name):
            val = env.get(name)
            # lazy host bindings stored as callables with marker
            if isinstance(val, _LazyBound):
                return val()
            return val
        # bound identifiers from flight
        bound = self._bound_value(key)
        if bound is not _MISSING:
            return bound
        raise NameError(name)

    def _bind_host_globals(self) -> None:
        env = self.global_env

        def lazy(fn: Callable[[], Any]) -> _LazyBound:
            return _LazyBound(fn)

        env.define("ship", lazy(lambda: self.host.ship))
        env.define("body", lazy(lambda: self.host.body))
        env.define(
            "time",
            lazy(
                lambda: Structure(
                    _fields={
                        "seconds": lambda: self.host.time_seconds,
                    }
                )
            ),
        )
        # time used as value in WaitUntil(time) — Structure with seconds
        # Also support bare time comparing via :seconds

        env.define(
            "eta",
            lazy(
                lambda: Structure(
                    _fields={
                        "apoapsis": lambda: self.host.eta_apoapsis(),
                        "periapsis": lambda: self.host.eta_periapsis(),
                    }
                )
            ),
        )

        env.define(
            "terminal",
            lazy(
                lambda: Structure(
                    _fields={
                        "input": Structure(
                            _fields={
                                "enter": "\n",
                                "haschar": lambda: self.host.terminal_has_char(),
                            },
                            _methods={
                                "getchar": lambda: self.host.terminal_get_char(),
                            },
                        )
                    }
                )
            ),
        )

        env.define("altitude", lazy(lambda: self.host.ship.altitude))
        env.define("apoapsis", lazy(lambda: self.host.ship.apoapsis))
        env.define("periapsis", lazy(lambda: self.host.ship.periapsis))
        env.define("prograde", lazy(lambda: self._wrap_direction(self.host.ship.prograde)))
        env.define(
            "srfprograde",
            lazy(lambda: self._wrap_direction(getattr(self.host.ship, "srfprograde", self.host.ship.prograde))),
        )
        env.define("up", lazy(lambda: self._wrap_direction(self.host.ship.up)))
        env.define("north", lazy(lambda: self._wrap_direction(self.host.ship.north)))
        env.define(
            "verticalspeed",
            lazy(
                lambda: getattr(
                    self.host.ship,
                    "verticalspeed",
                    getattr(self.host.ship, "vertical_speed", 0.0),
                )
            ),
        )
        env.define("missiontime", lazy(lambda: self.host.mission_time))
        env.define(
            "steering",
            lazy(
                lambda: self._wrap_direction(
                    self.host.evaluate_steering()
                    if hasattr(self.host, "evaluate_steering")
                    else self.host.ship.facing
                )
            ),
        )
        env.define(
            "throttle",
            lazy(
                lambda: self.host.evaluate_throttle()
                if hasattr(self.host, "evaluate_throttle")
                else 0.0
            ),
        )
        def _abort_flag() -> bool:
            physics = getattr(self.host, "physics", None)
            if physics is not None:
                state = getattr(physics, "state", None)
                if state is not None:
                    return bool(getattr(state, "abort", False))
            return False

        env.define("abort", lazy(_abort_flag))

    def _bound_value(self, key: str) -> Any:
        return _MISSING

    def _wrap_direction(self, d: Any) -> Direction:
        if isinstance(d, Direction):
            return d
        vec = as_vector(getattr(d, "vector", d))
        return Direction(
            vector=vec,
            pitch=float(getattr(d, "pitch", 0.0)),
            yaw=float(getattr(d, "yaw", 0.0)),
            roll=float(getattr(d, "roll", 0.0)),
        )

    def _as_direction(self, value: Any) -> Direction:
        return self._wrap_direction(value)

    def _is_vectorish(self, value: Any) -> bool:
        if isinstance(value, KVector):
            return True
        if isinstance(value, Direction):
            return False
        return hasattr(value, "x") and hasattr(value, "y") and hasattr(value, "z")

    def _as_iterable(self, value: Any) -> list[Any]:
        if isinstance(value, (KList, KQueue)):
            return list(value)
        if isinstance(value, (list, tuple)):
            return list(value)
        if hasattr(value, "__iter__"):
            return list(value)
        raise TypeError(f"not iterable: {type(value)!r}")

    def _poll_triggers(self, env: Environment) -> None:
        for trigger in list(self._on_triggers):
            try:
                current = self.eval_expr(trigger.condition, trigger.env)
            except Exception:
                continue
            # fire on change to truthy (kOS on-trigger semantics: when value changes)
            if current != trigger.last_value:
                prev = trigger.last_value
                trigger.last_value = current
                if kos_truthy(current) and not kos_truthy(prev):
                    try:
                        self.exec_stmt(trigger.body, trigger.env)
                    except ReturnSignal:
                        pass


class _LazyBound:
    def __init__(self, fn: Callable[[], Any]) -> None:
        self.fn = fn

    def __call__(self) -> Any:
        return self.fn()


_MISSING = object()
