import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.WatchUi;

// Trening "Jazda na rolkach" (FIT sport 30). Dystans, prędkość i trasę liczy GPS zegarka.
class RolkiSession {
    private var _session = null;
    var autoLap as AutoLap = new AutoLap();
    var gpsQuality as Number = Position.QUALITY_NOT_AVAILABLE;
    var justSaved as Boolean = false;

    function initialize() {
    }

    function enableSensors() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function disableSensors() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    function onPosition(info as Position.Info) as Void {
        gpsQuality = info.accuracy;
        WatchUi.requestUpdate();
    }

    function gpsReady() as Boolean {
        return gpsQuality >= Position.QUALITY_USABLE;
    }

    function hasSession() as Boolean {
        return _session != null;
    }

    function isRecording() as Boolean {
        return _session != null && _session.isRecording();
    }

    function distance() as Float {
        var info = Activity.getActivityInfo();
        return (info != null && info.elapsedDistance != null) ? info.elapsedDistance.toFloat() : 0.0;
    }

    // Co sekundę z widoku: automatyczne okrążenie co 1 km (po cichu).
    function update() as Void {
        if (isRecording() && autoLap.check(distance())) {
            _session.addLap();
        }
    }

    function start() as Void {
        if (_session == null) {
            _session = ActivityRecording.createSession({
                :name => "Rolki",
                :sport => Activity.SPORT_INLINE_SKATING,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            autoLap = new AutoLap();
            justSaved = false;
        }
        _session.start();
        alert(Attention has :TONE_START ? Attention.TONE_START : null);
    }

    function stop() as Void {
        if (isRecording()) {
            _session.stop();
            alert(Attention has :TONE_STOP ? Attention.TONE_STOP : null);
        }
    }

    // BACK: ręczne okrążenie, krótka wibracja.
    function lap() as Void {
        if (!isRecording()) {
            return;
        }
        autoLap.manual(distance());
        _session.addLap();
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
    }

    function save() as Void {
        if (_session != null) {
            _session.save();
            _session = null;
            justSaved = true;
        }
    }

    function discard() as Void {
        if (_session != null) {
            _session.discard();
            _session = null;
        }
    }

    private function alert(tone) as Void {
        if (Attention has :playTone && tone != null) {
            Attention.playTone(tone);
        }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        }
    }
}
