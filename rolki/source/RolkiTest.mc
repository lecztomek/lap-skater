import Toybox.Lang;
import Toybox.Test;

// Testy Rolek: automatyczne okrążenie co 1 km i test dymny sesji (GPS + nagrywanie).

(:test)
function testAutoLapEveryKm(logger as Logger) as Boolean {
    var a = new AutoLap();
    var laps = 0;
    // 5,5 km co 7 m (ok. 25 km/h, próbka co sekundę)
    for (var d = 0.0; d <= 5500.0; d += 7.0) {
        if (a.check(d)) { laps += 1; }
    }
    logger.debug("okrążenia po 5,5 km: " + laps);
    return laps == 5 && a.laps == 5;
}

(:test)
function testAutoLapAfterManual(logger as Logger) as Boolean {
    var a = new AutoLap();
    a.check(400.0);
    a.manual(400.0);                   // ręczne okrążenie na 400 m
    var early = a.check(1300.0);       // 900 m od ręcznego – jeszcze nie
    var due = a.check(1401.0);         // 1001 m od ręcznego – tak
    logger.debug("po ręcznym: " + early + " " + due + ", okrążenia " + a.laps);
    return !early && due && a.laps == 2;
}

(:test)
function testAutoLapNoDoubleOnJump(logger as Logger) as Boolean {
    // skok GPS o 2,5 km w jednej próbce – jedno okrążenie na próbkę, reszta przy kolejnych
    var a = new AutoLap();
    var n = 0;
    if (a.check(2500.0)) { n += 1; }
    if (a.check(2500.0)) { n += 1; }
    if (a.check(2500.0)) { n += 1; }
    logger.debug("skok: " + n);
    return n == 2;
}

(:test)
function testRolkiSessionSmoke(logger as Logger) as Boolean {
    var s = new RolkiSession();
    s.enableSensors();
    s.start();
    s.update();
    s.lap();
    s.stop();
    s.discard();
    s.disableSensors();
    logger.debug("sesja OK");
    return true;
}
