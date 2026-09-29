# Globalne przypomnienia o testach na sprzęcie

Hook Claude Code działający w **każdym projekcie**. W sesji zdalnej (telefon,
chmura), gdy Claude zmienił pliki, których nie da się sprawdzić bez sprzętu,
nie pozwala zakończyć tury, dopóki nie założy:

1. **GitHub Issue** z etykietą `needs-hardware-test` (kroki testu, gdzie, czego oczekiwać),
2. **wydarzenia w Google Calendar** (domyślnie jutro 18:00, z linkiem do issue).

Na laptopie hook `SessionStart` prosi Claude'a o sprawdzenie otwartych issue
z tą etykietą i przypomnienie na początku rozmowy.

## Instalacja

- **Laptop:** `bash tools/claude-hw-reminder/install.sh`
  (zapisuje `~/.claude/hw-reminder/` i dopisuje hooki do `~/.claude/settings.json`).
- **Chmura, wszystkie repo:** wklej całą zawartość `install.sh` do
  *Setup script* środowiska (menu środowiska w pasku tytułu sesji → Edit).
  Kontener zaczyna od zera, więc hooki z laptopa tam nie dotrą.
- Wymagane w chmurze: konektor Google Calendar i dostęp GitHub do repo.

## Które pliki liczą się jako "sprzętowe"

Domyślnie: `*.mc`, `monkey.jungle`, `*.ino`, `platformio.ini`. Dodatkowe wzorce:
plik `.claude/hardware-paths` w repo (regex na linię, np. `^app/`) albo
zmienna `HW_PATTERNS` (oddzielone `;`).

## Zmienne

`HW_TODO_REPO` (wspólne repo na issue, np. `user/hardware-todo`),
`HW_REMINDER_TIME` (np. `18:00`), `HW_REMINDER_TZ` (`Europe/Warsaw`),
`HW_REMINDER_DISABLE=1` (wyłącza).

Hook nie ponawia przypomnienia dla tej samej zmiany w jednej sesji; nowa
zmiana w plikach sprzętowych wywoła je ponownie.
