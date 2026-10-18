import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Pozycja, kierunek i pobieranie obrazu mapy przez telefon (Geoapify Static Maps).
class MapaController {
    static const URL = "https://maps.geoapify.com/v1/staticmap";
    static const ZOOM_MIN = 12;
    static const ZOOM_MAX = 18;
    static const RETRY_MS = 15000;

    var logic as MapLogic = new MapLogic();
    var bitmap = null;
    var lat = null;
    var lon = null;
    var speed as Float = 0.0;
    var heading = null;          // stopnie, kierunek jazdy / zegarka
    var headingUp as Boolean = true;   // mapa wg kierunku jazdy; false = północ u góry
    var zoom as Number = 16;
    var status as Symbol = :gps;       // :gps, :nokey, :loading, :ok, :error
    var errorCode as Number = 0;
    var shownBearing as Number = 0;    // obrót obrazu, który jest na ekranie
    private var _pending as Boolean = false;
    private var _lastFailMs as Number = -100000;
    private var _compass = null;
    private var _apiKey as String = "";
    private var _style as String = "osm-bright";
    private var _timer as Timer.Timer?;

    function initialize() {
        var z = Application.Storage.getValue("zoom");
        if (z != null) {
            zoom = z as Number;
        }
        var hu = Application.Storage.getValue("headingUp");
        if (hu != null) {
            headingUp = hu as Boolean;
        }
        readSettings();
    }

    function readSettings() as Void {
        var k = Application.Properties.getValue("apiKey");
        _apiKey = k == null ? "" : (k as String);
        var s = Application.Properties.getValue("style");
        _style = (s == null || (s as String).length() == 0) ? "osm-bright" : (s as String);
    }

    function start() as Void {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        Sensor.enableSensorEvents(method(:onSensor));
        _timer = new Timer.Timer();
        _timer.start(method(:tick), 1000, true);
    }

    function stop() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        Sensor.enableSensorEvents(null);
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onPosition(info as Position.Info) as Void {
        if (info.position == null || info.accuracy < Position.QUALITY_POOR) {
            return;
        }
        var deg = info.position.toDegrees();
        lat = deg[0].toDouble();
        lon = deg[1].toDouble();
        speed = info.speed == null ? 0.0 : info.speed.toFloat();
        heading = MapLogic.chooseHeading(info.heading, info.speed, _compass);
        logic.addTrail(lat, lon);
    }

    function onSensor(info as Sensor.Info) as Void {
        _compass = info.heading;
        if (speed < MapLogic.MIN_SPEED_GPS) {
            heading = MapLogic.chooseHeading(null, 0.0, _compass);
        }
    }

    function bearing() as Number {
        if (!headingUp || heading == null) {
            return 0;
        }
        return MapLogic.quantize(heading);
    }

    // Co sekundę: czy pobrać nowy obraz.
    function tick() as Void {
        if (_apiKey.length() == 0) {
            status = :nokey;
        } else if (lat == null) {
            status = :gps;
        } else if (!_pending) {
            var now = System.getTimer();
            var b = bearing();
            if (now - _lastFailMs >= RETRY_MS && logic.shouldRequest(lat, lon, b, zoom, now)) {
                request(b, now);
            }
        }
        WatchUi.requestUpdate();
    }

    private function request(b as Number, now as Number) as Void {
        var size = System.getDeviceSettings().screenWidth;
        var params = logic.requestParams(lat, lon, b, zoom, size, _style, _apiKey);
        logic.markRequested(lat, lon, b, zoom, now);
        _pending = true;
        _requestBearing = b;
        if (bitmap == null) {
            status = :loading;
        }
        Communications.makeImageRequest(URL, params, {
            :maxWidth => size,
            :maxHeight => size,
            :dithering => Communications.IMAGE_DITHERING_FLOYD_STEINBERG
        }, method(:onImage));
    }

    private var _requestBearing as Number = 0;

    function onImage(code as Number, data as WatchUi.BitmapResource or Graphics.BitmapReference or Null) as Void {
        _pending = false;
        if (code == 200 && data != null) {
            bitmap = data;
            shownBearing = _requestBearing;
            status = :ok;
        } else {
            _lastFailMs = System.getTimer();
            errorCode = code;
            if (bitmap == null) {
                status = :error;
            }
        }
        WatchUi.requestUpdate();
    }

    function zoomIn() as Void {
        if (zoom < ZOOM_MAX) {
            zoom += 1;
            Application.Storage.setValue("zoom", zoom);
        }
    }

    function zoomOut() as Void {
        if (zoom > ZOOM_MIN) {
            zoom -= 1;
            Application.Storage.setValue("zoom", zoom);
        }
    }

    function toggleMode() as Void {
        headingUp = !headingUp;
        Application.Storage.setValue("headingUp", headingUp);
    }
}
