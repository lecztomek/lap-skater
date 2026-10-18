import Toybox.Lang;
import Toybox.Test;

// Testy pola Rower Moc: statystyki mocy. (Test pola z kanałem ANT+ wysypywał symulator w CI.)

(:test)
function testPowerSmoothing(logger as Logger) as Boolean {
    var s = new PowerStats();
    s.add(100);
    s.add(200);
    s.add(300);
    s.add(400);   // średnia z 3 ostatnich: 300
    logger.debug("3 s: " + s.smoothed() + ", śr " + s.average() + ", maks " + s.max);
    return s.smoothed() == 300 && s.average() == 250 && s.max == 400;
}

(:test)
function testPowerDropout(logger as Logger) as Boolean {
    var s = new PowerStats();
    s.add(150);
    s.add(null);
    s.add(null);
    var stillOk = s.hasData();     // 2 s bez danych – jeszcze tak
    s.add(null);
    var lost = !s.hasData();       // 3 s – czujnik zgubiony
    s.add(160);
    var back = s.hasData();
    logger.debug("zanik: " + stillOk + " " + lost + " " + back + ", śr " + s.average());
    // średnia liczy tylko odczyty (bez dziur): (150+160)/2
    return stillOk && lost && back && s.average() == 155;
}

(:test)
function testPowerZerosCount(logger as Logger) as Boolean {
    // zjazd bez pedałowania (0 W) wlicza się do średniej, jak w licznikach rowerowych
    var s = new PowerStats();
    s.add(200);
    s.add(0);
    s.add(0);
    s.add(200);
    logger.debug("z zerami: śr " + s.average());
    return s.average() == 100;
}
