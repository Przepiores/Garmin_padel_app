#!/usr/bin/env bash
# Globalny hook Claude Code: przypomnienie o teście na sprzęcie.
# Samodzielny: uruchom na laptopie ALBO wklej w "Setup script" środowiska
# chmurowego (wtedy działa w każdej sesji zdalnej, w każdym repo).
# Zapisuje ~/.claude/hw-reminder/hw_reminder.py i dopisuje hooki do
# ~/.claude/settings.json (bez ruszania innych ustawień). Idempotentny.
set -e
DIR="$HOME/.claude/hw-reminder"
mkdir -p "$DIR/state"

cat > "$DIR/hw_reminder.py" <<'PY'
#!/usr/bin/env python3
"""SessionStart / Stop hook: przypomnienia o testach na sprzęcie.

Zdalnie (CLAUDE_CODE_REMOTE=true): Stop blokuje zakończenie tury, gdy zmieniono
pliki, których nie da się sprawdzić w chmurze, i każe założyć GitHub Issue oraz
wydarzenie w Google Calendar. Lokalnie: SessionStart przypomina o otwartych issue.

Konfiguracja (opcjonalna):
  .claude/hardware-paths   w repo: regexy ścieżek (jeden na linię, # = komentarz)
  HW_PATTERNS              regexy oddzielone średnikiem (dopisywane)
  HW_TODO_REPO             owner/repo na issue, jeśli ma być jedno wspólne
  HW_REMINDER_TIME         godzina wydarzenia, domyślnie 18:00
  HW_REMINDER_TZ           strefa, domyślnie Europe/Warsaw
  HW_REMINDER_DISABLE=1    wyłącza hook
"""
import hashlib, json, os, re, subprocess, sys

STATE = os.path.expanduser("~/.claude/hw-reminder/state")
LABEL = "needs-hardware-test"
DEFAULTS = [r"\.mc$", r"(^|/)monkey\.jungle$", r"\.ino$", r"(^|/)platformio\.ini$"]


def git(*args, cwd):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def patterns(root):
    pats = list(DEFAULTS)
    try:
        with open(os.path.join(root, ".claude", "hardware-paths")) as f:
            pats += [l.strip() for l in f if l.strip() and not l.startswith("#")]
    except OSError:
        pass
    pats += [p for p in os.environ.get("HW_PATTERNS", "").split(";") if p]
    return [re.compile(p) for p in pats]


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))


def start(data, cwd):
    sid = data.get("session_id", "x")
    if os.environ.get("CLAUDE_CODE_REMOTE") == "true":
        head = git("rev-parse", "HEAD", cwd=cwd)
        if head:
            with open(os.path.join(STATE, sid + ".base"), "w") as f:
                f.write(head)
        return
    central = os.environ.get("HW_TODO_REPO", "")
    emit({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext":
        f"Jeśli masz dostęp do GitHuba (narzędzia MCP albo gh), sprawdź otwarte issue "
        f"z etykietą {LABEL} w bieżącym repozytorium"
        + (f" oraz w {central}" if central else "")
        + ". Jeśli są, na początku odpowiedzi krótko przypomnij użytkownikowi o "
        "testach na sprzęcie (tytuły + linki) i zaproponuj pomoc. Jeśli nie ma, nic nie wspominaj."}})


def stop(data, cwd):
    if os.environ.get("CLAUDE_CODE_REMOTE") != "true" or data.get("stop_hook_active"):
        return
    root = git("rev-parse", "--show-toplevel", cwd=cwd)
    if not root:
        return
    sid = data.get("session_id", "x")
    base = ""
    try:
        base = open(os.path.join(STATE, sid + ".base")).read().strip()
    except OSError:
        pass
    if not base or not git("cat-file", "-t", base, cwd=root):
        base = git("merge-base", "HEAD", "origin/HEAD", cwd=root) or "HEAD"
    names = set(git("diff", "--name-only", base, cwd=root).splitlines())
    names |= set(git("ls-files", "--others", "--exclude-standard", cwd=root).splitlines())
    pats = patterns(root)
    files = sorted(n for n in names if any(p.search(n) for p in pats))
    if not files:
        return
    digest = hashlib.sha1((",".join(files) + git("diff", base, "--", *files, cwd=root)).encode()).hexdigest()
    marker = os.path.join(STATE, sid + ".done")
    try:
        if open(marker).read() == digest:
            return
    except OSError:
        pass
    with open(marker, "w") as f:
        f.write(digest)

    repo = os.path.basename(root)
    origin = git("remote", "get-url", "origin", cwd=root)
    branch = git("rev-parse", "--abbrev-ref", "HEAD", cwd=root)
    central = os.environ.get("HW_TODO_REPO", "")
    tz = os.environ.get("HW_REMINDER_TZ", "Europe/Warsaw")
    at = os.environ.get("HW_REMINDER_TIME", "18:00")
    reason = (
        "W tej sesji zmieniono pliki, których nie da się zbudować ani przetestować w chmurze "
        f"(sprzęt / symulator): {', '.join(files[:15])}"
        + (" …" if len(files) > 15 else "") + f". Repo: {origin or repo}, gałąź: {branch}.\n"
        "Zanim skończysz, zrób dwie rzeczy:\n"
        f"1. Załóż GitHub Issue w {central or 'tym repozytorium'} (narzędzia mcp__github__*) z etykietą "
        f"`{LABEL}` i tytułem `[HW-test] {repo}: <krótki opis zmiany>`. W treści: co zmieniono, "
        "gdzie testować (symulator / zegarek / urządzenie), konkretne kroki i oczekiwany wynik, "
        "link do gałęzi lub PR.\n"
        f"2. Dodaj wydarzenie w Google Calendar (narzędzia mcp__Google_Calendar__*), jutro o {at} "
        f"({tz}), 30 min, tytuł `🔧 Test na sprzęcie: {repo}`, w opisie link do issue; przypomnienie "
        "popup 10 min przed.\n"
        "Jeśli któreś narzędzie jest niedostępne, zrób drugie i napisz o tym. Jeśli zmiana naprawdę "
        "nie wymaga testu (np. sam komentarz), pomiń oba kroki i napisz dlaczego. "
        "Na końcu odpowiedzi dodaj linię `🔧 Wymaga testu na sprzęcie: <link do issue>`."
    )
    emit({"decision": "block", "reason": reason})


def main():
    if os.environ.get("HW_REMINDER_DISABLE") == "1" or len(sys.argv) < 2:
        return
    try:
        data = json.load(sys.stdin)
    except ValueError:
        data = {}
    os.makedirs(STATE, exist_ok=True)
    cwd = data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    {"start": start, "stop": stop}[sys.argv[1]](data, cwd)


main()
PY
chmod +x "$DIR/hw_reminder.py"

python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    cfg = json.load(open(p))
except (OSError, ValueError):
    cfg = {}
hooks = cfg.setdefault("hooks", {})
for event, arg in (("SessionStart", "start"), ("Stop", "stop")):
    groups = [g for g in hooks.get(event, [])
              if not any("hw_reminder.py" in h.get("command", "") for h in g.get("hooks", []))]
    groups.append({"hooks": [{"type": "command",
                              "command": f'python3 "$HOME/.claude/hw-reminder/hw_reminder.py" {arg}'}]})
    hooks[event] = groups
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(cfg, open(p, "w"), indent=2, ensure_ascii=False)
PY
echo "hw-reminder zainstalowany w $DIR"
