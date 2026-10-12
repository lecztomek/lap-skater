import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Testy LapCounter na syntetycznych danych: owal 60x30 (proste 30 m, łuki r=12 m), zegarek na
// nadgarstku, kompas 1 Hz (z zakłóceniami hali, machaniem ręką i szumem). Uruchamiane w CI
// (monkeyc --unit-test + symulator). Każdy scenariusz jedzie N,5 okrążenia -> oczekujemy N.

(:test)
class Rng {
    private var _x as Number;

    function initialize(seed as Number) {
        _x = seed;
    }

    // LCG; wynik 0..1
    function next() as Float {
        _x = (_x * 1103515245 + 12345) & 0x7fffffff;
        return _x / 2147483648.0;
    }

    // ~N(0,1)
    function gauss() as Float {
        return (next() + next() + next() + next() - 2.0) * 1.7320508;
    }
}

(:test)
class RinkSim {
    static const STRAIGHT = 30.0;
    static const R = 12.0;
    static const PI_F = 3.1415927;

    var laps as Float = 10.5;
    var speed as Float = 4.0;          // m/s
    var swingDeg as Float = 0.0;       // machanie ręką (pochylenie)
    var distortDeg as Float = 0.0;     // zakłócenia magnetyczne hali
    var noiseDeg as Float = 0.0;       // szum kompasu
    var clockwise as Boolean = false;
    var offset as Float = 0.0;         // obrót całej tafli względem północy
    // manewry: [start s, obrót rad, czas s, jedzie?(, zmiana kierunku jazdy?)]
    var events as Array = [];
    var seed as Number = 1;

    function initialize() {
    }

    function lapLen() as Float {
        return 2 * STRAIGHT + 2 * PI_F * R;
    }

    // [x, y, kierunek jazdy]
    private function path(sd as Float) as Array<Float> {
        var p = sd - Math.floor(sd / lapLen()) * lapLen();
        if (p < STRAIGHT) { return [p - 15.0, -R, 0.0]; }
        p -= STRAIGHT;
        if (p < PI_F * R) { var a = p / R; return [15.0 + R * Math.sin(a), -R * Math.cos(a), a]; }
        p -= PI_F * R;
        if (p < STRAIGHT) { return [15.0 - p, R, PI_F]; }
        p -= STRAIGHT;
        var b = p / R;
        return [-15.0 - R * Math.sin(b), R * Math.cos(b), PI_F + b];
    }

    function run(c as LapCounter, manualAt as Array<Number>) as LapCounter {
        var rng = new Rng(seed);
        var total = laps * lapLen();
        var dt = 0.04;   // krok symulacji 25 Hz, kompas co 1 s
        var t = 0.0;
        var sd = 0.0;
        var extra = 0.0;
        var sec = 0;
        var sw = Math.toRadians(swingDeg);
        var dist0 = Math.toRadians(distortDeg);
        var nz = Math.toRadians(noiseDeg);
        var dirSign = 1.0;
        var trav = 0.0;
        var reversed = [];
        while (trav < total) {
            var moving = true;
            for (var i = 0; i < events.size(); i++) {
                var e = events[i] as Array;
                if (t >= e[0] && t < e[0] + e[2]) {
                    extra += e[1] / e[2] * dt;
                    moving = e[3];
                    if (e.size() > 4 && e[4] && reversed.indexOf(i) < 0) {
                        reversed.add(i);
                        dirSign = -dirSign;   // nawrót: od teraz jedziemy owalem w drugą stronę
                    }
                }
            }
            if (moving) {
                sd += dirSign * speed * dt;
                trav += speed * dt;
            }
            var pt = path(sd);
            var x = pt[0];
            var y = pt[1];
            var h = pt[2];
            if (clockwise) { h = -h; y = -y; }
            var dist = dist0 * Math.sin(x / 7.0) * Math.cos(y / 5.0);
            var swingNow = sw * Math.sin(2.7 * t);
            var yaw = h + extra + offset + 0.3 * swingNow;   // nadgarstek trochę skręca przy machaniu
            t += dt;
            var ms = Math.round(t * 1000).toNumber();
            if (ms >= (sec + 1) * 1000) {
                sec += 1;
                var hd = LapCounter.wrap((yaw + dist + rng.gauss() * nz).toFloat());
                c.addHeading(hd, ms);
                for (var j = 0; j < manualAt.size(); j++) {
                    if (manualAt[j] == sec) { c.manualLap(ms); }
                }
            }
        }
        return c;
    }
}

(:test)
module LapTests {
    const PI_F = 3.1415927;

    function spins(times as Array<Number>, revs as Number, dur as Float) as Array {
        var out = [];
        for (var i = 0; i < times.size(); i++) {
            out.add([times[i].toFloat(), revs * 2 * PI_F * (i % 2 == 0 ? 1 : -1), dur, false]);
        }
        return out;
    }

    // Uruchamia scenariusz dla kilku ziaren losowych; każde musi dać dokładnie expected.
    function check(logger as Logger, name as String, sim as RinkSim, expected as Number, seeds as Number) as Boolean {
        var ok = true;
        for (var s = 1; s <= seeds; s++) {
            sim.seed = s;
            var c = sim.run(new LapCounter(), []);
            if (c.laps != expected) {
                logger.error(name + " seed " + s + ": " + c.laps + " zamiast " + expected
                    + " (odrzucone " + c.rejectedLaps + ", nawroty " + c.reversals + ")");
                ok = false;
            }
        }
        if (ok) {
            logger.debug(name + ": OK (" + seeds + " przebiegów)");
        }
        return ok;
    }

    // Zmiana kierunku: liczy się suma (pełne + carry + bieżące) – prawda to laps symulacji.
    function checkTotal(logger as Logger, name as String, sim as RinkSim, tolerance as Float, seeds as Number) as Boolean {
        var ok = true;
        for (var s = 1; s <= seeds; s++) {
            sim.seed = s;
            var c = sim.run(new LapCounter(), []);
            var err = (c.totalLaps() - sim.laps).abs();
            if (err > tolerance || c.reversals != 2) {
                logger.error(name + " seed " + s + ": suma " + c.totalLaps().format("%.2f") + " zamiast "
                    + sim.laps + ", nawroty " + c.reversals);
                ok = false;
            }
        }
        if (ok) {
            logger.debug(name + ": OK (" + seeds + " przebiegów)");
        }
        return ok;
    }

    function noisy() as RinkSim {
        var s = new RinkSim();
        s.swingDeg = 20.0;
        s.distortDeg = 30.0;
        s.noiseDeg = 4.0;
        return s;
    }
}

(:test)
function testWrap(logger as Logger) as Boolean {
    var w1 = LapCounter.wrap(3.5);
    var w2 = LapCounter.wrap(-3.5);
    var w3 = LapCounter.wrap(7.0);
    logger.debug("wrap: " + w1 + " " + w2 + " " + w3);
    return (w1 + 2.7831853).abs() < 0.001 && (w2 - 2.7831853).abs() < 0.001 && (w3 - 0.7168147).abs() < 0.001;
}

(:test)
function testCleanOval(logger as Logger) as Boolean {
    return LapTests.check(logger, "czysty owal", new RinkSim(), 10, 3);
}

(:test)
function testNoiseAndDistortion(logger as Logger) as Boolean {
    var s = new RinkSim();
    s.swingDeg = 35.0;
    s.distortDeg = 40.0;
    s.noiseDeg = 5.0;
    return LapTests.check(logger, "zakłócenia + machanie", s, 10, 5);
}

(:test)
function testNorthOffset(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    s.offset = 3.0;   // przejście przez północ (±180°) w innym miejscu tafli
    return LapTests.check(logger, "przesunięcie północy", s, 10, 3);
}

(:test)
function testClockwise(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    s.clockwise = true;
    return LapTests.check(logger, "zgodnie z zegarem", s, 10, 3);
}

(:test)
function testFast(logger as Logger) as Boolean {
    var s = new RinkSim();
    s.speed = 7.0;
    s.swingDeg = 35.0;
    s.distortDeg = 40.0;
    s.noiseDeg = 5.0;
    return LapTests.check(logger, "szybko 7 m/s", s, 10, 5);
}

(:test)
function testSlow(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    s.speed = 2.0;
    s.laps = 6.5;
    return LapTests.check(logger, "wolno 2 m/s", s, 6, 3);
}

(:test)
function testSpins(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    s.events = LapTests.spins([50, 95, 140, 190, 250, 300], 3, 1.0);
    return LapTests.check(logger, "6 piruetów", s, 10, 5);
}

(:test)
function testSpinsRightAfterLap(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    s.events = LapTests.spins([36, 70, 104], 2, 0.7);
    return LapTests.check(logger, "piruety tuż po okrążeniu", s, 10, 5);
}

(:test)
function testBackwardSameDirection(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.events = [[60.0, p, 0.5, true], [110.0, p, 0.5, true], [200.0, p, 0.6, true], [260.0, p, 0.6, true]];
    return LapTests.check(logger, "tyłem, obroty w tę samą stronę", s, 10, 5);
}

(:test)
function testBackwardOppositeDirection(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.events = [[60.0, p, 0.5, true], [110.0, -p, 0.5, true], [200.0, -p, 0.6, true], [260.0, p, 0.6, true]];
    return LapTests.check(logger, "tyłem, obroty w przeciwne strony", s, 10, 5);
}

(:test)
function testSpinExitBackward(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.events = [[80.0, 2.5 * 2 * p, 1.0, false], [150.0, p, 0.5, true]];
    return LapTests.check(logger, "piruet z wyjściem tyłem", s, 10, 5);
}

(:test)
function testManualLap(logger as Logger) as Boolean {
    var c = new LapCounter();
    var ok = c.manualLap(10000) && c.laps == 1;
    ok = ok && !c.manualLap(13000);          // podwójne kliknięcie (< 8 s) – ignorowane
    ok = ok && c.manualLap(45000) && c.laps == 2 && c.turn == 0.0;
    logger.debug("ręczne okrążenia: " + c.laps);
    return ok;
}

(:test)
function testManualLapDuringSkating(logger as Logger) as Boolean {
    // ręczne okrążenie w połowie drogi zeruje obrót – automatyczne liczą się dalej od tego miejsca
    var s = LapTests.noisy();
    s.seed = 1;
    var c = s.run(new LapCounter(), [17]);
    logger.debug("ręczne w połowie 1. okrążenia: " + c.laps);
    return c.laps == 10 || c.laps == 11;
}

(:test)
function testReferenceRejectsTooShortLap(logger as Logger) as Boolean {
    // wzorzec z ręcznych okrążeń ~34 s; automatyczne po 12 s ma być odrzucone
    var c = new LapCounter();
    c.manualLap(34000);
    c.manualLap(68000);
    c.manualLap(102000);
    var ref = c.referenceLapMs();
    // obrót o pełne 360° w 12 s (12 próbek po 30°)
    var hd = 0.0;
    c.hold(hd);
    for (var i = 1; i <= 14; i++) {
        hd = LapCounter.wrap(hd + 0.5235988);
        c.addHeading(hd, 102000 + i * 1000);
    }
    logger.debug("wzorzec " + ref + " ms, okrążenia " + c.laps + ", odrzucone " + c.rejectedLaps);
    return ref == 34000 && c.laps == 3 && c.rejectedLaps == 1;
}

// Typowa sesja: jazda w jedną stronę, po ~kilku minutach zmiana kierunku i z powrotem.
// 30,5 okrążenia, dwa nawroty; suma ma się zgadzać z dokładnością do 1 okrążenia.
(:test)
function testDirectionChangeFastTurn(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.laps = 30.5;
    s.events = [[340.0, p, 0.8, true, true], [700.0, -p, 0.8, true, true]];
    return LapTests.checkTotal(logger, "zmiana kierunku, szybki nawrót", s, 1.0, 3);
}

(:test)
function testDirectionChangeSlowTurn(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.laps = 30.5;
    s.events = [[340.0, -p, 3.0, true, true], [700.0, -p, 3.0, true, true]];
    return LapTests.checkTotal(logger, "zmiana kierunku, wolny nawrót", s, 1.0, 3);
}

(:test)
function testDirectionChangeWithManeuvers(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.laps = 30.5;
    s.events = [[150.0, 6 * p, 1.0, false], [340.0, p, 0.8, true, true], [450.0, p, 0.5, true],
        [500.0, p, 0.5, true], [700.0, -p, 0.8, true, true], [850.0, -4 * p, 1.0, false]];
    return LapTests.checkTotal(logger, "zmiana kierunku + piruety + tyłem", s, 1.0, 3);
}

// Test dymny prawdziwej sesji (czujniki + nagrywanie) – łapie błędy poza samym algorytmem.
(:test)
function testSessionSmoke(logger as Logger) as Boolean {
    var s = new SkateSession();
    logger.debug("enableSensors");
    s.enableSensors();
    logger.debug("start");
    s.start();
    logger.debug("heading");
    for (var i = 0; i < 5; i++) {
        s.counter.addHeading(0.1 * i, 1000 * (i + 1));
    }
    s.update();
    logger.debug("lap / stop / discard");
    s.lap();
    s.stop();
    s.discard();
    s.disableSensors();
    return true;
}
