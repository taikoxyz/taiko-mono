#!/usr/bin/env python3
"""Check the HTML's exact Lean excerpts, complete public-property index and source line links.

This checks source snapshots in this package's accepted top-level declaration layout. English
explanations still require review; this is not a semantic translation checker or Lean parser.
"""
from collections import Counter
from html.parser import HTMLParser
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
STATEMENTS = 'DerivationStatements/Claims.lean'
PROOFS = 'DerivationProofs/Claims.lean'
PROPERTIES = 'DerivationProofs/Properties.lean'
SOURCES = {STATEMENTS, PROOFS, PROPERTIES}
DECLARATION = re.compile(r'(?m)^(def|structure|theorem) ([A-Za-z_][A-Za-z_0-9]*)\b')
NEXT_COMMAND = re.compile(r'(?m)^(?:/--|/-!|--|end\b|namespace\b|open\b|variable\b|def\b|structure\b|theorem\b)')


def declarations(source):
    """Return kind, full declaration and one-based line for column-zero declarations."""
    result = {}
    for match in DECLARATION.finditer(source):
        start = source.find('\n', match.start())
        following = NEXT_COMMAND.search(source, start + 1) if start >= 0 else None
        block = source[match.start():following.start() if following else None].rstrip()
        result[match.group(2)] = (match.group(1), block, source[:match.start()].count('\n') + 1)
    return result


def theorem_signature(block):
    """Find the outer proof assignment, preserving record updates/defaults inside the type."""
    stack = []
    closing = {'(': ')', '[': ']', '{': '}', '⦃': '⦄', '⟨': '⟩'}
    i = 0
    while i < len(block):
        if block.startswith('--', i):
            end = block.find('\n', i)
            i = len(block) if end < 0 else end + 1
        elif block.startswith('/-', i):
            depth = 1
            i += 2
            while depth and i < len(block):
                if block.startswith('/-', i):
                    depth += 1
                    i += 2
                elif block.startswith('-/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            if depth:
                raise ValueError('unterminated Lean comment')
        elif block[i] == '"':
            i += 1
            while i < len(block) and block[i] != '"':
                i += 2 if block[i] == '\\' else 1
            if i >= len(block):
                raise ValueError('unterminated Lean string')
            i += 1
        elif not stack and block.startswith(':=', i):
            return block[:i].rstrip()
        elif block[i] in closing:
            stack.append(closing[block[i]])
            i += 1
        elif block[i] in closing.values():
            if not stack or stack.pop() != block[i]:
                raise ValueError('unbalanced Lean signature delimiters')
            i += 1
        else:
            i += 1
    raise ValueError('missing outer theorem proof assignment')


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.snippets = []
        self.links = []
        self.code = None
        self.link = None
        self.lemma = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'details' and attrs.get('id', '').startswith('lemma-'):
            self.lemma = attrs['id'][6:]
        if tag == 'code' and 'data-source' in attrs:
            self.code = (attrs, [])
        if tag == 'a':
            self.link = (attrs.get('href', ''), self.lemma, [])

    def handle_data(self, text):
        if self.code is not None:
            self.code[1].append(text)
        if self.link is not None:
            self.link[2].append(text)

    def handle_endtag(self, tag):
        if tag == 'code' and self.code is not None:
            attrs, parts = self.code
            self.snippets.append((attrs, ''.join(parts)))
            self.code = None
        if tag == 'a' and self.link is not None:
            href, lemma, parts = self.link
            self.links.append((href, lemma, ''.join(parts)))
            self.link = None
        if tag == 'details':
            self.lemma = None


def check(root=ROOT):
    errors = []
    try:
        page = Page()
        page.feed((root / 'STATEMENTS.html').read_text())
        source = {path: declarations((root / path).read_text()) for path in SOURCES}
        claims = json.loads((root / 'spec-coverage.json').read_text())['claims']
        required = {(STATEMENTS, name) for name in source[STATEMENTS]}
        required |= {(PROPERTIES, name) for name in source[PROPERTIES]}
        required |= {(PROOFS, claim['theorem'].rsplit('.', 1)[1]) for claim in claims.values()}
        seen = Counter()
        for attrs, actual in page.snippets:
            path, name = attrs['data-source'], attrs.get('data-declaration', '')
            seen[path, name] += 1
            if path not in source or name not in source[path]:
                errors.append(f'HTML unknown source declaration: {path}:{name}')
                continue
            kind, expected, _ = source[path][name]
            signature = attrs.get('data-signature') == 'true'
            if (kind == 'theorem') != signature:
                errors.append(f'HTML declaration/signature mode mismatch: {name}')
            if signature:
                expected = theorem_signature(expected)
            if actual != expected:
                errors.append(f'HTML stale Lean excerpt: {path}:{name}')
        for key in required:
            if seen[key] != 1:
                errors.append(f'HTML requires exactly one excerpt: {key[0]}:{key[1]} (got {seen[key]})')
        for key in seen.keys() - required:
            errors.append(f'HTML unindexed excerpt: {key[0]}:{key[1]}')
        linked = Counter()
        for href, lemma, label in page.links:
            if href.startswith(PROPERTIES + '#L'):
                if lemma not in source[PROPERTIES]:
                    errors.append(f'HTML unknown property link: {href}')
                    continue
                linked[lemma] += 1
                line = source[PROPERTIES][lemma][2]
                if href != f'{PROPERTIES}#L{line}' or label != f'{PROPERTIES}:{line}':
                    errors.append(f'HTML stale theorem line link: {lemma}')
        for name in source[PROPERTIES]:
            if linked[name] != 1:
                errors.append(f'HTML requires exactly one theorem line link: {name}')
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f'HTML check failed: {exc}')
    return errors


if __name__ == '__main__':
    failures = check()
    print('\n'.join(failures) if failures else 'HTML Lean excerpts, property index and line links: OK')
    raise SystemExit(bool(failures))
