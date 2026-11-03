#!/usr/bin/env python3
"""Derive Claude Code CLI model id aliases from the installed native binary."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Minimum lengths after "claude-{tier}-" to avoid junk like "claude-haiku-".
_MODEL_RE = re.compile(
    r"^claude-(?P<tier>opus|sonnet|haiku)-(?P<rest>[0-9][0-9A-Za-z@._-]*)$"
)


def _version_tuple(rest: str) -> tuple[int, ...]:
    parts: list[int] = []
    for segment in rest.replace("@", "-").split("-"):
        if segment.isdigit():
            parts.append(int(segment))
        elif segment and segment[0].isdigit():
            head = re.match(r"^(\d+)", segment)
            if head:
                parts.append(int(head.group(1)))
    return tuple(parts)


def _is_modern_alias(model_id: str) -> bool:
    if "@" in model_id or "[" in model_id or "(" in model_id:
        return False
    parts = model_id.split("-")
    if len(parts) < 3 or not parts[2][:1].isdigit():
        return False
    tail = parts[-1]
    # Dated snapshot ids (…-20251001) are not the CLI's default alias ids.
    if tail.isdigit() and len(tail) == 8:
        return False
    return True


def _pick_latest(candidates: set[str]) -> str:
    modern = {c for c in candidates if _is_modern_alias(c)}
    pool = modern or candidates

    def sort_key(model_id: str) -> tuple:
        m = _MODEL_RE.match(model_id)
        if not m:
            return (0,)
        rest = m.group("rest")
        return (_version_tuple(rest), len(rest), model_id)

    return max(pool, key=sort_key)


def extract_model_ids(claude_binary: Path) -> dict[str, str]:
    blob = claude_binary.read_bytes()
    text = blob.decode("utf-8", errors="ignore")
    by_tier: dict[str, set[str]] = {"opus": set(), "sonnet": set(), "haiku": set()}
    for match in re.finditer(
        rb"claude-(?:opus|sonnet|haiku)-[0-9][0-9A-Za-z@._-]{0,64}",
        blob,
    ):
        token = match.group(0).decode("ascii", errors="ignore")
        m = _MODEL_RE.match(token)
        if not m:
            continue
        tier = m.group("tier")
        by_tier[tier].add(token)
    for token in text.split():
        m = _MODEL_RE.match(token.strip())
        if m:
            by_tier[m.group("tier")].add(token.strip())

    if not any(by_tier.values()):
        raise RuntimeError(
            f"no claude model ids found in {claude_binary}; is this the Claude Code CLI?"
        )

    resolved = {tier: _pick_latest(ids) for tier, ids in by_tier.items() if ids}
    for tier in ("opus", "sonnet", "haiku"):
        resolved.setdefault(tier, resolved.get("sonnet") or next(iter(resolved.values())))
    resolved["default"] = resolved["sonnet"]
    return resolved


def emit_shell(models: dict[str, str]) -> None:
    print(f"CLAUDE_OPUS_ALIAS={models['opus']}")
    print(f"CLAUDE_SONNET_ALIAS={models['sonnet']}")
    print(f"CLAUDE_HAIKU_ALIAS={models['haiku']}")
    print(f"CLAUDE_DEFAULT_MODEL={models['default']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("claude_binary", type=Path)
    parser.add_argument(
        "--shell",
        action="store_true",
        help="Print shell variable assignments (default)",
    )
    args = parser.parse_args()
    if not args.claude_binary.is_file():
        print(f"resolve-claude-model-aliases: not found: {args.claude_binary}", file=sys.stderr)
        return 1
    models = extract_model_ids(args.claude_binary)
    emit_shell(models)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
