# Instalacja na Windowsie i wgranie aplikacji na zegarek

Instrukcja dla aplikacji testowej **Padel Probe** (`app/`) i parsera
`tools/fit_probe.py`. Całość zajmuje ok. 30–45 minut przy pierwszym razie.

## 1. Programy

1. **Java 17 lub nowsza** (wymaga jej rozszerzenie Monkey C), np. Temurin
   z [adoptium.net](https://adoptium.net). Podczas instalacji zaznacz
   „Set JAVA_HOME” i „Add to PATH”.
2. **Visual Studio Code** z [code.visualstudio.com](https://code.visualstudio.com).
3. **Python 3.11+** z [python.org](https://www.python.org/downloads/windows/).
   W instalatorze zaznacz **„Add python.exe to PATH”**.
4. **Git** z [git-scm.com](https://git-scm.com/download/win), o ile jeszcze go nie masz.

## 2. Connect IQ SDK

1. Wejdź na [developer.garmin.com/connect-iq/sdk](https://developer.garmin.com/connect-iq/sdk)
   i w sekcji **Install the SDK Manager** kliknij *Accept & Download* (wersja Windows).
2. Rozpakuj archiwum do własnego folderu, np. `C:\garmin\sdkmanager`, i uruchom
   `sdkmanager.exe`.
3. **Login**: zaloguj się kontem Garmin (tym samym co w Garmin Connect).
4. Zakładka **SDK**: pobierz najnowszy SDK i kliknij *Use as Current SDK*.
5. Zakładka **Devices**: wyszukaj „epix” i pobierz **epix Pro (Gen 2)** w swoim
   rozmiarze (42, 47 lub 51 mm). Jeśli nie wiesz, pobierz wszystkie trzy.

## 3. Rozszerzenie Monkey C w VS Code

1. W VS Code: *View → Extensions*, wyszukaj **Monkey C** (wydawca: Garmin)
   i zainstaluj. Po instalacji zrestartuj VS Code.
2. `Ctrl+Shift+P` → **Monkey C: Verify Installation**. Powinno potwierdzić
   znalezienie SDK.
3. `Ctrl+Shift+P` → **Monkey C: Generate a Developer Key**. Zapisz klucz
   **poza repozytorium**, np. w `C:\garmin\klucz`. Tym kluczem podpisujesz
   aplikację i **nigdy nie commituj go do gita**.

## 4. Pobranie projektu

```powershell
cd C:\garmin
git clone https://github.com/Przepiores/Garmin_padel_app.git
cd Garmin_padel_app
git checkout ccr-f1588f6a-23a32v
```

W VS Code otwórz folder **`app`** (*File → Open Folder…*), bo tam leży
`monkey.jungle`, czyli plik projektu Connect IQ.

## 5. Kompilacja i symulator (opcjonalnie, ale warto)

1. Otwórz dowolny plik z `app/source`.
2. *Run → Run Without Debugging* (`Ctrl+F5`) i wybierz swój model epix Pro.
3. Symulator nie ma prawdziwych czujników, więc częstotliwości mogą pokazywać 0.
   W tym kroku sprawdzamy tylko, że **kompilacja przechodzi** i ekran się
   rysuje. Klawisze symulatora: START = nagrywanie, UP/DOWN = etykieta.

**Jeśli kompilacja zgłosi błędy**, skopiuj cały komunikat z zakładki
*Output/Problems* i wklej go do rozmowy ze mną. Tego kodu nie dało się
skompilować w moim środowisku, bo nie mam tam dostępu do serwerów Garmina,
więc drobne poprawki są prawdopodobne.

## 6. Wgranie na zegarek (sideload)

1. `Ctrl+Shift+P` → **Monkey C: Build for Device** → wybierz model → wskaż
   folder wyjściowy (np. `C:\garmin\build`). Powstanie plik `.prg`.
2. Podłącz zegarek kablem USB. W Eksploratorze pojawi się jako urządzenie
   (MTP): *Ten komputer → epix Pro → Internal Storage*.
3. Skopiuj plik `.prg` do folderu **`GARMIN\Apps`** na zegarku.
4. Odłącz zegarek. Aplikacja **Padel Probe** pojawi się na liście aktywności
   i aplikacji (przycisk START, przewiń w dół).

## 7. Ustawienie zegarka przed testem

**Zapis danych co sekundę.** Wycinki uderzeń są zapisywane porcjami w rekordach
co sekundę. W trybie „Smart” część porcji może przepaść.
Na zegarku: *Ustawienia → System → Zapis danych → Co sekundę*
(ang. *Settings → System → Data Recording → Every Second*). Nazwy menu mogą się
nieznacznie różnić zależnie od wersji oprogramowania zegarka.

## 8. Plik FIT po treningu i parser

**Skąd wziąć plik .fit**, jedna z dwóch dróg:
- bezpośrednio z zegarka: podłącz przez USB i skopiuj najnowszy plik z
  `GARMIN\Activity`,
- z Garmin Connect w przeglądarce: aktywność → ikona ⚙ → *Eksportuj oryginał*.
  Dostaniesz ZIP z plikiem `.fit`.

**Uruchomienie parsera** (PowerShell, w katalogu repozytorium):

```powershell
cd tools
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python fit_probe.py C:\sciezka\do\aktywnosci.fit --plot
```

Jeśli PowerShell zablokuje aktywację środowiska, uruchom raz
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

Parser wypisze raport i utworzy obok pliku FIT folder z `windows.csv`,
`windows_summary.csv` i wykresem `windows_omega.png`.

## Gdy coś pójdzie nie tak

- **Ikona „IQ!” lub aplikacja się zamyka**: na zegarku pojawi się plik
  `GARMIN\Apps\LOGS\CIQ_LOG.YAML`. Wklej jego zawartość do rozmowy.
- **Brak polskich znaków na ekranie**: zegarek używa języka systemu. Przy
  angielskim systemie zobaczysz angielskie napisy, i tak ma być.
