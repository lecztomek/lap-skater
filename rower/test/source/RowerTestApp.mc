import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Pusta aplikacja – nośnik testów jednostkowych PowerStats.
class RowerTestApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new WatchUi.View()];
    }
}
