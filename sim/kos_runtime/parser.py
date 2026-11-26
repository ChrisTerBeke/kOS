from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from kos_runtime import ast_nodes as ast


class ParseError(Exception):
    def __init__(self, message: str, filename: str = "", line: int = 0, column: int = 0) -> None:
        self.filename = filename
        self.line = line
        self.column = column
        loc = f"{filename}:{line}:{column}: " if filename else ""
        super().__init__(f"{loc}{message}")


@dataclass
class Token:
    kind: str
    value: str
    line: int
    column: int


KEYWORDS = {
    "function",
    "parameter",
    "local",
    "global",
    "set",
    "to",
    "is",
    "if",
    "else",
    "until",
    "for",
    "in",
    "return",
    "lock",
    "unlock",
    "on",
    "off",
    "wait",
    "stage",
    "rcs",
    "sas",
    "abort",
    "print",
    "at",
    "clearscreen",
    "switch",
    "list",
    "runoncepath",
    "runpath",
    "run",
    "and",
    "or",
    "not",
    "true",
    "false",
    "lexicon",
    "queue",
    "break",
    "from",
    "when",
    "then",
    "preserve",
}


def tokenize(source: str, filename: str = "<string>") -> list[Token]:
    tokens: list[Token] = []
    i = 0
    line = 1
    col = 1
    n = len(source)

    def advance(count: int = 1) -> None:
        nonlocal i, line, col
        for _ in range(count):
            if i < n and source[i] == "\n":
                line += 1
                col = 1
            else:
                col += 1
            i += 1

    while i < n:
        ch = source[i]

        # whitespace
        if ch in " \t\r\f":
            advance()
            continue
        if ch == "\n":
            advance()
            continue
        # line continuation
        if ch == "\\":
            advance()
            continue

        # comments
        if ch == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                advance()
            continue

        start_line, start_col = line, col

        # string
        if ch == '"':
            advance()
            buf: list[str] = []
            while i < n and source[i] != '"':
                if source[i] == "\n":
                    raise ParseError("unterminated string", filename, start_line, start_col)
                buf.append(source[i])
                advance()
            if i >= n:
                raise ParseError("unterminated string", filename, start_line, start_col)
            advance()  # closing "
            tokens.append(Token("STRING", "".join(buf), start_line, start_col))
            continue

        # number — do not consume statement-terminating `.` (e.g. `1.` or `0.1.`)
        if ch.isdigit() or (ch == "." and i + 1 < n and source[i + 1].isdigit()):
            buf: list[str] = []
            if ch == ".":
                buf.append(".")
                advance()
                while i < n and source[i].isdigit():
                    buf.append(source[i])
                    advance()
            else:
                while i < n and source[i].isdigit():
                    buf.append(source[i])
                    advance()
                # fractional part only if `.` is followed by a digit
                if i < n and source[i] == "." and i + 1 < n and source[i + 1].isdigit():
                    buf.append(".")
                    advance()
                    while i < n and source[i].isdigit():
                        buf.append(source[i])
                        advance()
            if i < n and source[i] in "eE":
                buf.append(source[i])
                advance()
                if i < n and source[i] in "+-":
                    buf.append(source[i])
                    advance()
                while i < n and source[i].isdigit():
                    buf.append(source[i])
                    advance()
            tokens.append(Token("NUMBER", "".join(buf), start_line, start_col))
            continue

        # identifier / keyword
        if ch.isalpha() or ch == "_":
            buf = []
            while i < n and (source[i].isalnum() or source[i] == "_"):
                buf.append(source[i])
                advance()
            raw = "".join(buf)
            lower = raw.lower()
            if lower in KEYWORDS:
                tokens.append(Token(lower, raw, start_line, start_col))
            else:
                tokens.append(Token("NAME", raw, start_line, start_col))
            continue

        # multi-char operators
        if ch == "<":
            if i + 1 < n and source[i + 1] == ">":
                advance(2)
                tokens.append(Token("OP", "<>", start_line, start_col))
                continue
            if i + 1 < n and source[i + 1] == "=":
                advance(2)
                tokens.append(Token("OP", "<=", start_line, start_col))
                continue
            advance()
            tokens.append(Token("OP", "<", start_line, start_col))
            continue
        if ch == ">":
            if i + 1 < n and source[i + 1] == "=":
                advance(2)
                tokens.append(Token("OP", ">=", start_line, start_col))
                continue
            advance()
            tokens.append(Token("OP", ">", start_line, start_col))
            continue
        if ch == "=":
            advance()
            tokens.append(Token("OP", "=", start_line, start_col))
            continue

        # single-char
        if ch in "+-*/^(){},.:[]@":
            advance()
            tokens.append(Token(ch, ch, start_line, start_col))
            continue

        raise ParseError(f"unexpected character {ch!r}", filename, line, col)

    tokens.append(Token("EOF", "", line, col))
    return tokens


class Parser:
    def __init__(self, tokens: list[Token], filename: str = "<string>") -> None:
        self.tokens = tokens
        self.filename = filename
        self.pos = 0

    def current(self) -> Token:
        return self.tokens[self.pos]

    def peek(self, offset: int = 0) -> Token:
        idx = self.pos + offset
        if idx >= len(self.tokens):
            return self.tokens[-1]
        return self.tokens[idx]

    def check(self, *kinds: str) -> bool:
        return self.current().kind in kinds

    def check_op(self, *ops: str) -> bool:
        return self.current().kind == "OP" and self.current().value in ops

    def match(self, *kinds: str) -> Token | None:
        if self.check(*kinds):
            tok = self.current()
            self.pos += 1
            return tok
        return None

    def match_op(self, *ops: str) -> Token | None:
        if self.check_op(*ops):
            tok = self.current()
            self.pos += 1
            return tok
        return None

    def expect(self, *kinds: str) -> Token:
        tok = self.match(*kinds)
        if tok is None:
            cur = self.current()
            raise ParseError(
                f"expected {kinds}, got {cur.kind} ({cur.value!r})",
                self.filename,
                cur.line,
                cur.column,
            )
        return tok

    def optional_dot(self) -> None:
        self.match(".")

    def at_statement_boundary(self) -> bool:
        """True if current token starts a new statement or ends a block."""
        k = self.current().kind
        if k in {
            "EOF",
            "}",
            "function",
            "parameter",
            "local",
            "global",
            "set",
            "if",
            "else",
            "until",
            "for",
            "return",
            "lock",
            "unlock",
            "on",
            "wait",
            "stage",
            "rcs",
            "sas",
            "abort",
            "print",
            "clearscreen",
            "switch",
            "break",
            "runoncepath",
            "runpath",
            "run",
            "when",
        }:
            return True
        # `list NAME in NAME` statement vs list(...) call
        if k == "list":
            nxt = self.peek(1)
            if nxt.kind == "NAME" and self.peek(2).kind == "in":
                return True
        return False

    def parse_script(self) -> ast.Script:
        statements: list[Any] = []
        while not self.check("EOF"):
            statements.append(self.parse_statement())
        return ast.Script(statements=statements, line=1, column=1)

    def parse_statement(self) -> Any:
        tok = self.current()
        line, col = tok.line, tok.column

        if self.check("{"):
            return self.parse_block()

        if self.match("function"):
            return self.parse_function(line, col)

        if self.match("parameter"):
            return self.parse_parameter_stmt(line, col)

        if self.check("local") or self.check("global"):
            return self.parse_declare(line, col)

        if self.match("set"):
            return self.parse_set(line, col)

        if self.match("if"):
            return self.parse_if(line, col)

        if self.match("until"):
            cond = self.parse_expression()
            body = self.parse_block()
            return ast.UntilStmt(condition=cond, body=body, line=line, column=col)

        if self.match("for"):
            name = self.expect("NAME").value
            self.expect("in")
            iterable = self.parse_expression()
            body = self.parse_block()
            return ast.ForStmt(name=name, iterable=iterable, body=body, line=line, column=col)

        if self.match("return"):
            value = None
            if not self.check(".") and not self.check("}") and not self.check("EOF"):
                if not self.at_statement_boundary():
                    value = self.parse_expression()
            self.optional_dot()
            return ast.ReturnStmt(value=value, line=line, column=col)

        if self.match("lock"):
            name = self.expect("NAME").value
            self.expect("to")
            expr = self.parse_expression()
            self.optional_dot()
            return ast.LockStmt(name=name, expression=expr, line=line, column=col)

        if self.match("unlock"):
            name = self.expect("NAME").value
            self.optional_dot()
            return ast.UnlockStmt(name=name, line=line, column=col)

        if self.match("on"):
            # on <expr> { body }
            cond = self.parse_expression()
            body = self.parse_block()
            return ast.OnStmt(condition=cond, body=body, line=line, column=col)

        if self.match("wait"):
            until = False
            if self.match("until"):
                until = True
            value = self.parse_expression()
            self.optional_dot()
            return ast.WaitStmt(value=value, until=until, line=line, column=col)

        if self.match("stage"):
            self.optional_dot()
            return ast.StageStmt(line=line, column=col)

        if self.match("rcs"):
            enabled = self._on_off()
            self.optional_dot()
            return ast.FlagStmt(which="rcs", enabled=enabled, line=line, column=col)

        if self.match("sas"):
            enabled = self._on_off()
            self.optional_dot()
            return ast.FlagStmt(which="sas", enabled=enabled, line=line, column=col)

        if self.match("abort"):
            # abort on/off statement (not expression)
            if self.check("on") or self.check("off"):
                enabled = self._on_off()
                self.optional_dot()
                return ast.FlagStmt(which="abort", enabled=enabled, line=line, column=col)
            # bare abort as expression stmt? treat as flag on
            self.optional_dot()
            return ast.FlagStmt(which="abort", enabled=True, line=line, column=col)

        if self.match("print"):
            value = self.parse_expression()
            at = None
            if self.match("at"):
                self.expect("(")
                x = self.parse_expression()
                self.expect(",")
                y = self.parse_expression()
                self.expect(")")
                at = (x, y)
            self.optional_dot()
            return ast.PrintStmt(value=value, at=at, line=line, column=col)

        if self.match("clearscreen"):
            self.optional_dot()
            return ast.ClearScreenStmt(line=line, column=col)

        if self.match("switch"):
            self.expect("to")
            volume = self.parse_expression()
            self.optional_dot()
            return ast.SwitchStmt(volume=volume, line=line, column=col)

        if self.match("break"):
            self.optional_dot()
            return ast.BreakStmt(line=line, column=col)

        if self.check("list") and self.peek(1).kind == "NAME" and self.peek(2).kind == "in":
            self.match("list")
            what = self.expect("NAME").value
            self.expect("in")
            target = self.expect("NAME").value
            self.optional_dot()
            return ast.ListInStmt(what=what, target=target, line=line, column=col)

        if self.check("runoncepath") or self.check("runpath") or self.check("run"):
            kind_tok = self.current()
            kind = kind_tok.kind
            self.pos += 1
            self.expect("(")
            args = [self.parse_expression()]
            while self.match(","):
                args.append(self.parse_expression())
            self.expect(")")
            self.optional_dot()
            return ast.RunStmt(kind=kind if kind != "run" else "run", args=args, line=line, column=col)

        # expression statement
        expr = self.parse_expression()
        self.optional_dot()
        return ast.ExprStmt(value=expr, line=line, column=col)

    def _on_off(self) -> bool:
        if self.match("on"):
            return True
        if self.match("off"):
            return False
        cur = self.current()
        raise ParseError("expected on/off", self.filename, cur.line, cur.column)

    def parse_function(self, line: int, col: int) -> ast.FunctionDef:
        name = self.expect("NAME").value
        # optional unused paren param list (rare); scripts use parameter stmts
        if self.match("("):
            while not self.check(")") and not self.check("EOF"):
                self.match("NAME")
                self.match(",")
            self.expect(")")
        body = self.parse_block()
        return ast.FunctionDef(name=name, body=body, line=line, column=col)

    def parse_parameter_stmt(self, line: int, col: int) -> Any:
        """parameter a, b is expr, c.  → one or more Parameter nodes via Block-like list.

        Returns a single Parameter if one name, else a Block of Parameter stmts.
        """
        params: list[ast.Parameter] = []
        while True:
            name = self.expect("NAME").value
            default = None
            if self.match("is") or self.match("to"):
                default = self.parse_expression()
            params.append(ast.Parameter(name=name, default=default, line=line, column=col))
            if not self.match(","):
                break
        self.optional_dot()
        if len(params) == 1:
            return params[0]
        return ast.Block(statements=params, line=line, column=col)

    def parse_declare(self, line: int, col: int) -> ast.LocalDecl:
        global_ = bool(self.match("global"))
        if not global_:
            self.expect("local")
        name = self.expect("NAME").value
        if self.match("is") or self.match("to") or self.match(","):
            value = self.parse_expression()
        else:
            cur = self.current()
            raise ParseError("expected is/to after declaration", self.filename, cur.line, cur.column)
        self.optional_dot()
        return ast.LocalDecl(name=name, value=value, global_=global_, line=line, column=col)

    def parse_set(self, line: int, col: int) -> ast.SetStmt:
        target = self.parse_assignable()
        self.expect("to")
        value = self.parse_expression()
        self.optional_dot()
        return ast.SetStmt(target=target, value=value, line=line, column=col)

    def parse_if(self, line: int, col: int) -> ast.IfStmt:
        condition = self.parse_expression()
        then_body = self.parse_block()
        else_body = None
        if self.match("else"):
            if self.match("if"):
                else_body = self.parse_if(self.tokens[self.pos - 1].line, self.tokens[self.pos - 1].column)
            else:
                else_body = self.parse_block()
        return ast.IfStmt(condition=condition, then_body=then_body, else_body=else_body, line=line, column=col)

    def parse_block(self) -> ast.Block:
        start = self.expect("{")
        statements: list[Any] = []
        while not self.check("}") and not self.check("EOF"):
            statements.append(self.parse_statement())
        self.expect("}")
        return ast.Block(statements=statements, line=start.line, column=start.column)

    def parse_assignable(self) -> Any:
        return self.parse_suffix_expr()

    # ---- expressions ----

    def parse_expression(self) -> Any:
        return self.parse_or()

    def parse_or(self) -> Any:
        left = self.parse_and()
        while self.match("or"):
            right = self.parse_and()
            left = ast.BinaryOp(op="or", left=left, right=right)
        return left

    def parse_and(self) -> Any:
        left = self.parse_not()
        while self.match("and"):
            right = self.parse_not()
            left = ast.BinaryOp(op="and", left=left, right=right)
        return left

    def parse_not(self) -> Any:
        if self.match("not"):
            return ast.UnaryOp(op="not", operand=self.parse_not())
        return self.parse_compare()

    def parse_compare(self) -> Any:
        left = self.parse_sum()
        while self.check_op("=", "<>", ">=", "<=", ">", "<"):
            op = self.current().value
            self.pos += 1
            right = self.parse_sum()
            left = ast.BinaryOp(op=op, left=left, right=right)
        return left

    def parse_sum(self) -> Any:
        left = self.parse_product()
        while self.check("+") or self.check("-"):
            op = self.current().value
            self.pos += 1
            right = self.parse_product()
            left = ast.BinaryOp(op=op, left=left, right=right)
        return left

    def parse_product(self) -> Any:
        left = self.parse_power()
        while self.check("*") or self.check("/"):
            op = self.current().value
            self.pos += 1
            right = self.parse_power()
            left = ast.BinaryOp(op=op, left=left, right=right)
        return left

    def parse_power(self) -> Any:
        left = self.parse_unary()
        if self.check("^"):
            self.pos += 1
            right = self.parse_power()  # right-assoc
            return ast.BinaryOp(op="^", left=left, right=right)
        return left

    def parse_unary(self) -> Any:
        if self.check("+") or self.check("-"):
            op = self.current().value
            self.pos += 1
            return ast.UnaryOp(op=op, operand=self.parse_unary())
        return self.parse_suffix_expr()

    def parse_suffix_expr(self) -> Any:
        expr = self.parse_primary()
        while True:
            if self.match(":"):
                name = self.expect("NAME").value
                call_args = None
                if self.check("("):
                    call_args = self.parse_call_args()
                expr = ast.Suffix(base=expr, name=name, call_args=call_args)
                continue
            if self.match("@"):
                expr = ast.Delegate(base=expr)
                continue
            if self.match("["):
                index = self.parse_expression()
                self.expect("]")
                expr = ast.Index(base=expr, index=index)
                continue
            break
        return expr

    def parse_call_args(self) -> list[Any]:
        self.expect("(")
        args: list[Any] = []
        if not self.check(")"):
            args.append(self.parse_expression())
            while self.match(","):
                args.append(self.parse_expression())
        self.expect(")")
        return args

    def parse_primary(self) -> Any:
        tok = self.current()
        line, col = tok.line, tok.column

        if self.match("NUMBER"):
            return ast.Number(value=float(tok.value), line=line, column=col)

        if self.match("STRING"):
            return ast.String(value=tok.value, line=line, column=col)

        if self.match("true"):
            return ast.Boolean(value=True, line=line, column=col)

        if self.match("false"):
            return ast.Boolean(value=False, line=line, column=col)

        # lexicon / list / queue literals or other keyword-named calls
        if self.check("lexicon") or self.check("list") or self.check("queue"):
            name = self.current().value
            kind = self.current().kind
            self.pos += 1
            if self.check("("):
                args = self.parse_call_args()
                if kind == "lexicon":
                    pairs: list[tuple[Any, Any]] = []
                    if len(args) % 2 != 0:
                        raise ParseError("lexicon needs key/value pairs", self.filename, line, col)
                    for i in range(0, len(args), 2):
                        pairs.append((args[i], args[i + 1]))
                    return ast.LexiconLiteral(pairs=pairs, line=line, column=col)
                if kind == "list":
                    return ast.ListLiteral(items=args, line=line, column=col)
                return ast.QueueLiteral(items=args, line=line, column=col)
            return ast.Name(value=name, line=line, column=col)

        # abort used as expression (on abort / bound var)
        if self.check("abort"):
            self.pos += 1
            if self.check("("):
                args = self.parse_call_args()
                return ast.Call(name="abort", args=args, line=line, column=col)
            return ast.Name(value="abort", line=line, column=col)

        if self.match("NAME"):
            name = tok.value
            if self.check("("):
                args = self.parse_call_args()
                return ast.Call(name=name, args=args, line=line, column=col)
            return ast.Name(value=name, line=line, column=col)

        if self.match("("):
            expr = self.parse_expression()
            self.expect(")")
            return expr

        raise ParseError(
            f"unexpected token {tok.kind} ({tok.value!r})",
            self.filename,
            line,
            col,
        )


def parse_script(source: str, filename: str = "<string>") -> ast.Script:
    tokens = tokenize(source, filename)
    parser = Parser(tokens, filename)
    script = parser.parse_script()
    if not parser.check("EOF"):
        cur = parser.current()
        raise ParseError(f"trailing token {cur.kind}", filename, cur.line, cur.column)
    return script
