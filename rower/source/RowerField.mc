import Toybox.Activity;
import Toybox.AntPlus;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.WatchUi;

// Pole danych: łączy się z miernikiem mocy ANT+ (Fazua Ride 60 nadaje profil mocy: moc rowerzysty
// i kadencję), pokazuje moc (średnia 3 s) i zapisuje ją w treningu. Pola FIT mają nativeNum
// standardowych pól mocy/kadencji, żeby serwisy typu Strava mogły je czytać jak zwykłą moc.
class RowerField extends WatchUi.SimpleDataField {
    // numery standardowych pól FIT: record.power, record.cadence, session.avg_power, session.max_power
    private const NATIVE_POWER = 7;
    private const NATIVE_CADENCE = 4;
    private const NATIVE_AVG_POWER = 20;
    private const NATIVE_MAX_POWER = 21;

    private var _power as AntPlus.BikePower?;
    private var _stats as PowerStats = new PowerStats();
    private var _fPower = null;
    private var _fCadence = null;
    private var _fAvg = null;
    private var _fMax = null;

    function initialize() {
        SimpleDataField.initialize();
        label = WatchUi.loadResource(Rez.Strings.Label) as String;
        // wyszukuje dowolny miernik mocy ANT+ w pobliżu (rower)
        _power = new AntPlus.BikePower(null);
        createFitFields();
    }

    private function createFitFields() as Void {
        _fPower = createField("power", 0, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "W", :nativeNum => NATIVE_POWER});
        _fCadence = createField("cadence", 1, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "rpm", :nativeNum => NATIVE_CADENCE});
        _fAvg = createField("avg_power", 2, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "W", :nativeNum => NATIVE_AVG_POWER});
        _fMax = createField("max_power", 3, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "W", :nativeNum => NATIVE_MAX_POWER});
    }

    // Co sekundę w trakcie aktywności.
    function compute(info as Activity.Info) {
        var watts = null;
        var cadence = null;
        if (_power != null) {
            var p = _power.getCalculatedPower();
            if (p != null && p.power != null) {
                watts = p.power.toNumber();
            }
            var c = _power.getCalculatedCadence();
            if (c != null && c.cadence != null) {
                cadence = c.cadence.toNumber();
            }
        }
        var recording = info != null && info.timerState == Activity.TIMER_STATE_ON;
        if (recording) {
            _stats.add(watts);
        }
        if (_fPower != null && recording) {
            if (watts != null) {
                _fPower.setData(watts);
            } else if (!_stats.hasData() && _stats.count > 0) {
                _fPower.setData(0);   // czujnik zgubiony – nie powtarzamy starej wartości
            }
            if (cadence != null) {
                _fCadence.setData(cadence);
            }
            if (_stats.count > 0) {
                _fAvg.setData(_stats.average());
                _fMax.setData(_stats.max);
            }
        }
        if (watts == null && !_stats.hasData()) {
            return "--";
        }
        return recording ? _stats.smoothed() : (watts != null ? watts : "--");
    }
}
