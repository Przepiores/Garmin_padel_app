import Toybox.Lang;
import Toybox.WatchUi;

// Buttons:
//   START     start recording / pause and open the save menu
//   UP/DOWN   change the stroke label (a new lap starts on every change)
//   BACK      lap while recording, exit when idle
//   MENU      settings (hold UP), only before recording
// Touch is ignored so a sweaty wrist cannot stop the recording.
class ProbeDelegate extends WatchUi.BehaviorDelegate {
    private var _app as PadelProbeApp;

    function initialize(app as PadelProbeApp) {
        BehaviorDelegate.initialize();
        _app = app;
    }

    function onSelect() as Boolean {
        var recorder = _app.recorder;
        if (recorder.isRecording()) {
            _app.pauseRecording();
            Menus.pushSaveMenu(_app);
        } else if (recorder.hasSession()) {
            Menus.pushSaveMenu(_app);
        } else {
            _app.startRecording();
        }
        return true;
    }

    function onNextPage() as Boolean {
        _app.cycleLabel(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _app.cycleLabel(-1);
        return true;
    }

    function onBack() as Boolean {
        var recorder = _app.recorder;
        if (recorder.isRecording()) {
            recorder.lap();
            return true;
        }
        if (recorder.hasSession()) {
            Menus.pushSaveMenu(_app);
            return true;
        }
        return false;
    }

    function onMenu() as Boolean {
        if (!_app.recorder.hasSession()) {
            Menus.pushSettingsMenu(_app);
        }
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        return true;
    }
}
