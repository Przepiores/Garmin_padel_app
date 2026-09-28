import Toybox.Lang;
import Toybox.WatchUi;

module Menus {
    function pushSaveMenu(app as PadelProbeApp) as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SaveTitle});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuResume, null, :resume, null));

        // Windows still queued are lost on save; warn so the user can resume
        // for a moment and let them be written.
        var pending = app.streamer.pending();
        var saveSubLabel = null;
        if (pending > 0) {
            saveSubLabel = Lang.format(WatchUi.loadResource(Rez.Strings.QueueWarning) as String, [pending]);
        }
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuSave, saveSubLabel, :save, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuDiscard, null, :discard, null));
        WatchUi.pushView(menu, new SaveMenuDelegate(app), WatchUi.SLIDE_UP);
    }

    function pushSettingsMenu(app as PadelProbeApp) as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SettingsTitle});
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.SettingLogger, null, :logger, app.useLogger, null));
        WatchUi.pushView(menu, new SettingsMenuDelegate(app), WatchUi.SLIDE_UP);
    }
}

class SaveMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _app as PadelProbeApp;

    function initialize(app as PadelProbeApp) {
        Menu2InputDelegate.initialize();
        _app = app;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            _app.resumeRecording();
        } else if (id == :save) {
            _app.saveRecording();
        } else if (id == :discard) {
            _app.discardRecording();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    // BACK leaves the session paused; START on the main screen reopens the menu.
    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _app as PadelProbeApp;

    function initialize(app as PadelProbeApp) {
        Menu2InputDelegate.initialize();
        _app = app;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :logger && item instanceof WatchUi.ToggleMenuItem) {
            _app.setUseLogger(item.isEnabled());
        }
    }
}
