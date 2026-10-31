#!/usr/bin/env python3
"""Reject @option annotations that sit inside a list literal.

The nix-settings-gui scanner binds a comment to the next assignment in the
same attribute set. It does not descend into a list of attribute sets, so an
annotation inside ``[ ... ]`` (including a ``lib.mkMerge`` argument) is dropped.
An attribute set wrapped by ``lib.mkIf`` outside a list is supported.
"""

from __future__ import annotations

import sys
from pathlib import Path


OPEN = {"[": "]", "{": "}", "(": ")"}
CLOSE = {value: key for key, value in OPEN.items()}


def comment_lines(text: str):
    """Yield (line_number, text, bracket_stack) for every comment."""
    index = 0
    line = 1
    length = len(text)
    stack: list[str] = []

    while index < length:
        char = text[index]

        if char == "#":
            start_line = line
            start = index + 1
            index = text.find("\n", start)
            if index == -1:
                index = length
            body = text[start:index]
            yield start_line, body, tuple(stack)
            continue

        if text.startswith("/*", index):
            start_line = line
            start = index + 2
            depth = 1
            index = start
            while index < length and depth:
                if text.startswith("/*", index):
                    depth += 1
                    index += 2
                elif text.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    if text[index] == "\n":
                        line += 1
                    index += 1
            body = text[start : index - 2]
            yield start_line, body, tuple(stack)
            continue

        if text.startswith("''", index):
            index += 2
            while index < length:
                if text.startswith("'''", index) or text.startswith("''$", index):
                    index += 3
                    continue
                if text.startswith("''", index):
                    index += 2
                    break
                if text[index] == "\n":
                    line += 1
                index += 1
            continue

        if char == '"':
            index += 1
            while index < length:
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == '"':
                    index += 1
                    break
                if text[index] == "\n":
                    line += 1
                index += 1
            continue

        if char in OPEN:
            stack.append(char)
            index += 1
            continue

        if char in CLOSE:
            if stack and stack[-1] == CLOSE[char]:
                stack.pop()
            index += 1
            continue

        if char == "\n":
            line += 1
        index += 1


def annotations_in_lists(text: str):
    for line, body, stack in comment_lines(text):
        for raw in body.splitlines():
            stripped = raw.strip()
            if stripped.startswith("@option") and "[" in stack:
                yield line


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parent.parent / "modules" / "patches"
    if not root.is_dir():
        print(f"annotations: not a directory: {root}", file=sys.stderr)
        return 2

    violations = 0
    files = sorted(root.glob("*.nix"))
    for path in files:
        text = path.read_text(encoding="utf-8")
        for line in annotations_in_lists(text):
            print(f"{path}:{line}: @option inside a list literal")
            violations += 1

    if violations:
        print(f"annotations: {violations} violation(s) in {len(files)} file(s)")
        return 1

    print(f"annotations: 0 violations in {len(files)} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
