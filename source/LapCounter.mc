import Toybox.Lang;
import Toybox.Math;

// Liczenie okrążeń z samego kompasu (~1 Hz) – logika bez czujników, testowana w
// source/LapCounterTest.mc (CI, symulator).
//
// Kompas mówi, w którą stronę zwrócony jest zegarek. Na owalu tafli każde pełne 360° obrotu
// = jedno okrążenie. Zakłócenia magnetyczne hali są stałe w danym miejscu, więc na pełnym
// okrążeniu się znoszą.
// - Zwrot przód/tył: skok > 120° w jednej próbce albo > 150° w dwóch kolejnych (po odjęciu
//   przewidywanego obrotu z zakrętu), odejmujemy 180° – kierunek jazdy się nie zmienił.
//   Znane ograniczenie: zwrot w zakręcie czasem daje błąd ±1 okrążenia (~3% zwrotów).
// - Zmiana kierunku jazdy (np. co 30 min): kompas zaczyna obracać się konsekwentnie w drugą
//   stronę (> REV_RAD od szczytu). Niedokończone okrążenie sprzed nawrotu liczymy z czasu
//   (wzorzec tempa) i odkładamy w carry; liczenie zaczyna się od nawrotu w nową stronę.
// - Wzorzec tempa: pierwsze okrążenie, potem mediana ostatnich. Automatyczne "okrążenie"
//   krótsze niż połowa typowego to błąd (piruet, manewr), nie jazda.
class LapCounter {
    static const PI_F = 3.1415927;
    static const TWO_PI_F = 6.2831853;
    // Krótsze "okrążenie" = podwójne kliknięcie albo resztka manewru, nie liczymy.
    static const MIN_LAP_MS = 8000;
    static const FLIP_RAD = 2.0943951;  // 120° w jednej próbce
    static const FLIP2_RAD = 2.6179939; // 150° w dwóch próbkach
    static const CALM_RAD = 0.7;        // spokojna próbka (do nauki tempa zakrętu)
    static const REF_LAPS = 5;
    static const REF_MIN_FRACTION = 0.5;
    // Kierunek jazdy ustala się po pół okrążenia; nawrót = cofnięcie o > 126° od szczytu
    // (zakłócenia hali dają najwyżej ~80°, zakręt w drugą stronę to 180°).
    // 160°: częściowo rozpoznany zwrot tyłem nie udaje zmiany kierunku.
    static const DIR_SET_RAD = 3.1415927;
    static const REV_RAD = 2.8;

    var laps as Number = 0;
    var turn as Float = 0.0;            // obrót [rad] od ostatniego okrążenia
    var backward as Boolean = false;
    var lastLapDtMs as Number = 0;      // czas ostatniego okrążenia
    var rejectedLaps as Number = 0;
    var direction as Number = 0;        // +1 / -1 kierunek jazdy po owalu, 0 = jeszcze nie wiadomo
    var reversals as Number = 0;
    var carry as Float = 0.0;           // niedokończone okrążenia sprzed nawrotów

    private var _anchor = null;         // poprzedni kierunek
    private var _lastLapTimerMs as Number = 0;
    private var _lapTimes as Array<Number> = [];
    private var _peak as Float = 0.0;
    private var _peakT as Number = 0;
    private var _prevD as Float = 0.0;       // poprzednia próbka (zwrot rozłożony na dwie)
    private var _justFlipped as Boolean = false;
    private var _rate as Float = 0.0;        // obrót z jazdy na próbkę (zakręt)

    function initialize() {
    }

    static function wrap(d as Float) as Float {
        while (d > PI_F) { d -= TWO_PI_F; }
        while (d <= -PI_F) { d += TWO_PI_F; }
        return d;
    }

    private static function absf(v as Float) as Float {
        return v < 0 ? -v : v;
    }

    // Pauza / brak nagrywania: śledzimy kierunek, ale nic nie liczymy.
    function hold(hd as Float) as Void {
        _anchor = hd;
    }

    // Kierunek z kompasu (~1 Hz). Zwraca true, gdy naliczono okrążenie.
    function addHeading(hd as Float, timerMs as Number) as Boolean {
        if (_anchor == null) {
            _anchor = hd;
            return false;
        }
        var d = wrap(hd - _anchor);
        _anchor = hd;
        // obrót z samej jazdy (zakręt) przewidujemy z ostatnich sekund i odejmujemy przed oceną zwrotu
        var dd = d - _rate;
        var flip = false;
        if (_justFlipped) {
            // tuż po zwrocie drugi zwrot nie jest możliwy – reszta to jazda (np. zakręt)
            _justFlipped = false;
            _prevD = 0.0;
        } else if (dd > FLIP_RAD || dd < -FLIP_RAD) {
            flip = true;
        } else if (absf(_prevD + dd) > FLIP2_RAD && _prevD * dd > 0) {
            flip = true;  // zwrot rozłożony na dwie próbki
        } else {
            _prevD = dd;
        }
        if (flip) {
            // zwrot przód/tył (w którąkolwiek stronę) – kierunek jazdy się nie zmienił
            backward = !backward;
            d += (dd > 0) ? -PI_F : PI_F;
            _prevD = 0.0;
            _justFlipped = true;
        } else if (!_justFlipped && absf(dd) < CALM_RAD) {
            // tempo zakrętu uczymy się tylko na spokojnych próbkach (nie z połowy zwrotu)
            _rate += 0.3 * (d - _rate);
        }
        turn += d;
        trackDirection(timerMs);
        if (turn >= TWO_PI_F || turn <= -TWO_PI_F) {
            // nadwyżka ponad 360° zostaje dla następnego okrążenia
            turn += (turn > 0) ? -TWO_PI_F : TWO_PI_F;
            _peak = turn;
            _peakT = timerMs;
            return tryLap(timerMs, true);
        }
        return false;
    }

    private function trackDirection(timerMs as Number) as Void {
        if (direction == 0) {
            if (absf(turn) >= DIR_SET_RAD) {
                direction = turn > 0 ? 1 : -1;
                _peak = turn;
                _peakT = timerMs;
            }
            return;
        }
        if (direction * (turn - _peak) > 0) {
            _peak = turn;
            _peakT = timerMs;
        } else if (direction * (_peak - turn) > REV_RAD) {
            // nawrót w chwili _peakT: niedokończone okrążenie liczymy z czasu (wzorzec tempa)
            var ref = referenceLapMs();
            var frac = ref > 0 ? (_peakT - _lastLapTimerMs).toFloat() / ref : absf(_peak) / TWO_PI_F;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 0.95) { frac = 0.95; }
            carry += frac;
            if (carry >= 1.0) {
                carry -= 1.0;
                laps += 1;
            }
            turn -= _peak;               // obrót od chwili nawrotu, już w nową stronę
            _lastLapTimerMs = _peakT;    // tempo kolejnego okrążenia liczymy od nawrotu
            direction = -direction;
            _peak = turn;
            _peakT = timerMs;
            reversals += 1;
        }
    }

    // BACK: ręczne okrążenie – zeruje licznik obrotu.
    function manualLap(timerMs as Number) as Boolean {
        if (tryLap(timerMs, false)) {
            turn = 0.0;
            _peak = 0.0;
            _peakT = timerMs;
            return true;
        }
        return false;
    }

    private function tryLap(timerMs as Number, auto as Boolean) as Boolean {
        var dt = timerMs - _lastLapTimerMs;
        if (dt < MIN_LAP_MS) {
            return false;
        }
        var ref = referenceLapMs();
        if (auto && ref > 0 && dt < ref * REF_MIN_FRACTION) {
            rejectedLaps += 1;
            return false;
        }
        lastLapDtMs = dt;
        _lastLapTimerMs = timerMs;
        laps += 1;
        _lapTimes.add(dt);
        if (_lapTimes.size() > REF_LAPS) {
            _lapTimes = _lapTimes.slice(1, null);
        }
        return true;
    }

    // Typowy czas okrążenia [ms]: mediana ostatnich (na początku – pierwsze okrążenie); 0 = brak.
    function referenceLapMs() as Number {
        var n = _lapTimes.size();
        if (n == 0) {
            return 0;
        }
        var a = _lapTimes.slice(0, null);
        for (var i = 1; i < n; i++) {
            var v = a[i];
            var j = i - 1;
            while (j >= 0 && a[j] > v) {
                a[j + 1] = a[j];
                j -= 1;
            }
            a[j + 1] = v;
        }
        return a[n / 2];
    }

    // Przejechane okrążenia łącznie (pełne + niedokończone sprzed nawrotów + bieżące).
    function totalLaps() as Float {
        return laps + carry + lapFraction();
    }

    // Część bieżącego okrążenia 0..1.
    function lapFraction() as Float {
        var part = absf(turn) / TWO_PI_F;
        return part > 1.0 ? 1.0 : part;
    }
}
