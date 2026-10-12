import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Timer;
import Toybox.WatchUi;

class SkateView extends WatchUi.View {
    private var _s as SkateSession;
    private var _timer as Timer.Timer?;

    function initialize(s as SkateSession) {
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

    function onTick() as Void {
        _s.update();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var info = Activity.getActivityInfo();
        var timerMs = val(info != null ? info.timerTime : null, 0);
        var dist = val(info != null ? info.elapsedDistance : null, 0.0);
        var speed = val(info != null ? info.currentSpeed : null, 0.0);
        var maxSpeed = val(info != null ? info.maxSpeed : null, 0.0);
        var hr = info != null ? info.currentHeartRate : null;
        var cal = val(info != null ? info.calories : null, 0);

        // Status u góry: bieżące okrążenie i jego czas
        var status;
        var statusColor = Graphics.COLOR_LT_GRAY;
        if (_s.isRecording()) {
            status = (WatchUi.loadResource(Rez.Strings.Lap) as String) + " " + _s.laps;
            if (!_s.gpsMode) {
                status += _s.hasCompass ? "  +" + _s.lapPercent() + "%" : "  BACK=okr.";
            }
            statusColor = Graphics.COLOR_GREEN;
        } else if (_s.hasSession()) {
            status = (WatchUi.loadResource(Rez.Strings.Paused) as String);
            statusColor = Graphics.COLOR_YELLOW;
        } else if (_s.justSaved) {
            status = (WatchUi.loadResource(Rez.Strings.Saved) as String);
            statusColor = Graphics.COLOR_GREEN;
        } else {
            status = (WatchUi.loadResource(Rez.Strings.PressStart) as String);
        }
        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.10, Graphics.FONT_XTINY, status, Graphics.TEXT_JUSTIFY_CENTER);

        // Czas
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.20, Graphics.FONT_NUMBER_MEDIUM, fmtTime(timerMs), Graphics.TEXT_JUSTIFY_CENTER);

        // Tętno / kalorie
        var y1 = h * 0.47;
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.30, y1, Graphics.FONT_MEDIUM, hr != null ? hr.toString() : "--", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.70, y1, Graphics.FONT_MEDIUM, cal.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.30, y1 - h * 0.06, Graphics.FONT_XTINY, "HR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.70, y1 - h * 0.06, Graphics.FONT_XTINY, "kcal", Graphics.TEXT_JUSTIFY_CENTER);

        // Dystans / prędkość: z GPS albo z okrążeń
        var bottom;
        if (_s.gpsMode) {
            bottom = "max " + (maxSpeed * 3.6).format("%.1f") + "  GPS " + gpsLabel();
        } else {
            dist = _s.distance();
            speed = _s.curKmh / 3.6;
            bottom = "śr " + _s.avgKmh().format("%.1f") + "  max " + _s.maxKmh.format("%.1f");
        }
        var y2 = h * 0.68;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.30, y2, Graphics.FONT_MEDIUM, (dist / 1000.0).format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.70, y2, Graphics.FONT_MEDIUM, (speed * 3.6).format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.30, y2 - h * 0.06, Graphics.FONT_XTINY, "km", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.70, y2 - h * 0.06, Graphics.FONT_XTINY, "km/h", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, bottom, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function gpsLabel() as String {
        var q = _s.gpsQuality;
        if (q >= Position.QUALITY_GOOD) { return "OK"; }
        if (q >= Position.QUALITY_USABLE) { return "~"; }
        return "...";
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
