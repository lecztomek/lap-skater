import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

class MapaView extends WatchUi.View {
    private var _m as MapaController;

    function initialize(m as MapaController) {
        View.initialize();
        _m = m;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_m.bitmap != null) {
            dc.drawBitmap(0, 0, _m.bitmap);
            drawArrow(dc, cx, cy);
            drawInfo(dc, w, h);
            if (_m.status == :error || _m.errorCode != 0 && _m.status != :ok) {
                small(dc, cx, h * 0.80, "HTTP " + _m.errorCode, Graphics.COLOR_RED);
            }
            return;
        }

        var msg;
        if (_m.status == :nokey) {
            msg = WatchUi.loadResource(Rez.Strings.NoKey) as String;
        } else if (_m.status == :gps) {
            msg = WatchUi.loadResource(Rez.Strings.WaitGps) as String;
        } else if (_m.status == :error) {
            msg = (_m.errorCode == -104 || _m.errorCode == -2)
                ? (WatchUi.loadResource(Rez.Strings.NoPhone) as String)
                : "HTTP " + _m.errorCode;
        } else {
            msg = WatchUi.loadResource(Rez.Strings.Loading) as String;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.AppVersion) as String,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Strzałka pozycji: w trybie "wg kierunku" względem obrotu obrazu na ekranie,
    // w trybie "północ u góry" – obrócona o kierunek jazdy.
    private function drawArrow(dc as Dc, cx as Number, cy as Number) as Void {
        var deg = 0.0;
        if (_m.heading != null) {
            deg = _m.heading - _m.shownBearing;
        }
        var a = Math.toRadians(deg);
        var s = Math.sin(a);
        var c = Math.cos(a);
        // strzałka w górę: czubek, prawy róg, wcięcie, lewy róg
        var pts = [[0, -14], [9, 10], [0, 5], [-9, 10]];
        var poly = [];
        for (var i = 0; i < pts.size(); i++) {
            var x = pts[i][0];
            var y = pts[i][1];
            poly.add([cx + x * c - y * s, cy + x * s + y * c]);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 13);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(poly);
    }

    private function drawInfo(dc as Dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        // u góry: tryb i przybliżenie; na dole: prędkość
        var mode = _m.headingUp ? "^" : "N";
        small(dc, cx, h * 0.04, mode + "  z" + _m.zoom, Graphics.COLOR_BLACK);
        small(dc, cx, h * 0.88, (_m.speed * 3.6).format("%.0f") + " km/h", Graphics.COLOR_BLACK);
    }

    // tekst na białym tle (czytelny na mapie)
    private function small(dc as Dc, x, y, text as String, color) as Void {
        var dims = dc.getTextDimensions(text, Graphics.FONT_XTINY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - dims[0] / 2 - 4, y, dims[0] + 8, dims[1], 4);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
