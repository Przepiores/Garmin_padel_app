import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Single screen with everything the court test needs to read off the watch.
class ProbeView extends WatchUi.View {
    private var _app as PadelProbeApp;

    function initialize(app as PadelProbeApp) {
        View.initialize();
        _app = app;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var probe = _app.probe;
        var cx = dc.getWidth() / 2;
        var font = Graphics.FONT_XTINY;
        var lineHeight = dc.getFontHeight(font);
        var labelFont = Graphics.FONT_SMALL;

        var lines = [
            format(Rez.Strings.AccLine, [probe.accRate(), probe.accMaxRate]),
            format(Rez.Strings.GyroLine, [probe.gyroRate(), probe.gyroMaxRate]),
            format(Rez.Strings.GyroMaxLine, [probe.maxGyroNorm, probe.maxGyroAxis]),
            format(Rez.Strings.AccMaxLine, [(probe.maxAccAxis / 1000.0).format("%.1f")]),
            format(Rez.Strings.StrokesLine, [probe.strokes, _app.streamer.pending()]),
            format(Rez.Strings.LoggerLine, [onOff(_app.useLogger), heartRate()])
        ] as Array<String>;

        var total = lineHeight * (lines.size() + 1) + dc.getFontHeight(labelFont);
        var y = (dc.getHeight() - total) / 2;

        dc.setColor(statusColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, statusText(), Graphics.TEXT_JUSTIFY_CENTER);
        y += lineHeight;

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, labelFont, Labels.name(_app.label), Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(labelFont);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, y, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineHeight;
        }

        var error = probe.error;
        if (error != null) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, font, error, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function statusText() as String {
        var recorder = _app.recorder;
        if (recorder.isRecording()) {
            return format(Rez.Strings.StatusRec, [timerText()]);
        }
        if (recorder.hasSession()) {
            return format(Rez.Strings.StatusPaused, [timerText()]);
        }
        var result = _app.lastResult;
        if (result != null) {
            return WatchUi.loadResource(result) as String;
        }
        return WatchUi.loadResource(Rez.Strings.StatusIdle) as String;
    }

    private function statusColor() as Number {
        var recorder = _app.recorder;
        if (recorder.isRecording()) {
            return Graphics.COLOR_RED;
        }
        return recorder.hasSession() ? Graphics.COLOR_ORANGE : Graphics.COLOR_GREEN;
    }

    private function timerText() as String {
        var info = Activity.getActivityInfo();
        var ms = info != null ? info.timerTime : null;
        if (ms == null) {
            ms = 0;
        }
        var s = ms / 1000;
        return (s / 60).format("%02d") + ":" + (s % 60).format("%02d");
    }

    private function heartRate() as String {
        var info = Activity.getActivityInfo();
        var hr = info != null ? info.currentHeartRate : null;
        return hr != null ? hr.toString() : "--";
    }

    private function onOff(enabled as Boolean) as String {
        return WatchUi.loadResource(enabled ? Rez.Strings.On : Rez.Strings.Off) as String;
    }

    private function format(id as ResourceId, args as Array) as String {
        return Lang.format(WatchUi.loadResource(id) as String, args);
    }
}
