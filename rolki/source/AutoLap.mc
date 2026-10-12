import Toybox.Lang;

// Automatyczne okrążenie co LAP_M metrów od poprzedniego (automatycznego albo ręcznego) –
// w Garmin Connect daje międzyczasy kilometrowe. Sama logika, testowana w RolkiTest.mc.
class AutoLap {
    static const LAP_M = 1000.0;

    var laps as Number = 0;
    private var _lapStartM as Float = 0.0;

    function initialize() {
    }

    // Zwraca true, gdy przekroczono kolejny kilometr.
    function check(distM as Float) as Boolean {
        if (distM - _lapStartM >= LAP_M) {
            _lapStartM += LAP_M;
            laps += 1;
            return true;
        }
        return false;
    }

    // Ręczne okrążenie: kolejny kilometr liczony od tego miejsca.
    function manual(distM as Float) as Void {
        _lapStartM = distM;
        laps += 1;
    }

    function lapDistance(distM as Float) as Float {
        return distM - _lapStartM;
    }
}
