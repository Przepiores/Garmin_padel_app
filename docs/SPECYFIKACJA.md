# Padel Stroke Analyzer – specyfikacja

Wynik wywiadu z 2026-09-28. Aplikacja Connect IQ, która zamienia zegarek Garmin
w analizator uderzeń w padlu: rozpoznaje typ uderzenia na podstawie
akcelerometru i żyroskopu, a uderzenia, których nie da się pewnie
sklasyfikować, oznacza jako **niepewne** zamiast zgadywać.

## 1. Ustalenia z wywiadu

| Temat | Decyzja |
|---|---|
| Urządzenie | Garmin **Epix Pro (Gen 2)** AMOLED, na start tylko to urządzenie |
| Nadgarstek | Do wyboru w ustawieniach. Model trenujemy najpierw na **prawej ręce (z rakietą)**, gracz praworęczny |
| Uderzenia (docelowo) | smash, bandeja, víbora; forehand i backhand z ziemi; wolej forehand i backhand; serwis; lob |
| Pierwszy etap | **Uderzenia nad głową** (smash, bandeja, víbora) |
| Wyniki | **Tylko po meczu**, w trakcie gry zegarek tylko nagrywa |
| Aktywność | Pełna aktywność Garmin (tętno, czas, kalorie, zapis do Garmin Connect), zastępuje wbudowany profil |
| Dane treningowe | **Tryb treningowy z etykietami**: wybierasz typ uderzenia i wykonujesz serię |
| Niepewne | Pokazywane jako najbardziej prawdopodobny typ ze znakiem zapytania, np. `bandeja? (lub víbora)`. Liczone **osobno** od pewnych |
| Nie-uderzenia | Podnoszenie piłki, gesty itp. są **odrzucane po cichu**. Do diagnostyki zostaje tylko ich liczba |
| Podsumowanie | Na zegarku i w Garmin Connect |
| Metryki dodatkowe | szacowana prędkość zamachu, oś czasu uderzeń, intensywność i wymiany |
| Odbiorcy | Na początek tylko autor. Model jest uczony na jego uderzeniach |
| Podział pracy | Współpraca: Claude pisze kod i tłumaczy decyzje, autor przegląda, testuje na korcie i zbiera dane |
| Środowisko | Windows, VS Code z rozszerzeniem Monkey C, Connect IQ SDK, Python |
| Język UI | Polski i angielski, wybierany automatycznie według języka zegarka |

## 2. Etapy

### Etap 1: uderzenia nad głową (MVP)
Tryb treningowy musi powstać już teraz, bo bez oznaczonych danych nie da się
wiarygodnie odróżnić bandeji od víbory.

- Aktywność Garmin: start, pauza, zapis, tętno, czas i kalorie.
- **Tryb treningowy**: zbieranie oznaczonych nagrań uderzeń.
- **Tryb meczu**: nagrywanie, detekcja i klasyfikacja po zakończeniu.
- Klasy: `smash`, `bandeja`, `víbora`, `inne uderzenie` (wszystko poza
  uderzeniami nad głową, na razie bez podziału) oraz `niepewne`.
- Podsumowanie na zegarku i pola danych w Garmin Connect.
- Metryki: prędkość zamachu, oś czasu, intensywność i wymiany.

### Etap 2: gra z ziemi i wolej
Forehand i backhand z ziemi, wolej forehand i backhand. `inne uderzenie` jest
rozbijane na konkretne klasy.

### Etap 3: reszta
Serwis i lob. Opcjonalnie wsparcie dla zegarka na ręce bez rakiety, co wymaga
osobnego modelu i jest znacznie trudniejsze.

## 3. Tryby aplikacji

### Tryb treningowy (etykietowanie)
1. Wybierasz typ uderzenia z listy, np. „Bandeja”.
2. Startujesz serię i wykonujesz uderzenia, np. od trenera lub z wyrzutni.
3. Każde wykryte uderzenie potwierdza krótka wibracja, dzięki czemu od razu
   widać, czy detektor coś zgubił.
4. Okno danych wokół każdego uderzenia jest zapisywane z etykietą.
5. Osobna etykieta **„nie-uderzenie”** do nagrywania fałszywych alarmów, np.
   podnoszenia piłki, przybijania piątki czy poprawiania rakiety. To dane dla
   filtra, który odrzuca je po cichu.

### Tryb meczu
- W trakcie gry ekran pokazuje tylko czas i tętno, bez liczników uderzeń.
- Klawisz Lap jest opcjonalny i nie jest wymagany w etapie 1.
- Po zakończeniu: klasyfikacja, podsumowanie i zapis aktywności.

## 4. Potok przetwarzania

```
czujniki (akcel. + żyro) ─► detekcja kandydata ─► filtr nie-uderzeń ─► cechy ─► klasyfikator ─► próg pewności
                                                        │                                        │
                                                   odrzucone (tylko licznik)          pewne / niepewne („typ?”)
```

1. **Próbkowanie**: akcelerometr i żyroskop z najwyższą częstotliwością, jaką
   udostępnia urządzenie (cel: 100 Hz, do weryfikacji).
2. **Detekcja kandydata**: szczyt modułu prędkości kątowej |ω| powyżej progu.
   Wycinamy okno od ok. −0,6 s do +0,4 s wokół szczytu, a kolejne szczyty
   w bardzo krótkim odstępie są scalane.
3. **Filtr nie-uderzeń**: odrzuca ruchy za słabe, za wolne lub nie
   pasujące do uderzenia.
4. **Cechy** (liczone na zegarku):
   - orientacja przedramienia względem grawitacji w chwili uderzenia (czy ręka
     jest nad głową),
   - dominująca oś obrotu oraz pronacja i supinacja,
   - szczytowe |ω| i szczytowe przyspieszenie,
   - czas trwania zamachu, faza przygotowania i faza wybrzmienia.
5. **Klasyfikator**: mały model (drzewo decyzyjne lub regresja logistyczna)
   trenowany w Pythonie na komputerze. Parametry są eksportowane jako stałe
   do kodu Monkey C.
6. **Pewność**: uderzenie jest `niepewne`, jeśli prawdopodobieństwo
   najlepszej klasy jest poniżej progu **albo** różnica między dwiema
   najlepszymi klasami jest mniejsza niż margines. W podsumowaniu wyświetla
   się jako `typ1? (lub typ2)`. Próg można ustawić w ustawieniach aplikacji.

### Hipotezy rozróżnienia uderzeń nad głową
Do sprawdzenia na danych, to nie są ustalone reguły:

- **Smash**: najwyższe |ω|, pełny zamach z góry w dół, wyraźna pronacja.
- **Bandeja**: wolniejsza, ruch bardziej do przodu niż w dół, mało pronacji,
  „krojenie” piłki.
- **Víbora**: szybsza od bandeji, silna rotacja boczna (slice), zamach
  bardziej z boku.

Bandeja i víbora to para, która najczęściej będzie trafiać do `niepewne`.

## 5. Podsumowanie i metryki

**Na zegarku (po meczu):**
- liczba pewnych uderzeń każdego typu,
- niepewne z typem i alternatywą, np. `bandeja? (lub víbora) ×4`,
- najmocniejsze uderzenie (maks. prędkość zamachu) z typem,
- uderzenia na minutę i szacowana liczba wymian.

**W Garmin Connect** (pola danych Connect IQ):
- pola sesji: liczby uderzeń per typ, liczba niepewnych, maks. prędkość zamachu,
- pola na osi czasu: typ uderzenia i prędkość zamachu w danej sekundzie,
  co daje wykres przebiegu meczu.

**Wymiany**: zegarek widzi tylko Twoje uderzenia, więc wymiany są
szacowane na podstawie przerw. Przerwa dłuższa niż X s oznacza nową wymianę,
a X dobierzemy empirycznie.

**Prędkość zamachu**: szczytowa prędkość kątowa nadgarstka (°/s). To miara
względna, dobra do porównań między uderzeniami, a nie prędkość piłki.

## 6. Ustawienia aplikacji
- nadgarstek: lewy lub prawy,
- ręka grająca: prawa lub lewa,
- próg pewności klasyfikacji (suwak z rozsądną wartością domyślną),
- język: automatycznie według zegarka (PL/EN).

## 7. Spike techniczny: aplikacja Padel Probe
Założenia do potwierdzenia na prawdziwym Epix Pro, zanim zbudujemy resztę.
Służy do tego aplikacja testowa w `app/`
(instrukcja: [INSTALACJA_WINDOWS.md](INSTALACJA_WINDOWS.md),
test: [PLAN_TESTU.md](PLAN_TESTU.md)).

Stan wiedzy z dokumentacji Connect IQ (wrzesień 2026):

1. **Częstotliwość próbkowania i żyroskop**. Epix Pro (Gen 2) obsługuje
   `Sensor.registerSensorDataListener` z akcelerometrem (mili-g) i
   żyroskopem (°/s). Maksimum zwraca
   `getMaxSampleRateForSensorType()`, a jego wartość sprawdzamy na zegarku.
   Sprawdzamy też nasycenie żyroskopu przy smashu.
2. **Eksport danych treningowych na komputer**:
   - ~~A: plik logu przez USB~~. Odrzucone: logi na zegarku są obcinane do
     ok. 5 KB (maks. ok. 10 KB z kopią `.BAK`).
   - **B1: `SensorLogging.SensorLogger`** zapisuje surowy akcelerometr
     i żyroskop do pliku FIT aktywności. Według forum tylko ok. 25 Hz,
     a znaczniki czasu bywają błędne. Do sprawdzenia.
   - **B2: wycinki w polach deweloperskich FIT**. Zegarek sam wykrywa
     uderzenie przy pełnej częstotliwości i zapisuje ok. 0,8 s sygnału wokół
     niego, porcjami po 112 wartości, bo aplikacja ma limit **256 B na
     rekord**, a rekord powstaje co 1 s. Jedno uderzenie przy 100 Hz zajmuje
     ok. 6 s zapisu. Wymaga zapisu „co sekundę” zamiast „Smart”.
   - C: wysyłka przez telefon (`makeWebRequest`). Rezerwa, jeśli B zawiedzie.
3. **Typ aktywności**: od API 4.1.6 jest `Activity.SPORT_RACKET` (64)
   z `SUB_SPORT_PADEL` (85). Aplikacja ich używa, a zapis w Garmin Connect
   sprawdzamy.
4. **Limity pól FIT**: 256 B na komunikat dla aplikacji. `setData()`
   wywołane przed zapisem rekordu nadpisuje poprzednią wartość.
5. **Wolumen danych**: na start ok. 50–100 oznaczonych uderzeń na klasę
   i osobno nagrania „nie-uderzeń”.

Konsekwencja dla docelowej aplikacji: detekcja uderzeń i tak musi działać na
zegarku w czasie rzeczywistym, więc detektor z Padel Probe będzie podstawą
trybu meczu.

## 8. Struktura repozytorium
```
app/            # aplikacja Connect IQ (Monkey C); obecnie Padel Probe (spike)
  manifest.xml
  monkey.jungle
  source/       # nagrywanie, czujniki, detekcja, zapis wycinków, UI
  resources/    # stringi EN (domyślne), pola FIT, ikona
  resources-pol/ # stringi PL
tools/          # Python: parser FIT (fit_probe.py), później trening modelu
data/           # oznaczone nagrania (.fit), opcjonalnie
docs/           # specyfikacja, instalacja, plan testu
```
