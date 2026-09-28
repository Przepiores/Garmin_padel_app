# Plan testu na korcie: Padel Probe

Cel: odpowiedzieć na pytania z sekcji 7 specyfikacji i przy okazji zebrać
pierwsze oznaczone uderzenia. Potrzebujesz ok. 40 minut i kogoś, kto wystawia
piłki (albo wyrzutni).

## Obsługa aplikacji

| Przycisk | Działanie |
|---|---|
| START | start nagrywania; w trakcie: pauza i menu (Wznów / Zapisz / Odrzuć) |
| UP / DOWN | zmiana etykiety; każda zmiana zaczyna nowe okrążenie (lap) |
| BACK | w trakcie nagrywania: okrążenie; bez nagrywania: wyjście |
| przytrzymaj UP (MENU) | ustawienia (logger FIT wł./wył.), tylko przed startem |

Ekran dotykowy jest celowo wyłączony w aplikacji, żeby spocony nadgarstek nie
zatrzymał nagrania.

**Co widać na ekranie:**
- status i czas, a pod nim etykieta uderzenia (żółta),
- `Akc. / Żyro X Hz (max Y)`: zmierzona i maksymalna częstotliwość czujnika,
- `Obrót A °/s, oś B`: największy obrót nadgarstka (moduł) i największa wartość
  pojedynczej osi. Jeśli B stale zatrzymuje się na tej samej okrągłej liczbie,
  np. 2000, żyroskop się nasyca,
- `Uderzenia N, kolejka K`: liczba wykrytych uderzeń i wycinki czekające na
  zapis do pliku,
- `Logger`: czy SensorLogger jest włączony, oraz tętno.

Po każdym wykrytym uderzeniu zegarek **krótko wibruje**, ok. 1 s po uderzeniu.

## Przed wyjściem na kort

- [ ] Zapis danych na zegarku ustawiony na **co sekundę** (patrz
      `INSTALACJA_WINDOWS.md`, krok 7).
- [ ] Zegarek na **prawym** nadgarstku, dopięty ciasno (luźny pasek to
      dodatkowe drgania).

## Sesja A: logger włączony (ok. 30 min)

1. Uruchom Padel Probe i poczekaj ok. 5 s. **Zrób zdjęcie ekranu**: linie
   Akc./Żyro przed startem nagrywania to odpowiedź na pytanie o częstotliwość.
2. Ustaw etykietę **Nie-uderzenie** i naciśnij START.
3. Przez ok. 1 min rób ruchy, które nie są uderzeniem: podnoszenie piłek,
   odbijanie piłki rakietą w miejscu, ocieranie potu, przybicie piątki,
   poprawianie paska.
4. Następnie kolejno dla etykiet **Smash**, **Bandeja**, **Víbora**, **Inne
   uderzenie** (forehandy, backhandy, woleje):
   - zmień etykietę przyciskiem UP/DOWN,
   - wykonaj **15–20 uderzeń**, w tempie mniej więcej jedno na 6–8 s,
   - pilnuj licznika **kolejka**: każde uderzenie zapisuje się ok. 6 s; jeśli
     kolejka przekroczy ~10, zrób przerwę, aż spadnie,
   - zauważ, czy wibracja przychodzi po **każdym** uderzeniu i czy nie
     przychodzi bez uderzenia.
5. Na koniec **poczekaj, aż kolejka spadnie do 0**, potem START → **Zapisz**.
6. Zrób zdjęcie ekranu po zapisaniu (maksima obrotu i akceleracji).

## Sesja B: logger wyłączony (ok. 5 min)

Sprawdzamy, czy SensorLogger nie „zabiera” czujników aplikacji.

1. Przytrzymaj UP → wyłącz **Logger czujników FIT** → BACK.
2. START, etykieta **Smash**, wykonaj 5–10 uderzeń, poczekaj na kolejkę 0,
   START → Zapisz.
3. Porównaj linie Akc./Żyro z sesją A. Jeśli różnią się wyraźnie, logger
   wpływa na próbkowanie.

## Po treningu

1. Zsynchronizuj zegarek lub skopiuj pliki `.fit` przez USB (patrz instrukcja).
2. Dla każdej sesji uruchom:
   ```
   python fit_probe.py SCIEZKA\do\pliku.fit --plot
   ```
3. Odeślij mi:
   - pełny tekst raportu z obu sesji,
   - wykres `windows_omega.png` z sesji A,
   - zdjęcia ekranu zegarka,
   - swoje obserwacje: zgubione lub nadmiarowe wibracje, czy coś się
     zawiesiło, czy czas i tętno wyglądały normalnie.

   Możesz też wrzucić pliki `.fit` do katalogu `data/` w repozytorium.
   Pamiętaj, że zawierają tętno, więc jeśli repozytorium jest publiczne,
   lepiej przesłać tylko raport.

## Co z tego wyczytamy

| Pytanie | Gdzie jest odpowiedź |
|---|---|
| Częstotliwość czujników | ekran (Akc./Żyro), raport: `acc_rate`, `gyro_rate`, częstotliwość w wycinkach |
| Nasycenie żyroskopu | ekran (`oś B`), raport: ostrzeżenie o identycznych maksimach |
| SensorLogger | raport: sekcja SensorLogger (liczba próbek, Hz, pola) |
| Wycinki w polach FIT | raport: wycinków / kompletnych / duplikaty, brakujące wycinki |
| Zapis co sekundę | raport: odstępy między rekordami |
| Typ aktywności | raport: `sport`; w Garmin Connect ikona i nazwa aktywności |
| Czy detektor działa | liczba wibracji vs faktyczne uderzenia; wykres `windows_omega.png` |
