import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Testy logiki mapy: źródło kierunku, zaokrąglanie, kiedy pobrać nowy obraz, ślad.

(:test)
function testHeadingSource(logger as Logger) as Boolean {
    var east = Math.toRadians(90.0);
    var north = 0.0;
    var gps = MapLogic.chooseHeading(east, 5.0, north);       // jazda: GPS
    var slow = MapLogic.chooseHeading(east, 0.5, north);      // postój: kompas
    var none = MapLogic.chooseHeading(null, 5.0, null);
    var neg = MapLogic.chooseHeading(null, 0.0, Math.toRadians(-90.0)); // -90° = 270°
    logger.debug("gps " + gps + " postój " + slow + " brak " + none + " ujemny " + neg);
    return (gps - 90).abs() < 0.01 && slow.abs() < 0.01 && none == null && (neg - 270).abs() < 0.01;
}

(:test)
function testQuantizeAndDiff(logger as Logger) as Boolean {
    var ok = MapLogic.quantize(7) == 0 && MapLogic.quantize(8) == 15 && MapLogic.quantize(359) == 0
        && MapLogic.quantize(172.6) == 180;
    ok = ok && MapLogic.angleDiff(350, 10) == 20 && MapLogic.angleDiff(10, 350) == 20 && MapLogic.angleDiff(0, 180) == 180;
    logger.debug("zaokrąglanie i różnice: " + ok);
    return ok;
}

(:test)
function testDistance(logger as Logger) as Boolean {
    // 0,001° szerokości ≈ 111 m
    var d = MapLogic.distanceM(50.0d, 19.9d, 50.001d, 19.9d);
    logger.debug("0,001° = " + d.format("%.1f") + " m");
    return d > 110 && d < 112;
}

(:test)
function testShouldRequest(logger as Logger) as Boolean {
    var m = new MapLogic();
    var lat = 50.0617d;
    var lon = 19.9373d;
    var first = m.shouldRequest(lat, lon, 0, 16, 0);
    m.markRequested(lat, lon, 0, 16, 0);
    var tooSoon = m.shouldRequest(50.0627d, lon, 0, 16, 2000);         // 111 m, ale po 2 s
    var moved = m.shouldRequest(50.0627d, lon, 0, 16, 5000);           // 111 m po 5 s
    var still = m.shouldRequest(50.0618d, lon, 0, 16, 5000);           // 11 m – nie
    var turned = m.shouldRequest(50.0618d, lon, 15, 16, 5000);         // obrót o 15° – tak
    var zoom = m.shouldRequest(lat, lon, 0, 17, 1000);                 // zmiana przybliżenia – od razu
    var old = m.shouldRequest(lat, lon, 0, 16, 61000);                 // obraz starszy niż minuta
    logger.debug("pierwszy " + first + " zaWcześnie " + tooSoon + " przesunięcie " + moved
        + " stoi " + still + " obrót " + turned + " zoom " + zoom + " stary " + old);
    return first && !tooSoon && moved && !still && turned && zoom && old;
}

(:test)
function testTrail(logger as Logger) as Boolean {
    var m = new MapLogic();
    var none = m.trailGeometry();
    // 100 punktów co ~111 m na północ
    for (var i = 0; i < 100; i++) {
        m.addTrail(50.0d + i * 0.001d, 19.9d);
        m.addTrail(50.0d + i * 0.001d + 0.00005d, 19.9d);   // ~5 m dalej – pomijany
    }
    var g = m.trailGeometry() as String;
    var points = 1;
    for (var j = 0; j < g.length(); j++) {
        if (g.substring(j, j + 1).equals(",")) { points += 1; }
    }
    points = points / 2;   // pary lon,lat
    logger.debug("ślad: " + (m.trail.size() / 2) + " punktów, w adresie " + points + ", koniec: "
        + g.substring(g.length() - 45, g.length()));
    return none == null && m.trail.size() == 200 && points == MapLogic.TRAIL_SEND
        && g.find("19.90000,50.09900;") != null && g.find("polyline:19.90000,50.00000,") == 0;
}

(:test)
function testRequestParams(logger as Logger) as Boolean {
    var m = new MapLogic();
    var p = m.requestParams(50.0617d, 19.9373d, 45, 16, 240, "osm-bright", "KLUCZ");
    logger.debug("center " + p["center"] + " bearing " + p["bearing"] + " geometry " + p.hasKey("geometry"));
    return p["center"].equals("lonlat:19.93730,50.06170") && p["bearing"].equals("45")
        && p["zoom"].equals("16") && p["width"].equals("240") && !p.hasKey("geometry");
}
