import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Testy LapCounter na syntetycznych danych: owal 60x30 (proste 30 m, łuki r=12 m), zegarek na
// nadgarstku, kompas 1 Hz i szybkie dane 25 Hz (akcelerometr + magnetometr). Uruchamiane w CI
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
    var fast as Boolean = true;        // czy są szybkie dane
    var hardIron as Array<Float> = [0.0, 0.0, 0.0]; // magnetyzm zegarka (brak kalibracji)
    // manewry: [start s, obrót rad, czas s, jedzie?]
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

    // wektor świata -> układ zegarka: R = Rz(yaw) * Ry(pitch), zegarek widzi R^T v
    private function toDev(v as Array<Float>, yaw as Float, pitch as Float) as Array<Float> {
        var cz = Math.cos(yaw);
        var sz = Math.sin(yaw);
        var cp = Math.cos(pitch);
        var sp = Math.sin(pitch);
        var x1 = cz * v[0] + sz * v[1];
        var y1 = -sz * v[0] + cz * v[1];
        var z1 = v[2];
        return [cp * x1 - sp * z1, y1, sp * x1 + cp * z1];
    }

    function run(c as LapCounter, manualAt as Array<Number>) as LapCounter {
        var rng = new Rng(seed);
        var total = laps * lapLen();
        var dt = 1.0 / LapCounter.FAST_RATE;
        var t = 0.0;
        var sd = 0.0;
        var extra = 0.0;
        var sec = 0;
        var sw = Math.toRadians(swingDeg);
        var dist0 = Math.toRadians(distortDeg);
        var nz = Math.toRadians(noiseDeg);
        var ax = [], ay = [], az = [], mx = [], my = [], mz = [];
        while (sd < total) {
            var moving = true;
            for (var i = 0; i < events.size(); i++) {
                var e = events[i] as Array;
                if (t >= e[0] && t < e[0] + e[2]) {
                    extra += e[1] / e[2] * dt;
                    moving = e[3];
                }
            }
            if (moving) { sd += speed * dt; }
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
            if (fast) {
                var a = toDev([0.0, 0.0, 1000.0], yaw, swingNow);
                ax.add(a[0] + rng.gauss() * 30);
                ay.add(a[1] + rng.gauss() * 30);
                az.add(a[2] + rng.gauss() * 30);
                var m = toDev([20.0 * Math.cos(-dist), 20.0 * Math.sin(-dist), -45.0], yaw, swingNow);
                mx.add(m[0] + hardIron[0]);
                my.add(m[1] + hardIron[1]);
                mz.add(m[2] + hardIron[2]);
            }
            if (ms >= (sec + 1) * 1000) {
                sec += 1;
                if (fast) {
                    c.addFastSamples(ax, ay, az, mx, my, mz, ms);
                    ax = []; ay = []; az = []; mx = []; my = []; mz = [];
                }
                var hd = LapCounter.wrap((yaw + dist + rng.gauss() * nz).toFloat());
                c.addHeading(hd, ms, ms);
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
                    + " (manewry " + c.spinsDetected + ", odrzucone " + c.rejectedLaps + ")");
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
function testBackwardWithoutFastData(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.fast = false;
    s.events = [[60.0, p, 0.4, true], [110.0, p, 0.4, true]];
    return LapTests.check(logger, "tyłem bez szybkich danych", s, 10, 3);
}

(:test)
function testSpinExitBackward(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.events = [[80.0, 2.5 * 2 * p, 1.0, false], [150.0, p, 0.5, true]];
    return LapTests.check(logger, "piruet z wyjściem tyłem", s, 10, 5);
}

(:test)
function testUncalibratedMagnetometer(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.hardIron = [30.0, 25.0, -20.0];
    s.events = LapTests.spins([50, 140, 250], 3, 1.0);
    s.events.addAll([[60.0, p, 0.5, true], [110.0, p, 0.5, true]]);
    return LapTests.check(logger, "nieskalibrowany magnetometr", s, 10, 5);
}

(:test)
function testManeuverInFirstLap(logger as Logger) as Boolean {
    var s = LapTests.noisy();
    var p = LapTests.PI_F;
    s.hardIron = [12.0, -8.0, 6.0];
    s.events = [[15.0, p, 0.5, true], [25.0, p, 0.5, true]];
    return LapTests.check(logger, "manewr w pierwszym okrążeniu", s, 10, 5);
}

(:test)
function testHeavySwingWithManeuvers(logger as Logger) as Boolean {
    var s = new RinkSim();
    var p = LapTests.PI_F;
    s.swingDeg = 50.0;
    s.distortDeg = 30.0;
    s.noiseDeg = 6.0;
    s.events = LapTests.spins([50, 250], 3, 1.0);
    s.events.addAll([[60.0, p, 0.5, true], [110.0, p, 0.5, true]]);
    return LapTests.check(logger, "mocne machanie + manewry", s, 10, 5);
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
        c.addHeading(hd, 102000 + i * 1000, 102000 + i * 1000);
    }
    logger.debug("wzorzec " + ref + " ms, okrążenia " + c.laps + ", odrzucone " + c.rejectedLaps);
    return ref == 34000 && c.laps == 3 && c.rejectedLaps == 1;
}
