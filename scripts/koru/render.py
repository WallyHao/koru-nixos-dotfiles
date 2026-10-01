"""Width-aware presentation only; operations live in the shell scripts."""

import os
import re
import shutil
import sys
import unicodedata

try:
    terminal_width = os.get_terminal_size(sys.stdout.fileno()).columns
except OSError:
    terminal_width = shutil.get_terminal_size((72, 24)).columns
width = max(12, min(80, terminal_width))
ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def clean(text):
    return "".join(c for c in ansi.sub("", text) if c >= " " and c != "\x7f")


def cells(char):
    if unicodedata.combining(char) or char in ("\u200d", "\ufe0f"):
        return 0
    return 2 if unicodedata.east_asian_width(char) in "WF" else 1


def clip(text, limit):
    text = clean(text)
    if sum(map(cells, text)) <= limit:
        return text
    result, used = "", 0
    for char in text:
        used += cells(char)
        if used > limit - 3:
            break
        result += char
    return result + "..."


def color(role):
    if not sys.stdout.isatty() or "NO_COLOR" in os.environ or os.getenv("TERM") == "dumb":
        return "", ""
    value = os.getenv("KORU_COLOR_" + role.upper(), "").lstrip("#")
    if not re.fullmatch(r"[0-9a-fA-F]{6}", value):
        return "", ""
    rgb = [int(value[i:i + 2], 16) for i in (0, 2, 4)]
    return "\033[38;2;%d;%d;%dm" % tuple(rgb), "\033[0m"


def emit(role, text):
    start, end = color(role)
    print(start + text + end, flush=True)


mode = sys.argv[1]
if mode == "line":
    emit(sys.argv[2], clip(sys.argv[3], width))
elif mode == "field":
    label, value = sys.argv[2:4]
    if width >= 44:
        start, end = color("label")
        other, reset = color("value")
        print(f"  {start}{label:<12}{end} {other}{clip(value, width - 15)}{reset}")
    else:
        emit("label", clip("  " + label, width))
        emit("value", clip("    " + value, width))
elif mode == "logs":
    for line in sys.stdin:
        text = clean(line.rstrip())
        # Wrap before applying ANSI colors, including long store paths.
        while sum(map(cells, text)) > width - 2:
            used, cut = 0, 0
            for char in text:
                if used + cells(char) > width - 2:
                    break
                used += cells(char)
                cut += 1
            split = text.rfind(" ", 0, cut + 1)
            if split > cut // 2:
                cut = split
            emit("muted", "  " + text[:cut])
            text = text[cut:].lstrip()
        emit("muted", "  " + text)
