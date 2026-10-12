import Toybox.Lang;
import Toybox.WatchUi;

// START: start / pauza (menu).  BACK: okrążenie w trakcie, wyjście gdy brak treningu.
// UP/DOWN: ekran prosty / szczegóły.
class RolkiDelegate extends WatchUi.BehaviorDelegate {
    private var _s as RolkiSession;
    private var _view as RolkiView;

    function initialize(s as RolkiSession, view as RolkiView) {
        BehaviorDelegate.initialize();
        _s = s;
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.togglePage();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.togglePage();
        return true;
    }

    function onSelect() as Boolean {
        if (_s.isRecording()) {
            _s.stop();
            showPauseMenu();
        } else if (_s.hasSession()) {
            showPauseMenu();
        } else {
            _s.start();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (_s.isRecording()) {
            _s.lap();
            WatchUi.requestUpdate();
            return true;
        }
        if (_s.hasSession()) {
            showPauseMenu();
            return true;
        }
        return false; // brak treningu -> wyjście z aplikacji
    }

    private function showPauseMenu() as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.Paused});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Resume, null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Save, null, :save, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Discard, null, :discard, {}));
        WatchUi.pushView(menu, new RolkiPauseDelegate(_s), WatchUi.SLIDE_UP);
    }
}

class RolkiPauseDelegate extends WatchUi.Menu2InputDelegate {
    private var _s as RolkiSession;

    function initialize(s as RolkiSession) {
        Menu2InputDelegate.initialize();
        _s = s;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            _s.start();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :save) {
            _s.save();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :discard) {
            var dlg = new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.DiscardConfirm) as String);
            WatchUi.pushView(dlg, new RolkiDiscardDelegate(_s), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

class RolkiDiscardDelegate extends WatchUi.ConfirmationDelegate {
    private var _s as RolkiSession;

    function initialize(s as RolkiSession) {
        ConfirmationDelegate.initialize();
        _s = s;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _s.discard();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // zamknij menu pauzy (dialog zamyka się sam)
        }
        return true;
    }
}
