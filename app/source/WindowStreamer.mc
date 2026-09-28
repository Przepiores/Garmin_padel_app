import Toybox.FitContributor;
import Toybox.Lang;

// Signal around one detected stroke, samples interleaved as
// [ax, ay, az, gx, gy, gz] (milli-g, deg/s).
class StrokeWindow {
    var id as Number;
    var label as Number;
    var rate as Number;
    var pre as Number;
    var values as Array<Number>;

    function initialize(id as Number, label as Number, rate as Number, pre as Number, values as Array<Number>) {
        self.id = id;
        self.label = label;
        self.rate = rate;
        self.pre = pre;
        self.values = values;
    }
}

// Writes stroke windows to FIT developer fields. An app may write at most
// 256 B per record message, so each window is split into chunks written one
// per CHUNK_PERIOD_MS. Header layout (uint16):
// [window id, chunk index, samples in window, label, sample rate, pre samples]
class WindowStreamer {
    var active as Boolean = false;
    var dropped as Number = 0;
    var chunksWritten as Number = 0;

    private var _queue as Array<StrokeWindow> = [] as Array<StrokeWindow>;
    private var _chunkIdx as Number = 0;
    private var _nextId as Number = 1;
    private var _idle as Boolean = false;
    private var _hdrField as FitContributor.Field? = null;
    private var _dataField as FitContributor.Field? = null;

    function initialize() {
    }

    function setFields(hdrField as FitContributor.Field?, dataField as FitContributor.Field?) as Void {
        _hdrField = hdrField;
        _dataField = dataField;
        _idle = false;
    }

    function reset() as Void {
        _queue = [] as Array<StrokeWindow>;
        _chunkIdx = 0;
        _nextId = 1;
        dropped = 0;
        chunksWritten = 0;
        active = false;
        setFields(null, null);
    }

    function pending() as Number {
        return _queue.size();
    }

    function enqueue(label as Number, rate as Number, pre as Number, values as Array<Number>) as Void {
        if (!active) {
            return;
        }
        if (_queue.size() >= Config.MAX_QUEUED_WINDOWS) {
            dropped++;
            return;
        }
        _queue.add(new StrokeWindow(_nextId, label, rate, pre, values));
        _nextId = _nextId >= Config.MAX_WINDOW_ID ? 1 : _nextId + 1;
    }

    // Called every CHUNK_PERIOD_MS while the session is recording.
    function tick() as Void {
        var hdrField = _hdrField;
        var dataField = _dataField;
        if (hdrField == null || dataField == null) {
            return;
        }
        if (_queue.size() == 0) {
            if (!_idle) {
                hdrField.setData(zeros(Config.HEADER_VALUES));
                _idle = true;
            }
            return;
        }
        _idle = false;

        var window = _queue[0];
        var total = window.values.size();
        var from = _chunkIdx * Config.CHUNK_VALUES;
        var chunk = new [Config.CHUNK_VALUES] as Array<Number>;
        for (var i = 0; i < Config.CHUNK_VALUES; i++) {
            var j = from + i;
            chunk[i] = j < total ? window.values[j] : 0;
        }
        hdrField.setData([window.id, _chunkIdx, total / 6, window.label, window.rate, window.pre]);
        dataField.setData(chunk);
        chunksWritten++;

        _chunkIdx++;
        if (_chunkIdx * Config.CHUNK_VALUES >= total) {
            _queue.remove(window);
            _chunkIdx = 0;
        }
    }

    private function zeros(count as Number) as Array<Number> {
        var result = new [count] as Array<Number>;
        for (var i = 0; i < count; i++) {
            result[i] = 0;
        }
        return result;
    }
}
