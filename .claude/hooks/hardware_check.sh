#!/usr/bin/env bash
# Stop (tylko sesje zdalne): jeśli w tej sesji zmieniono kod aplikacji
# zegarkowej, a nie dopisano wpisu do kolejki testów sprzętowych, każe
# Claude'owi go dodać, zanim zakończy turę.
[ "$CLAUDE_CODE_REMOTE" = "true" ] || exit 0

input=$(cat)
# Drugi przebieg po naszym bloku: nie zapętlaj.
printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
QUEUE="docs/TESTY_NA_SPRZECIE.md"
base=$(cat .claude/.session_base 2>/dev/null)
git cat-file -e "${base}^{commit}" 2>/dev/null || base=HEAD

changed=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u)

# Kod, którego nie da się sprawdzić w kontenerze (brak SDK Connect IQ i zegarka).
printf '%s\n' "$changed" | grep -Eq '^app/' || exit 0
# Kolejka już zaktualizowana w tej sesji: w porządku.
printf '%s\n' "$changed" | grep -Fxq "$QUEUE" && exit 0

cat <<JSON
{"decision":"block","reason":"W tej sesji zmieniono pliki w app/ (Monkey C / zasoby / manifest), których nie da się zbudować ani przetestować w chmurze. Dopisz na górze listy w $QUEUE wpis w formacie opisanym w tym pliku: data, gałąź, co zmieniono, co dokładnie sprawdzić na zegarku lub w symulatorze i czego się spodziewać. Zacommituj i wypchnij go razem ze zmianą, a w odpowiedzi dla użytkownika dodaj na końcu linię '🔧 Wymaga testu na sprzęcie: …'. Jeśli zmiana naprawdę nie wymaga testu (np. tylko komentarz), dopisz wpis od razu zaznaczony jako [x] z uzasadnieniem."}
JSON
