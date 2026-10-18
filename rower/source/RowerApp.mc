import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class RowerApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new RowerField()];
    }
}
