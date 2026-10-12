import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// START/ENTER: start / pauza (menu).  BACK/LAP: okrążenie w trakcie, wyjście gdy brak treningu.
// Przytrzymaj UP (MENU): ustawienia – tylko gdy nie ma treningu.
class SkateDelegate extends WatchUi.BehaviorDelegate {
    private var _s as SkateSession;

    function initialize(s as SkateSession) {
        BehaviorDelegate.initialize();
        _s = s;
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

    function onMenu() as Boolean {
        if (_s.hasSession()) {
            return true;
        }
        var menu = new WatchUi.Menu2({:title => Rez.Strings.Settings});
        var lens = [115, 125, 135, 145, 155, 165, 175];
        for (var i = 0; i < lens.size(); i++) {
            var mark = (lens[i] == _s.lapLen.toNumber()) ? " *" : "";
            menu.addItem(new WatchUi.MenuItem(lens[i] + " m" + mark, null, lens[i], {}));
        }
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.SettingGpsShort, null, :gps, _s.gpsMode, {}));
        WatchUi.pushView(menu, new SettingsMenuDelegate(_s), WatchUi.SLIDE_UP);
        return true;
    }

    private function showPauseMenu() as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.Paused});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Resume, null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Save, null, :save, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Discard, null, :discard, {}));
        WatchUi.pushView(menu, new PauseMenuDelegate(_s), WatchUi.SLIDE_UP);
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _s as SkateSession;

    function initialize(s as SkateSession) {
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
            WatchUi.pushView(dlg, new DiscardConfirmDelegate(_s), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

class DiscardConfirmDelegate extends WatchUi.ConfirmationDelegate {
    private var _s as SkateSession;

    function initialize(s as SkateSession) {
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

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _s as SkateSession;

    function initialize(s as SkateSession) {
        Menu2InputDelegate.initialize();
        _s = s;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :gps) {
            var on = (item as WatchUi.ToggleMenuItem).isEnabled();
            Application.Properties.setValue("useGps", on);
            // GPS włącza się przy starcie aplikacji
            _s.disableSensors();
            _s.readSettings();
            _s.enableSensors();
            return;
        }
        Application.Properties.setValue("lapLength", id as Number);
        _s.readSettings();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
