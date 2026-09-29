# CLAUDE.md

Aplikacja Connect IQ (Monkey C) na Garmin Epix Pro Gen 2, która rozpoznaje
uderzenia w padlu z akcelerometru i żyroskopu. Obecnie etap spike'a: aplikacja
testowa **Padel Probe** w `app/` i parser FIT w `tools/`. Wymagania:
`docs/SPECYFIKACJA.md`, plan testu na korcie: `docs/PLAN_TESTU.md`.

## Współpraca

- Autor pracuje na **Windowsie** (VS Code + rozszerzenie Monkey C, Connect IQ
  SDK, Python 3.11+) i testuje na zegarku. Claude pisze kod i tłumaczy decyzje.
- Rozmowa, dokumentacja w `docs/` i docstringi w `tools/` są **po polsku**.
  Komentarze w kodzie Monkey C są po angielsku.
- Instrukcje dla autora podawaj z komendami PowerShell/Windows.

## Struktura

- `app/`: projekt Connect IQ (`monkey.jungle`, `manifest.xml`, produkty
  `epix2pro42mm/47mm/51mm`, minApiLevel 4.1.6).
  - `source/Config.mc`: progi detekcji i układ porcji FIT.
  - `source/Labels.mc`: etykiety uderzeń.
  - `resources/strings/` (ang.) i `resources-pol/strings/` (pol.): każdy
    nowy tekst UI dodaj w **obu** plikach.
- `tools/fit_probe.py`: analiza pliku FIT z zegarka, eksport wycinków do CSV
  i opcjonalny wykres (`python fit_probe.py AKTYWNOSC.fit [--out DIR] [--plot]`).
- `tools/tests/`: testy parsera (unittest).

## Niezmienniki, które łatwo zepsuć

- `LABELS`, `HEADER_VALUES` i `CHUNK_VALUES` w `tools/fit_probe.py` muszą się
  zgadzać z `app/source/Labels.mc` i `app/source/Config.mc`. Zmieniaj je razem.
- Wiadomość FIT z aplikacji Connect IQ ma limit 256 B, więc układ porcji danych
  w `Config.mc` musi się w nim mieścić.
- Pola deweloperskie FIT są zdefiniowane w `app/resources/fit/fit_contributions.xml`.

## Budowanie i testy

- **Monkey C nie da się skompilować w sesji w chmurze** (brak SDK i dostępu do
  serwerów Garmina). Po zmianach w `app/` przejrzyj diff szczególnie starannie
  i poproś autora o kompilację (`Ctrl+F5` w VS Code) i wklejenie błędów.
- Testy parsera, uruchamiane z katalogu `tools/`:

  ```
  pip install -r requirements.txt
  python -m unittest discover tests
  ```

## Bezpieczeństwo

- Nigdy nie commituj klucza deweloperskiego (`*.der`, `*.pem`, `developer_key*`)
  ani `.env`. Wszystkie są w `.gitignore`.
- Pliki FIT z kortu to dane autora. Nie wysyłaj ich do zewnętrznych usług bez pytania.

## Skille projektu

- `generate-image` (`.claude/skills/generate-image/`): generowanie grafik,
  np. ikony launchera i grafik do sklepu, przez OpenRouter. Wymaga
  `OPENROUTER_API_KEY` w zmiennej środowiskowej albo w `.env`. Każde wywołanie
  jest płatne.
