import Toybox.Lang;
import Toybox.Math;

// Liczenie okrążeń z kompasu – sama logika, bez czujników, żeby dało się ją testować
// (source/LapCounterTest.mc, uruchamiane w CI).
//
// Kompas (~1 Hz) mówi, w którą stronę zwrócony jest zegarek. Na owalu tafli każde pełne
// 360° obrotu = jedno okrążenie. Zakłócenia magnetyczne hali są stałe w danym miejscu,
// więc na pełnym okrążeniu się znoszą.
//
// Manewry obracają ciało, a nie kierunek jazdy:
// - piruet / szybki obrót / zwrot do jazdy tyłem – wykrywane z szybkich danych
//   (magnetometr skompensowany pochyleniem z akcelerometru, ~25 Hz). Próbki kompasu z czasu
//   manewru pomijamy; obrót ciała mierzony szybkimi danymi zaokrąglamy do wielokrotności 180°
//   i odejmujemy (nieparzysta liczba połówek = zwrot przód/tył),
// - bez szybkich danych: skok kierunku > 135° między próbkami to zwrot przód/tył.
// Pierwsze okrążenie jest wzorcem: magnetometr kalibruje się na nim (zakres osi), a jego czas
// (potem mediana ostatnich) odrzuca "okrążenia" dużo krótsze niż typowe.
class LapCounter {
    static const PI_F = 3.1415927;
    static const TWO_PI_F = 6.2831853;
    // Krótsze "okrążenie" = podwójne kliknięcie albo resztka manewru, nie liczymy.
    static const MIN_LAP_MS = 8000;
    // Szybkie dane: obrót szybszy niż SPIN_RATE [rad/s] w oknie SPIN_WINDOW próbek,
    // SPIN_MIN_SAMPLES razy z rzędu. W zakręcie ~0,5-1 rad/s, zwrot tyłem ~6 rad/s.
    static const FAST_RATE = 25;
    static const SPIN_RATE = 3.0;
    static const SPIN_WINDOW = 5;
    static const SPIN_MIN_SAMPLES = 2;
    static const SPIN_MARGIN_MS = 300;
    static const SPIN_HOLD_MS = 500;
    static const ACC_ALPHA = 0.3;      // wygładzanie akcelerometru (kierunek grawitacji)
    static const RING = 40;            // historia szybkich danych (1,6 s)
    // Zwrot przód/tył: skok między kolejnymi próbkami kompasu (jazda tak nie obraca)
    // oraz próg po manewrze, gdy brak pomiaru z szybkich danych.
    static const FLIP_RAD = 2.3561945; // 135°
    static const FLIP_GAP_RAD = 1.5707963; // 90°
    // Wzorzec tempa: mediana ostatnich REF_LAPS okrążeń (na początku – pierwsze).
    static const REF_LAPS = 5;
    static const REF_MIN_FRACTION = 0.5;

    var laps as Number = 0;
    var turn as Float = 0.0;            // obrót [rad] od ostatniego okrążenia
    var backward as Boolean = false;
    var lastLapDtMs as Number = 0;      // czas ostatniego okrążenia
    var spinsDetected as Number = 0;
    var rejectedLaps as Number = 0;

    private var _lastLapTimerMs as Number = 0;
    private var _lapTimes as Array<Number> = [];
    // kompas
    private var _anchor = null;         // ostatni zatwierdzony kierunek
    private var _anchorT as Number = 0;
    private var _pendHd = null;         // próbka czeka 1 s, aż przyjdzie paczka szybkich danych
    private var _pendT as Number = 0;
    private var _gap as Boolean = false; // od ostatniej zatwierdzonej próbki był manewr
    private var _rate as Float = 0.0;    // tempo obrotu z jazdy [rad/s]
    private var _totalRot as Float = 0.0;
    // manewr
    private var _spinFromMs as Number = -100000;
    private var _spinUntilMs as Number = -100000;
    private var _uStart = null;
    private var _uEnd as Float = 0.0;
    // szybkie dane
    private var _calReady as Boolean = false;
    private var _mn = null;
    private var _mx = null;
    private var _g = null;
    private var _prevFast = null;
    private var _u as Float = 0.0;       // narastający obrót z szybkich danych
    private var _fastCount as Number = 0;
    private var _hist as Array<Float> = [];
    private var _ringT as Array<Number> = new Array<Number>[RING];
    private var _ringU as Array<Float> = new Array<Float>[RING];
    private var _ringPos as Number = 0;
    private var _ringLen as Number = 0;

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
        _pendHd = null;
        _gap = false;
    }

    // Kierunek osi X zegarka z magnetometru skompensowany pochyleniem (dół = -a).
    static function tiltHeading(ax as Float, ay as Float, az as Float, mx as Float, my as Float, mz as Float) {
        var dx = -ax;
        var dy = -ay;
        var dz = -az;
        var ex = dy * mz - dz * my;
        var ey = dz * mx - dx * mz;
        var ez = dx * my - dy * mx;
        var nx = ey * dz - ez * dy;
        var ny = ez * dx - ex * dz;
        var nz = ex * dy - ey * dx;
        var ne = ex * ex + ey * ey + ez * ez;
        if (ne <= 0) {
            return null;
        }
        var nn = Math.sqrt(nx * nx + ny * ny + nz * nz);
        if (nn <= 0) {
            return null;
        }
        return Math.atan2(ex / Math.sqrt(ne), nx / nn).toFloat();
    }

    // Paczka szybkich danych (akcelerometr i magnetometr, tablice), nowMs = czas nadejścia.
    function addFastSamples(axs, ays, azs, mxs, mys, mzs, nowMs as Number) as Void {
        var n = mxs.size();
        if (axs.size() < n) { n = axs.size(); }
        var step = 1000 / FAST_RATE;
        for (var i = 0; i < n; i++) {
            var ts = nowMs - (n - 1 - i) * step;  // czas próbki w paczce
            var mx = mxs[i].toFloat();
            var my = mys[i].toFloat();
            var mz = mzs[i].toFloat();
            // samokalibracja: środek zakresu osi poziomych = magnetyzm samego zegarka
            if (_mn == null) {
                _mn = [mx, my];
                _mx = [mx, my];
            } else {
                if (mx < _mn[0]) { _mn[0] = mx; }
                if (my < _mn[1]) { _mn[1] = my; }
                if (mx > _mx[0]) { _mx[0] = mx; }
                if (my > _mx[1]) { _mx[1] = my; }
            }
            if (!_calReady) {
                continue; // pierwsze okrążenie: tylko zbieramy zakres osi
            }
            mx -= (_mx[0] + _mn[0]) / 2;
            my -= (_mx[1] + _mn[1]) / 2;   // oś Z (pionowa) prawie się nie obraca – bez korekty
            var ax = axs[i].toFloat();
            var ay = ays[i].toFloat();
            var az = azs[i].toFloat();
            if (_g == null) {
                _g = [ax, ay, az];
            } else {
                _g[0] += ACC_ALPHA * (ax - _g[0]);
                _g[1] += ACC_ALPHA * (ay - _g[1]);
                _g[2] += ACC_ALPHA * (az - _g[2]);
            }
            var h = tiltHeading(_g[0], _g[1], _g[2], mx, my, mz);
            if (h == null) {
                continue;
            }
            if (_prevFast != null) {
                _u += wrap(h - _prevFast);
            }
            _prevFast = h;
            _ringT[_ringPos] = ts;
            _ringU[_ringPos] = _u;
            _ringPos = (_ringPos + 1) % RING;
            if (_ringLen < RING) { _ringLen += 1; }
            if (_uStart != null && ts >= _spinFromMs && ts <= _spinUntilMs) {
                _uEnd = _u;
            }
            _hist.add(_u);
            if (_hist.size() > SPIN_WINDOW + 1) {
                _hist = _hist.slice(1, null);
            }
            if (_hist.size() == SPIN_WINDOW + 1) {
                var d = absf(_hist[SPIN_WINDOW] - _hist[0]);
                if (d * FAST_RATE / SPIN_WINDOW > SPIN_RATE) {
                    _fastCount += 1;
                    if (_fastCount >= SPIN_MIN_SAMPLES) {
                        if (ts > _spinUntilMs) {
                            _spinFromMs = ts - (SPIN_WINDOW + SPIN_MIN_SAMPLES) * step - SPIN_MARGIN_MS;
                            spinsDetected += 1;
                            _uStart = uAt(_spinFromMs);
                            _uEnd = _u;
                        }
                        _spinUntilMs = ts + SPIN_HOLD_MS;
                    }
                } else {
                    _fastCount = 0;
                }
            }
        }
    }

    // Obrót z szybkich danych w chwili t (najpóźniejsza próbka nie późniejsza niż t).
    private function uAt(t as Number) as Float {
        var oldest = (_ringPos - _ringLen + RING) % RING;
        var u = _ringU[oldest];
        for (var j = 0; j < _ringLen; j++) {
            var k = (oldest + j) % RING;
            if (_ringT[k] <= t) {
                u = _ringU[k];
            }
        }
        return u;
    }

    // Kierunek z kompasu (~1 Hz). Zwraca true, gdy naliczono okrążenie.
    function addHeading(hd as Float, nowMs as Number, timerMs as Number) as Boolean {
        var counted = false;
        if (_pendHd != null) {
            if (_pendT < _spinFromMs || _pendT > _spinUntilMs) {
                counted = commit(_pendHd, _pendT, timerMs);
            } else {
                _gap = true;
            }
            _pendHd = null;
        }
        if (nowMs >= _spinFromMs && nowMs <= _spinUntilMs) {
            _gap = true;
            return counted;
        }
        _pendHd = hd;
        _pendT = nowMs;
        return counted;
    }

    private function commit(hd as Float, t as Number, timerMs as Number) as Boolean {
        if (_anchor == null) {
            _anchor = hd;
            _anchorT = t;
            return false;
        }
        var d = wrap(hd - _anchor);
        var dts = (t - _anchorT) / 1000.0;
        _anchor = hd;
        _anchorT = t;
        if (_gap) {
            if (_uStart != null) {
                // ile połówek obrotu zrobiło ciało (szybkie dane) – nieparzyste = zwrot przód/tył
                var k = Math.round((_uEnd - _uStart) / PI_F).toNumber();
                if (k % 2 != 0) {
                    backward = !backward;
                }
                d = wrap(d - k * PI_F);
                _uStart = null;
            } else {
                // brak pomiaru: ciało obróciło się o 0 albo 180°, a w tym czasie albo jechaliśmy
                // (obrót ~ tempo sprzed manewru), albo staliśmy – wybieramy lepiej pasującą wersję
                var bestD = 0.0;
                var bestR = 99.0;
                var bestFlip = false;
                var exps = [0.0, _rate * dts];
                for (var i = 0; i < 2; i++) {
                    var dd = wrap(d - exps[i]);
                    var flip = dd > FLIP_GAP_RAD || dd < -FLIP_GAP_RAD;
                    if (flip) {
                        dd = wrap(dd - PI_F);
                    }
                    if (absf(dd) < bestR) {
                        bestR = absf(dd);
                        bestD = exps[i] + dd;
                        bestFlip = flip;
                    }
                }
                if (bestFlip) {
                    backward = !backward;
                }
                d = bestD;
            }
            _gap = false;
        } else {
            if (d > FLIP_RAD || d < -FLIP_RAD) {
                // zwrot przód/tył (w którąkolwiek stronę) – kierunek jazdy się nie zmienił
                backward = !backward;
                d += (d > 0) ? -PI_F : PI_F;
            }
            if (dts > 0) {
                _rate += 0.2 * (d / dts - _rate);
            }
        }
        turn += d;
        _totalRot += absf(d);
        if (!_calReady && _totalRot >= TWO_PI_F) {
            // po pełnym obrocie zakres osi magnetometru jest znany – szybkie dane od zera
            _calReady = true;
            _prevFast = null;
            _u = 0.0;
            _hist = [];
            _ringLen = 0;
            _fastCount = 0;
        }
        if (turn >= TWO_PI_F || turn <= -TWO_PI_F) {
            // nadwyżka ponad 360° zostaje dla następnego okrążenia
            turn += (turn > 0) ? -TWO_PI_F : TWO_PI_F;
            return tryLap(timerMs, true);
        }
        return false;
    }

    // BACK: ręczne okrążenie – zeruje licznik obrotu.
    function manualLap(timerMs as Number) as Boolean {
        if (tryLap(timerMs, false)) {
            turn = 0.0;
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

    // Część bieżącego okrążenia 0..1.
    function lapFraction() as Float {
        var part = absf(turn) / TWO_PI_F;
        return part > 1.0 ? 1.0 : part;
    }
}
