# Łyżwy – aplikacja Connect IQ

Nagrywa trening jako **Jazda na łyżwach** (FIT sport 33) – w Garmin Connect pojawia się z właściwym typem.

## Obsługa (kryte lodowisko)
- **START**: start; w trakcie → pauza + menu (Wznów / Zapisz / Odrzuć)
- **Okrążenia liczą się same** – z kompasu: każde pełne 360° obrotu = jedno okrążenie (krótka wibracja).
  Zakłócenia magnetyczne hali są stałe w danym miejscu, więc na pełnym okrążeniu się znoszą.
  Piruety/zawrotki szybsze niż 8 s nie są liczone jako okrążenie.
- **BACK**: ręczne okrążenie (korekta, gdy kompas coś pominie) – zeruje licznik obrotu.
- Bez treningu BACK = wyjście z aplikacji
- Ekran: „Okr. 12 +40%” (pełne okrążenia + postęp bieżącego), czas, tętno, kcal, dystans,
  prędkość (z ostatnich 10 s), średnia i maksymalna

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

## Budowanie i wgranie (bez sklepu)
1. Zainstaluj VS Code + rozszerzenie **Monkey C** oraz **Connect IQ SDK Manager** (developer.garmin.com/connect-iq).
2. W SDK Managerze pobierz najnowsze SDK i urządzenie **Forerunner 245 Music**.
3. VS Code: `Monkey C: Generate a Developer Key` (raz).
4. Otwórz folder `LyzwyCIQ` (ustawiony na Forerunner 245 Music – `fr245m`).
5. `Monkey C: Build for Device` → powstaje plik `.prg`.
6. Podłącz zegarek kablem, skopiuj `.prg` do `GARMIN/APPS/`, odłącz. Na zegarku: START → przewiń w dół do „Łyżwy” (lub dodaj do ulubionych: Ustawienia → Aktywności i aplikacje).

Test w symulatorze: `F5` (Run) w VS Code.
