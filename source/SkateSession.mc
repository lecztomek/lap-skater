import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;
import Toybox.WatchUi;

// Nagrywanie treningu jako "Jazda na łyżwach" (FIT sport 33).
// Bez GPS okrążenia liczy kompas (LapCounter): każde pełne 360° obrotu = jedno okrążenie tafli.
// Dystans = okrążenia x długość okrążenia z ustawień. BACK = okrążenie ręcznie (korekta).
class SkateSession {
    private const SPEED_WINDOW = 10; // s, wygładzanie prędkości

    private var _session = null;
    private var _fDist = null;
    private var _fLaps = null;
    private var _fRecDist = null;
    private var _fRecSpeed = null;
    private var _fLapSpeed = null;
    private var _fAvg = null;

    var gpsMode as Boolean = false;
    var lapLen as Float = 145.0;
    var laps as Number = 0;
    var lapStartMs as Number = 0;
    var lastLapKmh as Float = 0.0;
    var curKmh as Float = 0.0;
    var maxKmh as Float = 0.0;
    var hasCompass as Boolean = false;
    var counter as LapCounter = new LapCounter();
    private var _distHist as Array<Float> = [];
    var gpsQuality as Number = Position.QUALITY_NOT_AVAILABLE;
    var justSaved as Boolean = false;

    function initialize() {
        readSettings();
    }

    function readSettings() as Void {
        var g = Application.Properties.getValue("useGps");
        gpsMode = (g == null) ? false : (g as Boolean);
        var l = Application.Properties.getValue("lapLength");
        lapLen = (l == null || (l as Number) <= 0) ? 145.0 : (l as Number).toFloat();
    }

    function enableSensors() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensor));
        if (gpsMode) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    function disableSensors() as Void {
        Sensor.enableSensorEvents(null);
        if (gpsMode) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
    }

    function onPosition(info as Position.Info) as Void {
        gpsQuality = info.accuracy;
        WatchUi.requestUpdate();
    }

    // ~1 Hz.
    function onSensor(info as Sensor.Info) as Void {
        var hd = info.heading;
        if (hd == null) {
            return;
        }
        hasCompass = true;
        if (!isRecording() || gpsMode) {
            counter.hold(hd.toFloat());
            return;
        }
        if (counter.addHeading(hd.toFloat(), timerMs())) {
            onLap(false);
        }
    }

    // Co sekundę z widoku: prędkość z dystansu w oknie SPEED_WINDOW s.
    function update() as Void {
        if (!isRecording()) {
            return;
        }
        if (!gpsMode) {
            _distHist.add(distance());
            if (_distHist.size() > SPEED_WINDOW + 1) {
                _distHist = _distHist.slice(1, null);
            }
            var n = _distHist.size();
            if (n > 1) {
                curKmh = (_distHist[n - 1] - _distHist[0]) / (n - 1) * 3.6;
                if (n == SPEED_WINDOW + 1 && curKmh > maxKmh) {
                    maxKmh = curKmh;
                }
            }
        }
        writeFit();
    }

    function hasSession() as Boolean {
        return _session != null;
    }

    function isRecording() as Boolean {
        return _session != null && _session.isRecording();
    }

    function timerMs() as Number {
        var info = Activity.getActivityInfo();
        return (info != null && info.timerTime != null) ? info.timerTime : 0;
    }

    // Dystans w metrach: pełne okrążenia + część bieżącego wg obrotu.
    function distance() as Float {
        return counter.totalLaps() * lapLen;
    }

    // Okrążenia do wyświetlenia (łącznie z niedokończonymi sprzed zmian kierunku).
    function lapsShown() as Number {
        return Math.floor(counter.totalLaps()).toNumber();
    }

    function lapPercent() as Number {
        var t = counter.totalLaps();
        return ((t - Math.floor(t)) * 100).toNumber();
    }

    function avgKmh() as Float {
        var t = timerMs();
        return t > 0 ? distance() / (t / 1000.0) * 3.6 : 0.0;
    }

    function start() as Void {
        if (_session == null) {
            _session = ActivityRecording.createSession({
                :name => "Lyzwy",
                :sport => Activity.SPORT_ICE_SKATING,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            laps = 0;
            lastLapKmh = 0.0;
            curKmh = 0.0;
            maxKmh = 0.0;
            counter = new LapCounter();
            _distHist = [];
            justSaved = false;
            if (!gpsMode) {
                createFitFields();
            }
        }
        _session.start();
        alert(Attention has :TONE_START ? Attention.TONE_START : null);
    }

    private function createFitFields() as Void {
        _fDist = _session.createField("dystans", 0, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "km"});
        _fLaps = _session.createField("okrazenia", 1, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_SESSION});
        _fRecDist = _session.createField("dystans_rec", 2, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "km"});
        _fRecSpeed = _session.createField("predkosc_okr", 3, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "km/h"});
        _fLapSpeed = _session.createField("predkosc_lap", 4, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "km/h"});
        _fAvg = _session.createField("srednia", 5, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "km/h"});
        writeFit();
    }

    private function writeFit() as Void {
        if (_fDist == null) {
            return;
        }
        var km = distance() / 1000.0;
        _fDist.setData(km);
        _fLaps.setData(lapsShown());
        _fRecDist.setData(km);
        _fRecSpeed.setData(lastLapKmh);
        _fAvg.setData(avgKmh());
    }

    function stop() as Void {
        if (isRecording()) {
            _session.stop();
            curKmh = 0.0;
            _distHist = [];
            writeFit();
            alert(Attention has :TONE_STOP ? Attention.TONE_STOP : null);
        }
    }

    // BACK: ręczne okrążenie (korekta) – zeruje licznik obrotu kompasu.
    function lap() as Void {
        if (isRecording() && counter.manualLap(timerMs())) {
            onLap(true);
        }
    }

    private function onLap(manual as Boolean) as Void {
        laps = counter.laps;
        lapStartMs = timerMs();
        var dt = counter.lastLapDtMs;
        lastLapKmh = dt > 0 ? lapLen / (dt / 1000.0) * 3.6 : 0.0;
        if (_fLapSpeed != null) {
            _fLapSpeed.setData(lastLapKmh); // trafia do zamykanego okrążenia
        }
        writeFit();
        _session.addLap();
        // automatyczne okrążenia po cichu; ręczne potwierdza krótka wibracja
        if (manual && Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
    }

    function save() as Void {
        if (_session != null) {
            writeFit();
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
