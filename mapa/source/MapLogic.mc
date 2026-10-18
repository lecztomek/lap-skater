import Toybox.Lang;
import Toybox.Math;

// Logika mapy bez czujników i sieci – testowana w MapaTest.mc.
// Forerunner 245 nie obraca bitmap, więc obrót robi serwis map (Geoapify, parametr bearing):
// prosimy o obraz już obrócony wg kierunku jazdy, z naszym śladem narysowanym przez serwer.
class MapLogic {
    static const MIN_SPEED_GPS = 1.5;   // m/s – szybciej: kierunek z GPS (stabilny w ruchu), wolniej: kompas
    static const BEARING_STEP = 15;     // stopnie – zaokrąglenie, żeby nie pobierać obrazu przy każdym drgnięciu
    static const MOVE_M = 40.0;         // nowy obraz po takim przesunięciu
    static const MIN_INTERVAL_MS = 4000;
    static const MAX_AGE_MS = 60000;
    static const TRAIL_STEP_M = 20.0;
    static const TRAIL_MAX = 300;
    static const TRAIL_SEND = 30;       // tyle punktów śladu w adresie (długość URL)

    // stan ostatniego zapytania
    private var _lastLat = null;
    private var _lastLon = null;
    private var _lastBearing as Number = -1;
    private var _lastZoom as Number = -1;
    private var _lastMs as Number = 0;
    // ślad [lat, lon, lat, lon, ...]
    var trail as Array<Double> = [];

    function initialize() {
    }

    // Odległość w metrach (przybliżenie równoprostokątne – na kilkadziesiąt metrów w zupełności).
    static function distanceM(lat1 as Double, lon1 as Double, lat2 as Double, lon2 as Double) as Double {
        var r = 6371000.0d;
        var k = 3.141592653589793d / 180.0d;
        var x = (lon2 - lon1) * k * Math.cos((lat1 + lat2) / 2.0d * k);
        var y = (lat2 - lat1) * k;
        return Math.sqrt(x * x + y * y) * r;
    }

    // Kierunek do obrócenia mapy [stopnie, 0 = północ] albo null, gdy nie wiadomo.
    static function chooseHeading(gpsHeadingRad, speedMs, compassRad) {
        var rad = null;
        if (gpsHeadingRad != null && speedMs != null && speedMs >= MIN_SPEED_GPS) {
            rad = gpsHeadingRad;
        } else if (compassRad != null) {
            rad = compassRad;
        }
        if (rad == null) {
            return null;
        }
        var deg = Math.toDegrees(rad.toDouble());
        while (deg < 0) { deg += 360; }
        while (deg >= 360) { deg -= 360; }
        return deg;
    }

    static function quantize(deg as Numeric) as Number {
        var q = Math.round(deg.toFloat() / BEARING_STEP).toNumber() * BEARING_STEP;
        return q % 360;
    }

    static function angleDiff(a as Number, b as Number) as Number {
        var d = (a - b).abs() % 360;
        return d > 180 ? 360 - d : d;
    }

    // Czy pobrać nowy obraz mapy.
    function shouldRequest(lat as Double, lon as Double, bearing as Number, zoom as Number, nowMs as Number) as Boolean {
        if (_lastLat == null) {
            return true;
        }
        if (zoom != _lastZoom) {
            return true;    // zmiana przybliżenia – od razu
        }
        if (nowMs - _lastMs < MIN_INTERVAL_MS) {
            return false;
        }
        return distanceM(_lastLat, _lastLon, lat, lon) >= MOVE_M
            || angleDiff(bearing, _lastBearing) >= BEARING_STEP
            || nowMs - _lastMs >= MAX_AGE_MS;
    }

    function markRequested(lat as Double, lon as Double, bearing as Number, zoom as Number, nowMs as Number) as Void {
        _lastLat = lat;
        _lastLon = lon;
        _lastBearing = bearing;
        _lastZoom = zoom;
        _lastMs = nowMs;
    }

    // Dodaje punkt śladu co TRAIL_STEP_M.
    function addTrail(lat as Double, lon as Double) as Void {
        var n = trail.size();
        if (n >= 2 && distanceM(trail[n - 2], trail[n - 1], lat, lon) < TRAIL_STEP_M) {
            return;
        }
        trail.add(lat);
        trail.add(lon);
        if (trail.size() > TRAIL_MAX * 2) {
            trail = trail.slice(2, null);
        }
    }

    // Ślad dla Geoapify: "polyline:lon,lat,...;linecolor:#d32f2f;linewidth:4" (najwyżej TRAIL_SEND punktów,
    // równomiernie wybranych, ostatni zawsze). null, gdy za mało punktów.
    function trailGeometry() {
        var n = trail.size() / 2;
        if (n < 2) {
            return null;
        }
        var count = n < TRAIL_SEND ? n : TRAIL_SEND;
        var s = "polyline:";
        for (var i = 0; i < count; i++) {
            // indeksy od najstarszego do najnowszego, ostatni = n-1
            var idx = count == 1 ? n - 1 : (i * (n - 1)) / (count - 1);
            if (i > 0) { s += ","; }
            s += trail[idx * 2 + 1].format("%.5f") + "," + trail[idx * 2].format("%.5f");
        }
        return s + ";linecolor:#d32f2f;linewidth:4";
    }

    // Parametry zapytania o obraz mapy.
    function requestParams(lat as Double, lon as Double, bearing as Number, zoom as Number,
            size as Number, style as String, apiKey as String) as Dictionary {
        var p = {
            "style" => style,
            "width" => size.toString(),
            "height" => size.toString(),
            "center" => "lonlat:" + lon.format("%.5f") + "," + lat.format("%.5f"),
            "zoom" => zoom.toString(),
            "bearing" => bearing.toString(),
            "format" => "png",
            "apiKey" => apiKey
        };
        var g = trailGeometry();
        if (g != null) {
            p.put("geometry", g);
        }
        return p;
    }
}
