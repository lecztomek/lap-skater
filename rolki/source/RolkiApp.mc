import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class RolkiApp extends Application.AppBase {
    var session as RolkiSession;

    function initialize() {
        AppBase.initialize();
        session = new RolkiSession();
    }

    function onStart(state as Dictionary?) as Void {
        session.enableSensors();
    }

    function onStop(state as Dictionary?) as Void {
        session.disableSensors();
    }

    function getInitialView() {
        var view = new RolkiView(session);
        return [view, new RolkiDelegate(session, view)];
    }
}
