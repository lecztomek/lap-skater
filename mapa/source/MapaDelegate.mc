import Toybox.Lang;
import Toybox.WatchUi;

// UP: przybliż, DOWN: oddal, START: mapa wg kierunku jazdy / północ u góry, BACK: wyjście.
class MapaDelegate extends WatchUi.BehaviorDelegate {
    private var _m as MapaController;

    function initialize(m as MapaController) {
        BehaviorDelegate.initialize();
        _m = m;
    }

    function onPreviousPage() as Boolean {
        _m.zoomIn();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        _m.zoomOut();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Boolean {
        _m.toggleMode();
        WatchUi.requestUpdate();
        return true;
    }
}
