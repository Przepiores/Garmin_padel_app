#!/usr/bin/env bash
# SessionStart: w chmurze zapamiętuje punkt startu sesji (dla hooka Stop),
# lokalnie (laptop) przypomina o otwartych testach na sprzęcie.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

QUEUE="docs/TESTY_NA_SPRZECIE.md"
BASE_FILE=".claude/.session_base"

if [ "$CLAUDE_CODE_REMOTE" = "true" ]; then
  git rev-parse HEAD > "$BASE_FILE" 2>/dev/null
  exit 0
fi

[ -f "$QUEUE" ] || exit 0
# Tylko pozycje pod nagłówkiem "## Kolejka" (pomija przykład formatu).
open_items=$(awk '/^## Kolejka/{q=1; next} /^## /{q=0} q && /^- \[ \] /' "$QUEUE")
[ -n "$open_items" ] || exit 0
count=$(printf '%s\n' "$open_items" | wc -l | tr -d ' ')

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' | awk '{printf "%s\\n", $0}'
}

msg="Czeka $count test(ów) na sprzęcie (zegarek/symulator) z sesji zdalnych:
$open_items
Szczegóły: $QUEUE. Po teście zaznacz [x] i dopisz wynik."
ctx="W pliku $QUEUE są otwarte zadania wymagające testu na zegarku lub w symulatorze Connect IQ. Na początku rozmowy krótko przypomnij o nich użytkownikowi i zaproponuj pomoc w ich przeprowadzeniu."

printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
  "$(json_escape "$msg")" "$(json_escape "$ctx")"
