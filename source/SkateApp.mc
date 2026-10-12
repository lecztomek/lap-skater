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
        var view = new SkateView(session);
        return [view, new SkateDelegate(session, view)];
    }
}
