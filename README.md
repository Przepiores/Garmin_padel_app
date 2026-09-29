# Garmin Padel App

Aplikacja Connect IQ na zegarki Garmin (start: Epix Pro Gen 2), która
rozpoznaje uderzenia w padlu (smash, bandeja, víbora i kolejne) na podstawie
akcelerometru i żyroskopu. Uderzenia, których nie da się pewnie
sklasyfikować, są oznaczane jako niepewne.

## Stan

Etap spike'a technicznego. `app/` zawiera aplikację testową **Padel Probe**,
która mierzy częstotliwość czujników, nagrywa aktywność padel i zapisuje
oznaczone wycinki uderzeń do pliku FIT. `tools/fit_probe.py` analizuje taki
plik.

## Dokumenty

- [Specyfikacja](docs/SPECYFIKACJA.md)
- [Instalacja na Windowsie i wgranie na zegarek](docs/INSTALACJA_WINDOWS.md)
- [Plan testu na korcie](docs/PLAN_TESTU.md)
- [Globalne przypomnienia o testach na sprzęcie (hook)](tools/claude-hw-reminder/README.md)

## Testy parsera

```
cd tools
pip install -r requirements.txt
python -m unittest discover tests
```
