import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MapaApp extends Application.AppBase {
    var map as MapaController;

    function initialize() {
        AppBase.initialize();
        map = new MapaController();
    }

    function onStart(state as Dictionary?) as Void {
        map.start();
    }

    function onStop(state as Dictionary?) as Void {
        map.stop();
    }

    // zmiana klucza / stylu w Connect IQ na telefonie
    function onSettingsChanged() as Void {
        map.readSettings();
        WatchUi.requestUpdate();
    }

    function getInitialView() {
        var view = new MapaView(map);
        return [view, new MapaDelegate(map)];
    }
}
