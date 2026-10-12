import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Timer;
import Toybox.WatchUi;

class RolkiView extends WatchUi.View {
    private var _s as RolkiSession;
    private var _timer as Timer.Timer?;
    private var _details as Boolean = false;

    function initialize(s as RolkiSession) {
        View.initialize();
        _s = s;
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function togglePage() as Void {
        _details = !_details;
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        _s.update();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (!_s.hasSession()) {
            drawStart(dc);
        } else if (_details) {
            drawDetails(dc);
        } else {
            drawSimple(dc);
        }
    }

    // kropka GPS: zielona – OK, żółta – słaby, czerwona – brak
    private function drawGpsDot(dc as Dc, x as Number, y as Number) as Void {
        var q = _s.gpsQuality;
        var c = q >= Position.QUALITY_GOOD ? Graphics.COLOR_GREEN
            : (q >= Position.QUALITY_USABLE ? Graphics.COLOR_YELLOW : Graphics.COLOR_RED);
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 5);
    }

    private function drawStart(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(_s.justSaved ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var msg = _s.justSaved ? Rez.Strings.Saved : Rez.Strings.PressStart;
        dc.drawText(cx, h / 2, Graphics.FONT_LARGE, WatchUi.loadResource(msg) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(_s.gpsReady() ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        var gps = _s.gpsReady() ? Rez.Strings.GpsOk : Rez.Strings.GpsWait;
        dc.drawText(cx, h * 0.68, Graphics.FONT_SMALL, WatchUi.loadResource(gps) as String, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.AppVersion) as String, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Główny ekran: czas, duży dystans, prędkość.
    private function drawSimple(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var info = Activity.getActivityInfo();
        var paused = !_s.isRecording();

        drawGpsDot(dc, cx, (h * 0.07).toNumber());
        dc.setColor(paused ? Graphics.COLOR_YELLOW : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var top = paused ? (WatchUi.loadResource(Rez.Strings.Paused) as String) : fmtTime(val(info != null ? info.timerTime : null, 0));
        dc.drawText(cx, h * 0.13, Graphics.FONT_MEDIUM, top, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.48, Graphics.FONT_NUMBER_HOT, (_s.distance() / 1000.0).format("%.2f"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.62, Graphics.FONT_XTINY, "km", Graphics.TEXT_JUSTIFY_CENTER);

        var speed = val(info != null ? info.currentSpeed : null, 0.0) * 3.6;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.72, Graphics.FONT_MEDIUM, speed.format("%.1f") + " km/h", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Drugi ekran (UP/DOWN): tętno, kalorie, średnia, maks., bieżący kilometr.
    private function drawDetails(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var info = Activity.getActivityInfo();
        var hr = info != null ? info.currentHeartRate : null;
        var cal = val(info != null ? info.calories : null, 0);
        var avg = val(info != null ? info.averageSpeed : null, 0.0) * 3.6;
        var max = val(info != null ? info.maxSpeed : null, 0.0) * 3.6;

        drawGpsDot(dc, cx, (h * 0.07).toNumber());
        cell(dc, w * 0.30, h * 0.20, "HR", hr != null ? hr.toString() : "--", Graphics.COLOR_RED);
        cell(dc, w * 0.70, h * 0.20, "kcal", cal.toString(), Graphics.COLOR_ORANGE);
        cell(dc, w * 0.30, h * 0.45, "śr km/h", avg.format("%.1f"), Graphics.COLOR_WHITE);
        cell(dc, w * 0.70, h * 0.45, "maks", max.format("%.1f"), Graphics.COLOR_WHITE);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.72, Graphics.FONT_SMALL, "km " + (_s.autoLap.laps + 1) + ": "
            + (_s.autoLap.lapDistance(_s.distance()) / 1000.0).format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // etykieta i wartość jedna pod drugą
    private function cell(dc as Dc, x, y, label as String, value as String, color) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 18, Graphics.FONT_MEDIUM, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function val(v, def) {
        return v == null ? def : v;
    }

    private function fmtTime(ms as Number) as String {
        var t = ms / 1000;
        var hh = t / 3600;
        var mm = (t % 3600) / 60;
        var ss = t % 60;
        if (hh > 0) {
            return hh + ":" + mm.format("%02d") + ":" + ss.format("%02d");
        }
        return mm.format("%02d") + ":" + ss.format("%02d");
    }
}
