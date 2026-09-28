import Toybox.Application;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Technical spike: records an activity while measuring sensor rates and
// collecting labelled stroke windows (see docs/PLAN_TESTU.md).
class PadelProbeApp extends Application.AppBase {
    const STORAGE_USE_LOGGER = "useLogger";

    var streamer as WindowStreamer;
    var probe as SensorProbe;
    var recorder as Recorder;
    var label as Number = Labels.NONE;
    var useLogger as Boolean = true;
    // Resource id of the last result shown on screen (saved / discarded).
    var lastResult as ResourceId? = null;

    private var _uiTimer as Timer.Timer?;
    private var _chunkTimer as Timer.Timer?;

    function initialize() {
        AppBase.initialize();
        streamer = new WindowStreamer();
        probe = new SensorProbe(streamer);
        recorder = new Recorder();
        var stored = Application.Storage.getValue(STORAGE_USE_LOGGER);
        if (stored instanceof Boolean) {
            useLogger = stored;
        }
    }

    function onStart(state as Dictionary?) as Void {
        probe.start();
        var uiTimer = new Timer.Timer();
        uiTimer.start(method(:onUiTick), 1000, true);
        _uiTimer = uiTimer;
        var chunkTimer = new Timer.Timer();
        chunkTimer.start(method(:onChunkTick), Config.CHUNK_PERIOD_MS, true);
        _chunkTimer = chunkTimer;
    }

    function onStop(state as Dictionary?) as Void {
        var uiTimer = _uiTimer;
        if (uiTimer != null) {
            uiTimer.stop();
        }
        var chunkTimer = _chunkTimer;
        if (chunkTimer != null) {
            chunkTimer.stop();
        }
        // Never lose a recording when the app is closed.
        if (recorder.hasSession()) {
            recorder.save(probe, streamer);
        }
        probe.stop();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new ProbeView(self), new ProbeDelegate(self)];
    }

    function onUiTick() as Void {
        var peak = probe.takeSecondPeak();
        if (recorder.isRecording()) {
            recorder.updateSecond(peak, probe.strokes);
        }
        WatchUi.requestUpdate();
    }

    function onChunkTick() as Void {
        if (recorder.isRecording()) {
            streamer.tick();
        }
    }

    function startRecording() as Void {
        lastResult = null;
        probe.resetStats();
        streamer.reset();
        recorder.start(useLogger, label, streamer);
        streamer.active = true;
        WatchUi.requestUpdate();
    }

    function pauseRecording() as Void {
        recorder.stop(probe, streamer);
        streamer.active = false;
        WatchUi.requestUpdate();
    }

    function resumeRecording() as Void {
        recorder.resume();
        streamer.active = true;
        WatchUi.requestUpdate();
    }

    function saveRecording() as Void {
        recorder.save(probe, streamer);
        streamer.reset();
        lastResult = Rez.Strings.StatusSaved;
        WatchUi.requestUpdate();
    }

    function discardRecording() as Void {
        recorder.discard();
        streamer.reset();
        lastResult = Rez.Strings.StatusDiscarded;
        WatchUi.requestUpdate();
    }

    function cycleLabel(delta as Number) as Void {
        label = (label + delta + Labels.COUNT) % Labels.COUNT;
        probe.label = label;
        if (recorder.hasSession()) {
            recorder.setLabel(label);
        }
        WatchUi.requestUpdate();
    }

    function setUseLogger(enabled as Boolean) as Void {
        useLogger = enabled;
        Application.Storage.setValue(STORAGE_USE_LOGGER, enabled);
    }
}
