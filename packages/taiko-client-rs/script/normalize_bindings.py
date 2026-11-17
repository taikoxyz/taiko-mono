#!/usr/bin/env python3
"""Normalize expanded Alloy bindings for the workspace Rust toolchain."""

from pathlib import Path
import re
import sys


_DERIVED_IMPL = re.compile(
    r"^[ \t]*#\[automatically_derived\]\n"
    r"(?P<item>(?:[ \t]*#\[[^\n]*\]\n)*[ \t]*impl\b[^{}]*\{)",
    re.MULTILINE,
)


def normalize_source(source: str) -> str:
    """Keep automatically_derived only on trait impls, as Rust requires."""
    def normalize_impl(match: re.Match[str]) -> str:
        depth = 0
        for token in re.findall(r"<|>|[A-Za-z_][A-Za-z_0-9]*", match["item"]):
            if token == "<":
                depth += 1
            elif token == ">":
                depth = max(0, depth - 1)
            elif depth == 0:
                if token == "for":
                    return match[0]
                if token == "where":
                    break
        return match["item"]

    return _DERIVED_IMPL.sub(normalize_impl, source)


def normalize_bindings(bindings: Path) -> None:
    """Apply reproducible toolchain compatibility fixes to a generated crate."""
    for path in sorted((bindings / "src").glob("*.rs")):
        source = normalize_source(path.read_text())
        # Expanded Alloy helpers can be unused; a source-level allowance survives
        # CI's -D warnings, unlike Cargo.toml's command-line lint defaults.
        attribute = "#![allow(dead_code)]\n"
        if path.name == "lib.rs" and attribute not in source:
            source = attribute + source
        path.write_text(source)


if __name__ == "__main__":
    normalize_bindings(Path(sys.argv[1]))
