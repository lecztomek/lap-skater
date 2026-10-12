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
// Bez GPS okrążenia liczy kompas: każde pełne 360° obrotu = jedno okrążenie tafli.
// Dystans = okrążenia x długość okrążenia z ustawień. BACK = okrążenie ręcznie (korekta).
class SkateSession {
    // Krótsze "okrążenie" = podwójne kliknięcie albo piruet, nie liczymy.
    private const MIN_LAP_MS = 8000;
    private const PI_F = 3.1415927;
    private const TWO_PI_F = 6.2831853;
    private const SPEED_WINDOW = 10; // s, wygładzanie prędkości
    // Piruet: magnetometr ~25 Hz, obrót szybszy niż SPIN_RATE przez SPIN_MIN_SAMPLES próbek.
    // Na lodzie (nawet w zakręcie) obracamy się ~0,5 rad/s, piruet to 10–30 rad/s.
    private const MAG_RATE = 25;
    private const SPIN_RATE = 8.0;
    private const SPIN_MIN_SAMPLES = 5;
    private const SPIN_HOLD_MS = 1500;

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
    var turn as Float = 0.0;          // obrót [rad] od ostatniego okrążenia
    var hasCompass as Boolean = false;
    private var _anchor = null;       // ostatni zatwierdzony kierunek
    private var _pendHd = null;       // próbka czekająca 1 s na ewentualne wykrycie piruetu
    private var _pendT as Number = 0;
    private var _spinFromMs as Number = -100000;
    private var _spinUntilMs as Number = -100000;
    private var _fastCount as Number = 0;
    private var _mx = null;
    private var _my = 0.0;
    private var _mz = 0.0;
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
        enableMagnetometer();
        if (gpsMode) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    function disableSensors() as Void {
        Sensor.enableSensorEvents(null);
        if (Sensor has :unregisterSensorDataListener) {
            Sensor.unregisterSensorDataListener();
        }
        if (gpsMode) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
    }

    function onPosition(info as Position.Info) as Void {
        gpsQuality = info.accuracy;
        WatchUi.requestUpdate();
    }

    // Szybkie dane magnetometru służą tylko do wykrycia piruetu (bez kalibracji – liczy się tempo zmian).
    private function enableMagnetometer() as Void {
        if (!(Sensor has :registerSensorDataListener)) {
            return;
        }
        try {
            Sensor.registerSensorDataListener(method(:onSensorData), {
                :period => 1,
                :magnetometer => {:enabled => true, :sampleRate => MAG_RATE}
            });
        } catch (e) {
            // bez wykrywania piruetów – liczenie działa jak wcześniej
        }
    }

    function onSensorData(data as Sensor.SensorData) as Void {
        var md = data.magnetometerData;
        if (md == null || md.x == null || md.y == null || md.z == null) {
            return;
        }
        var xs = md.x;
        var ys = md.y;
        var zs = md.z;
        var now = System.getTimer();
        for (var i = 0; i < xs.size(); i++) {
            var x = xs[i].toFloat();
            var y = ys[i].toFloat();
            var z = zs[i].toFloat();
            if (_mx != null) {
                var n = Math.sqrt((x * x + y * y + z * z) * (_mx * _mx + _my * _my + _mz * _mz));
                if (n > 0) {
                    var c = (x * _mx + y * _my + z * _mz) / n;
                    if (c > 1.0) { c = 1.0; }
                    if (c < -1.0) { c = -1.0; }
                    if (Math.acos(c) * MAG_RATE > SPIN_RATE) {
                        _fastCount += 1;
                        if (_fastCount >= SPIN_MIN_SAMPLES) {
                            if (now > _spinUntilMs) {
                                _spinFromMs = now - 1300; // paczka danych obejmuje ostatnią sekundę
                            }
                            _spinUntilMs = now + SPIN_HOLD_MS;
                        }
                    } else {
                        _fastCount = 0;
                    }
                }
            }
            _mx = x;
            _my = y;
            _mz = z;
        }
    }

    // ~1 Hz. Sumujemy zmianę kierunku; arytmetyka w (-PI, PI], więc przejście przez północ nie przeszkadza.
    // Zakłócenia magnetyczne hali są stałe w danym miejscu, więc na pełnym okrążeniu się znoszą.
    // Próbki z czasu piruetu pomijamy i liczymy różnicę między kierunkiem przed i po piruecie
    // (wyjeżdżamy w tę samą stronę, więc to mały kąt). Każda próbka czeka 1 s, bo dane
    // magnetometru przychodzą paczkami co sekundę.
    function onSensor(info as Sensor.Info) as Void {
        var hd = info.heading;
        if (hd == null) {
            return;
        }
        hasCompass = true;
        if (!isRecording() || gpsMode) {
            _anchor = hd;
            _pendHd = null;
            return;
        }
        var now = System.getTimer();
        if (_pendHd != null) {
            if (_pendT < _spinFromMs || _pendT > _spinUntilMs) {
                commitHeading(_pendHd);
            }
            _pendHd = null;
        }
        if (now >= _spinFromMs && now <= _spinUntilMs) {
            return;
        }
        _pendHd = hd;
        _pendT = now;
    }

    private function commitHeading(hd) as Void {
        if (_anchor == null) {
            _anchor = hd;
            return;
        }
        var d = (hd - _anchor).toFloat();
        while (d > PI_F) { d -= TWO_PI_F; }
        while (d <= -PI_F) { d += TWO_PI_F; }
        turn += d;
        _anchor = hd;
        if (turn >= TWO_PI_F || turn <= -TWO_PI_F) {
            // zostawiamy nadwyżkę ponad 360° dla następnego okrążenia
            turn += (turn > 0) ? -TWO_PI_F : TWO_PI_F;
            countLap(false);
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
        var part = (turn < 0 ? -turn : turn) / TWO_PI_F;
        if (part > 1.0) { part = 1.0; }
        return (laps + part) * lapLen;
    }

    function lapPercent() as Number {
        return ((distance() / lapLen - laps) * 100).toNumber();
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
            lapStartMs = 0;
            lastLapKmh = 0.0;
            curKmh = 0.0;
            maxKmh = 0.0;
            turn = 0.0;
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
        _fLaps.setData(laps);
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
        if (isRecording() && countLap(true)) {
            turn = 0.0;
        }
    }

    private function countLap(manual as Boolean) as Boolean {
        var now = timerMs();
        var dt = now - lapStartMs;
        if (dt < MIN_LAP_MS) {
            return false;
        }
        lastLapKmh = lapLen / (dt / 1000.0) * 3.6;
        laps += 1;
        lapStartMs = now;
        if (_fLapSpeed != null) {
            _fLapSpeed.setData(lastLapKmh); // trafia do zamykanego okrążenia
        }
        writeFit();
        _session.addLap();
        // automatyczne okrążenia po cichu; ręczne potwierdza krótka wibracja
        if (manual && Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
        return true;
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
