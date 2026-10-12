# Lap Skater (Łyżwy) – aplikacja Connect IQ

Nagrywa trening jako **Jazda na łyżwach** (FIT sport 33) – w Garmin Connect pojawia się z właściwym typem.

## Obsługa (kryte lodowisko)
- **START**: start; w trakcie → pauza + menu (Wznów / Zapisz / Odrzuć)
- **Okrążenia liczą się same** – z kompasu: każde pełne 360° obrotu = jedno okrążenie (po cichu).
  Zakłócenia magnetyczne hali są stałe w danym miejscu, więc na pełnym okrążeniu się znoszą.
- **Piruety i jazda tyłem**: szybkie obroty wykrywa magnetometr z akcelerometrem (25 Hz); obrót ciała
  w czasie manewru jest zaokrąglany do wielokrotności 180° i odejmowany (nieparzysta liczba połówek =
  zwrot przód/tył), więc nie dodaje ani nie zabiera okrążeń.
- **Zmiana kierunku jazdy** (np. co 30 min): wykrywana, gdy kompas zaczyna obracać się konsekwentnie
  w drugą stronę; niedokończone okrążenie sprzed nawrotu liczone z czasu (wzorzec tempa), dalej liczenie
  w nową stronę. Błąd w symulacji: ~0,2–0,4 okrążenia na nawrót.
- **Pierwsze okrążenie = wzorzec**: kalibruje magnetometr i tempo; automatyczne „okrążenie” krótsze niż
  połowa typowego (mediana ostatnich) jest odrzucane.
- **BACK**: ręczne okrążenie (korekta, gdy kompas coś pominie) – zeruje licznik obrotu, krótka wibracja.
- **UP / DOWN**: przełączanie ekranu prostego i szczegółów
- Bez treningu BACK = wyjście z aplikacji
- Ekran główny: czas, duża liczba okrążeń, dystans; postęp bieżącego okrążenia jako niebieski pierścień
- Ekran szczegółów: okrążenia z %, czas, tętno, kcal, dystans, prędkość (z ostatnich 10 s), średnia i maksymalna

Ograniczenia: jeśli lodowisko w trakcie zmieni kierunek jazdy, tracisz najwyżej kawałek okrążenia.
Jazda „ósemkami” albo zabawa na środku tafli nie liczy się jako dystans.

**Dystans = okrążenia × długość okrążenia.** Domyślnie 145 m (tafla 60×30, jazda ~3 m od bandy).
Zmiana na zegarku: w aplikacji, przed startem, **przytrzymaj UP** → wybierz długość (aktualna ma „*”)
albo przełącz GPS.
Jak ją policzyć: tafla 60×30 m, jeździsz ~3 m od bandy → prostokąt 54×24 m ≈ 2×(54+24) = 156 m,
minus zaokrąglone narożniki ≈ 150 m.

W Garmin Connect: typ „Jazda na łyżwach”, tętno, kalorie, okrążenia z czasami; dystans, liczba okrążeń
i średnia prędkość są w sekcji danych aplikacji Connect IQ (wykresy: dystans, prędkość okrążenia).
Natywne pole „Dystans” zostaje puste – aplikacje Connect IQ nie mogą go ustawić bez GPS.

Lód na zewnątrz? Włącz w ustawieniach „GPS zamiast okrążeń” – wtedy dystans liczy zegarek z GPS.

## Testy

Algorytm liczenia okrążeń jest w `source/LapCounter.mc` (bez czujników), testy w
`source/LapCounterTest.mc`: syntetyczna jazda po owalu 60×30 m z zakłóceniami hali, machaniem ręką,
piruetami, jazdą tyłem, nieskalibrowanym magnetometrem, ręcznymi okrążeniami – każdy scenariusz na kilku
ziarnach losowych. CI uruchamia je w symulatorze Connect IQ przed każdym buildem; czerwony test
blokuje wydanie. Wynik: artefakt `test.log` w danym przebiegu Actions.

## Automatyczny build (GitHub Actions)

Każdy push do `main` buduje aplikację i wystawia pliki w **Releases → „Najnowszy build”**:
- `lap-skater.iq` – do wgrania w Connect IQ Store jako beta (apps.garmin.com/developer → Upload an App),
- `lap-skater.prg` – do wgrania kablem do `GARMIN/APPS`.

Jednorazowo: **Settings → Secrets and variables → Actions → New repository secret**:

| Sekret | Wartość |
|---|---|
| `GARMIN_USERNAME` | e-mail konta Garmin |
| `GARMIN_PASSWORD` | hasło konta Garmin (konto bez weryfikacji dwuetapowej) |
| `DEVELOPER_KEY_B64` | klucz deweloperski w base64 – ten sam przy każdej wersji, inaczej sklep nie przyjmie aktualizacji |

Build akceptuje umowę licencyjną Connect IQ SDK:
https://developer.garmin.com/downloads/connect-iq/sdks/agreement.html
(opcjonalnie zmienna repozytorium `GARMIN_AGREEMENT_HASH` = hash przeczytanej wersji).
Ręczne uruchomienie: Actions → Build → Run workflow.

## Budowanie lokalne (opcjonalnie)
1. Zainstaluj VS Code + rozszerzenie **Monkey C** oraz **Connect IQ SDK Manager** (developer.garmin.com/connect-iq).
2. W SDK Managerze pobierz najnowsze SDK i urządzenie **Forerunner 245 Music**.
3. VS Code: `Monkey C: Generate a Developer Key` (raz).
4. Otwórz folder `LyzwyCIQ` (ustawiony na Forerunner 245 Music – `fr245m`).
5. `Monkey C: Build for Device` → powstaje plik `.prg`.
6. Podłącz zegarek kablem, skopiuj `.prg` do `GARMIN/APPS/`, odłącz. Na zegarku: START → przewiń w dół do „Łyżwy” (lub dodaj do ulubionych: Ustawienia → Aktywności i aplikacje).

Test w symulatorze: `F5` (Run) w VS Code.
