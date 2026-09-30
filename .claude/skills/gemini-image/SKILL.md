---
name: gemini-image
description: "Generowanie i edycja obrazów przez Gemini API (Nano Banana) skryptem w Pythonie, bez przeglądarki. Użyj, gdy użytkownik prosi o wygenerowanie, narysowanie, stworzenie, przerobienie lub edycję obrazu, zdjęcia, grafiki, ilustracji, ikony, plakatu albo mockupu. Działa w Claude Code, w czacie claude.ai i w Coworku."
---

# Obrazy przez Gemini API

Jeden skrypt, standardowa biblioteka Pythona, bez `pip install`:
`scripts/gen_image.py` (ścieżka względem katalogu tego skilla).

## 1. Klucz API

Skrypt szuka klucza w tej kolejności:
1. zmienna `GEMINI_API_KEY` (albo `GOOGLE_API_KEY`),
2. plik `api_key` w katalogu skilla (jedna linia, obok tego `SKILL.md`),
3. `~/.config/gemini/api_key`.

Brak klucza → poproś o niego użytkownika i przekaż go przez zmienną środowiskową
w tym jednym wywołaniu (`GEMINI_API_KEY=... python ...`). Nie zapisuj klucza
do repozytorium, nie wklejaj go do odpowiedzi ani do plików, które wysyłasz.

## 2. Wywołanie

```bash
python3 <skill>/scripts/gen_image.py "<PROMPT>" -o <katalog>/<nazwa>.png
```

| Opcja | Znaczenie |
|---|---|
| `-m lite` / `flash` / `pro` | `gemini-3.1-flash-lite-image` (najtańszy, tylko 1K), `gemini-3.1-flash-image` (domyślny), `gemini-3-pro-image` (najlepsza jakość, tekst na grafikach) |
| `-a 16:9` | proporcje: `1:1 3:2 2:3 3:4 4:3 4:5 5:4 9:16 16:9 21:9` |
| `-s 2K` | rozdzielczość: `512 1K 2K 4K` (lite: tylko 1K) |
| `-i plik.png` | obraz wejściowy do edycji lub referencja; można podać do 14 razy |
| `--previous <id>` | kontynuacja poprzedniej generacji (poprawki bez ponownego wysyłania obrazu) |

Skrypt wypisuje JSON: `file`, `mime_type`, `bytes`, `interaction_id`, `seconds`, `text`.
Rozszerzenie pliku dopasowuje do typu, który faktycznie przyszedł (bywa JPEG).
**Zapamiętaj `interaction_id`**: przy kolejnej prośbie o poprawkę tego samego obrazu
podaj go w `--previous`, zamiast generować od zera.

Wybór modelu: domyślnie `flash`. `pro` przy tekście na grafice, infografikach i gdy
użytkownik chce najwyższej jakości. `lite` przy wielu szybkich szkicach.
Generacja trwa zwykle 10–60 s; nie ustawiaj krótszego timeoutu niż 180 s.

## 3. Gdzie zapisać i jak pokazać

- **Czat claude.ai / Cowork:** zapisz do `/mnt/user-data/outputs/`, obejrzyj plik
  (`Read`/podgląd obrazu), potem udostępnij go użytkownikowi (np. `present_files`
  lub `SendUserFile` z `display: "render"`, zależnie od tego, co jest dostępne).
- **Claude Code:** zapisz tam, gdzie prosi użytkownik; bez wskazania do
  `./generated/` albo katalogu scratchpad, obejrzyj plik narzędziem `Read`
  i podaj ścieżkę.

**Zawsze obejrzyj obraz przed pokazaniem.** Jeśli wyraźnie mija się z prośbą,
popraw prompt i wygeneruj ponownie (maks. 2 razy), zanim cokolwiek pokażesz.
Dla plików > 2 MB czytaj miniaturę (PIL, `thumbnail((1024, 1024))`, JPEG q80).

## 4. Prompty

Pisz prompt **po angielsku**, nawet gdy rozmowa jest po polsku. Krótkie życzenie
rozbuduj w konkret: temat, kadr i kąt, styl (foto / ilustracja / 3D / flat),
światło, obiektyw, tło, paleta, poziom detalu. Nie dopytuj o szczegóły: zrób
dobry prompt, pokaż wynik, poprawki przyjdą w następnej turze. Tekst, który ma
się pojawić na obrazie, podaj w cudzysłowie i dokładnie.

Przy edycji (`-i`) opisz tylko zmianę i dopisz, co ma zostać bez zmian
(`Keep everything else unchanged.`).

Nie odtwarzaj markowych logo, wordmarków ani konkretnych chronionych wzorów
produktów; opisz generyczny odpowiednik, dopisz `No brand logos or text anywhere`
i powiedz o tym użytkownikowi w jednym zdaniu. Nie generuj wizerunków realnych,
rozpoznawalnych osób w sytuacjach, które mogłyby wprowadzać w błąd.

## 5. Błędy

| Komunikat | Co zrobić |
|---|---|
| `no API key` | poproś o klucz (sekcja 1) |
| `HTTP 400 ... API key not valid` | klucz błędny, nowy z aistudio.google.com/apikey |
| `HTTP 429 ... limit: 0` | modele obrazowe nie są w darmowym tierze: trzeba włączyć billing projektu klucza w AI Studio. Powiedz to wprost, nie ponawiaj |
| `HTTP 429` (bez `limit: 0`) | chwilowy limit: odczekaj ~30 s, ponów raz |
| `HTTP 403` bez treści JSON / `network` | sieć środowiska blokuje `generativelanguage.googleapis.com`. W czacie claude.ai: Ustawienia → Capabilities → Code execution → dodaj tę domenę do dozwolonych (lub „All domains"). W Claude Code na webie: ustawienia sieci środowiska |
| `HTTP 404` | zła nazwa modelu; sprawdź `-m` |
| `no image` | filtr bezpieczeństwa albo odpowiedź tekstowa (pole `text`): przeformułuj prompt |

## 6. Serie i warianty

Kilka wariantów: kilka niezależnych wywołań z różnymi nazwami plików (można
równolegle). Spójna seria (ta sama postać, ten sam styl): pierwszy obraz
generuj normalnie, kolejne z `-i <pierwszy obraz>` jako referencją.
