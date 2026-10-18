import Toybox.Lang;

// Statystyki mocy z próbek co sekundę – sama logika, testowana w RowerTest.mc.
// Pokazujemy średnią z 3 s (pojedyncze odczyty skaczą), w podsumowaniu średnia i maksimum.
class PowerStats {
    static const SMOOTH = 3;
    // Brak danych dłużej niż STALE s = czujnik zgubiony, przestajemy podawać moc.
    static const STALE = 3;

    var count as Number = 0;
    var max as Number = 0;
    private var _sum as Number = 0;
    private var _recent as Array<Number> = [];
    private var _missing as Number = 0;

    function initialize() {
    }

    // power = null, gdy w tej sekundzie nie ma odczytu.
    function add(power as Number?) as Void {
        if (power == null) {
            _missing += 1;
            return;
        }
        _missing = 0;
        count += 1;
        _sum += power;
        if (power > max) {
            max = power;
        }
        _recent.add(power);
        if (_recent.size() > SMOOTH) {
            _recent = _recent.slice(1, null);
        }
    }

    function hasData() as Boolean {
        return count > 0 && _missing < STALE;
    }

    function smoothed() as Number {
        var n = _recent.size();
        if (n == 0) {
            return 0;
        }
        var s = 0;
        for (var i = 0; i < n; i++) {
            s += _recent[i];
        }
        return (s + n / 2) / n;
    }

    function average() as Number {
        return count > 0 ? (_sum + count / 2) / count : 0;
    }
}
