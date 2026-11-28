"""Strict data-only parser for the selected TLC pretty-print value grammar.

No eval, literal_eval, code loading, subprocess, imports from the target, or
permissive duplicate-key normalization. All parsed values remain type tagged.
This file has not been executed or tested; root inspection/GO is required.
"""
from __future__ import annotations

from dataclasses import dataclass
import json
import re


class Refusal(ValueError):
    pass


@dataclass(frozen=True)
class Value:
    kind: str
    data: object


TOKEN = re.compile(
    r'(?P<space>\s+)|(?P<string>"(?:[^"\\\x00-\x1f]|\\["\\/bfnrt]|\\u[0-9a-fA-F]{4})*")'
    r'|(?P<int>-?[0-9]+)|(?P<op>\|->|:>|@@|<<|>>|\\in|\.\.|[{}\[\](),])'
    r'|(?P<id>[A-Za-z_][A-Za-z_0-9]*)'
)
MAX_CHARS = 64 * 1024 * 1024
MAX_TOKENS = 2_000_000
MAX_DEPTH = 128
MAX_ITEMS = 100_000


def unique(items, label):
    rows = tuple(items)
    if len(rows) > MAX_ITEMS:
        raise Refusal(f"too many {label}")
    if len(set(rows)) != len(rows):
        raise Refusal(f"duplicate {label}")
    return rows


class Parser:
    def __init__(self, text):
        if not isinstance(text, str) or len(text) > MAX_CHARS:
            raise Refusal("value text exceeds input bound")
        self.tokens = []
        offset = 0
        while offset < len(text):
            match = TOKEN.match(text, offset)
            if match is None:
                raise Refusal(f"unsupported TLC value syntax at offset {offset}")
            if match.lastgroup != "space":
                self.tokens.append((match.lastgroup, match.group()))
                if len(self.tokens) > MAX_TOKENS:
                    raise Refusal("value token bound exceeded")
            offset = match.end()
        self.index = 0

    def peek(self, offset=0):
        at = self.index + offset
        return self.tokens[at][1] if at < len(self.tokens) else None

    def take(self, wanted=None):
        if self.index >= len(self.tokens):
            raise Refusal("unexpected end of TLC value")
        kind, text = self.tokens[self.index]
        if wanted is not None and text != wanted:
            raise Refusal(f"expected {wanted}, got {text}")
        self.index += 1
        return kind, text

    def parse(self, depth=0):
        if depth > MAX_DEPTH:
            raise Refusal("TLC value nesting bound exceeded")
        kind, token = self.take()
        if kind == "string":
            return Value("string", json.loads(token))
        if kind == "int":
            low = int(token)
            if self.peek() != "..":
                return Value("int", low)
            self.take("..")
            high_kind, high_text = self.take()
            if high_kind != "int":
                raise Refusal("integer interval has non-integer endpoint")
            high = int(high_text)
            if high - low + 1 > MAX_ITEMS:
                raise Refusal("integer interval exceeds item bound")
            return Value("set", tuple(sorted((Value("int", x) for x in range(low, high + 1)), key=canonical)))
        if kind == "id":
            if token in ("TRUE", "FALSE"):
                return Value("bool", token == "TRUE")
            return Value("model", token)
        if token in ("{", "<<"):
            close = "}" if token == "{" else ">>"
            values = []
            if self.peek() != close:
                while True:
                    values.append(self.parse(depth + 1))
                    if len(values) > MAX_ITEMS:
                        raise Refusal("collection bound exceeded")
                    if self.peek() != ",":
                        break
                    self.take(",")
            self.take(close)
            if token == "{":
                values = sorted(unique(values, "set element"), key=canonical)
            return Value("set" if token == "{" else "tuple", tuple(values))
        if token == "[":
            if self.peek() == "]":
                self.take("]")
                return Value("record", ())
            field_kind, field = self.take()
            if field_kind != "id":
                raise Refusal("record field must be a bare identifier")
            if self.peek() == "\\in":
                self.take("\\in")
                domain = self.parse(depth + 1)
                self.take("|->")
                value = self.parse(depth + 1)
                self.take("]")
                if domain.kind != "set":
                    raise Refusal("constant function has non-set domain")
                # This syntax is accepted only as a constant value function;
                # no expression or binder substitution is evaluated.
                if contains_model(value, field):
                    raise Refusal("nonconstant function expression is unsupported")
                return Value("function", tuple(sorted(((key, value) for key in domain.data),
                                                       key=lambda row: canonical(row[0]))))
            entries = []
            while True:
                self.take("|->")
                entries.append((field, self.parse(depth + 1)))
                if self.peek() != ",":
                    break
                self.take(",")
                field_kind, field = self.take()
                if field_kind != "id":
                    raise Refusal("record field must be an identifier")
            self.take("]")
            unique((key for key, _ in entries), "record field")
            return Value("record", tuple(sorted(entries)))
        if token == "(":
            entries = []
            while True:
                key = self.parse(depth + 1)
                self.take(":>")
                entries.append((key, self.parse(depth + 1)))
                if len(entries) > MAX_ITEMS:
                    raise Refusal("function bound exceeded")
                if self.peek() != "@@":
                    break
                self.take("@@")
            self.take(")")
            unique((key for key, _ in entries), "function key")
            return Value("function", tuple(sorted(entries, key=lambda row: canonical(row[0]))))
        raise Refusal(f"unsupported TLC value token {token}")

    def complete(self):
        value = self.parse()
        if self.index != len(self.tokens):
            raise Refusal("trailing data after TLC value")
        return value


def canonical(value):
    return repr(value)


def contains_model(value, name):
    if value.kind == "model":
        return value.data == name
    if value.kind in ("set", "tuple"):
        return any(contains_model(item, name) for item in value.data)
    if value.kind in ("record", "function"):
        return any((isinstance(key, Value) and contains_model(key, name))
                   or contains_model(item, name) for key, item in value.data)
    return False


def parse_value(text):
    return Parser(text).complete()


STATE = re.compile(r"^State ([1-9][0-9]*): (.+)$")
ASSIGN = re.compile(r"^/\\ ([A-Za-z_][A-Za-z_0-9]*) =\s*(.*)$")
STATS = re.compile(r"^\s*([0-9,]+) states generated, ([0-9,]+) distinct states found, ([0-9,]+) states left on queue\.$")
VIOLATION = re.compile(r"^Error: Invariant ([A-Za-z_][A-Za-z_0-9]*) is violated\.$")


@dataclass(frozen=True)
class TraceState:
    number: int
    action: str
    values: dict


@dataclass(frozen=True)
class ParsedLog:
    states: tuple
    invariant: str | None
    counts: dict
    complete: bool


def parse_log(text, expected):
    if not isinstance(text, str) or len(text) > MAX_CHARS or "\ufffd" in text:
        raise Refusal("oversized or lossy TLC log")
    states, stats, violations, other_errors = [], [], [], []
    current_number = None
    current_action = None
    variables = {}
    variable = None
    chunks = []
    after_summary = False
    finished = 0

    def finish_variable():
        nonlocal variable, chunks
        if variable is not None:
            if variable in variables:
                raise Refusal("duplicate variable in state")
            variables[variable] = parse_value("\n".join(chunks))
            variable, chunks = None, []

    def finish_state():
        nonlocal current_number, current_action, variables
        finish_variable()
        if current_number is not None:
            if not variables or current_number != len(states) + 1:
                raise Refusal("empty, missing or duplicate TLC state")
            if states and set(variables) != set(states[0].values):
                raise Refusal("state variable domain changed or is missing")
            states.append(TraceState(current_number, current_action, variables))
            if len(states) > 10000:
                raise Refusal("state trace bound exceeded")
            current_number, current_action, variables = None, None, {}

    lines = text.splitlines()
    for line in lines:
        match = STATE.fullmatch(line)
        if match:
            if after_summary:
                raise Refusal("state after final summary")
            finish_state()
            current_number, current_action = int(match[1]), match[2]
            continue
        match = STATS.fullmatch(line)
        if match:
            finish_state()
            after_summary = True
            stats.append(dict(zip(("generated", "distinct", "queued"),
                                  (int(x.replace(",", "")) for x in match.groups()))))
            continue
        match = VIOLATION.fullmatch(line)
        if match:
            if current_number is not None:
                raise Refusal("violation interleaved in state")
            violations.append(match[1])
            continue
        if line.startswith("Error:") and line != "Error: The behavior up to this point is:":
            other_errors.append(line)
        if line.startswith("Finished in "):
            finished += 1
        if current_number is not None:
            match = ASSIGN.fullmatch(line)
            if match:
                finish_variable()
                variable, chunks = match[1], [match[2]]
            elif variable is not None:
                chunks.append(line)
            elif line.strip():
                raise Refusal("non-variable data inside TLC state")
    finish_state()
    if other_errors or len(stats) != 1 or finished != 1:
        raise Refusal("TLC error or missing/duplicate final summary")
    counts = stats[0]
    if not (counts["generated"] >= counts["distinct"] > 0):
        raise Refusal("invalid TLC state statistics")
    complete = "Model checking completed. No error has been found." in lines
    if expected == "PASS":
        if violations or not complete or counts["queued"] != 0 or states:
            raise Refusal("safety run did not completely exhaust its graph")
        invariant = None
    else:
        if violations != [expected] or complete or len(states) < 2:
            raise Refusal("missing/wrong invariant or summary-only witness")
        if counts["distinct"] < len(states):
            raise Refusal("trace exceeds reported distinct state count")
        invariant = expected
    return ParsedLog(tuple(states), invariant, counts, complete)


def strict_json(text):
    def pairs(rows):
        unique((key for key, _ in rows), "JSON key")
        return dict(rows)
    def reject_constant(_):
        raise Refusal("nonfinite JSON number")
    return json.loads(text, object_pairs_hook=pairs, parse_constant=reject_constant)


def record(value, fields=None):
    if value.kind != "record":
        raise Refusal("record expected")
    result = dict(value.data)
    if fields is not None and set(result) != set(fields):
        raise Refusal(f"record field domain differs: {sorted(result)}")
    return result


def integer(value, low=None, high=None):
    if value.kind != "int" or (low is not None and value.data < low) or (high is not None and value.data > high):
        raise Refusal("integer type or bound mismatch")
    return value.data


def string(value):
    if value.kind != "string":
        raise Refusal("string expected")
    return value.data


def boolean(value):
    if value.kind != "bool":
        raise Refusal("boolean expected")
    return value.data


def string_set(value):
    if value.kind != "set":
        raise Refusal("set expected")
    return frozenset(string(item) for item in value.data)


def integer_map(value, keys):
    if value.kind != "function":
        raise Refusal("explicit integer-key function expected")
    result = {integer(key): integer(item) for key, item in value.data}
    if set(result) != set(keys):
        raise Refusal("integer function domain differs")
    return result
