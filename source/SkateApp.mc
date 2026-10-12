import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SkateApp extends Application.AppBase {
    var session as SkateSession;

    function initialize() {
        AppBase.initialize();
        session = new SkateSession();
    }

    function onStart(state as Dictionary?) as Void {
        session.enableSensors();
    }

    function onStop(state as Dictionary?) as Void {
        session.disableSensors();
    }

    function getInitialView() {
        return [new SkateView(session), new SkateDelegate(session)];
    }
}
