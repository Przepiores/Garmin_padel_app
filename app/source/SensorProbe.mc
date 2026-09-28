import Toybox.Attention;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.System;

// Receives accelerometer + gyroscope data at the highest available rate,
// measures the real sample rate and detects stroke candidates as |omega|
// peaks. The signal around each peak is cut out of a ring buffer and handed
// to the WindowStreamer.
class SensorProbe {
    var label as Number = Labels.NONE;
    var error as String? = null;

    var accMaxRate as Number = 0;
    var gyroMaxRate as Number = 0;
    var rate as Number = 0;

    var accSamples as Number = 0;
    var gyroSamples as Number = 0;
    var callbacks as Number = 0;
    var emptyCallbacks as Number = 0;

    // Maxima since the last reset: per-axis values show gyro saturation.
    var maxGyroAxis as Number = 0;
    var maxGyroNorm as Number = 0;
    var maxAccAxis as Number = 0;
    var strokes as Number = 0;

    private var _streamer as WindowStreamer;
    private var _firstDataMs as Number = -1;
    private var _lastDataMs as Number = 0;

    // Ring buffer of interleaved samples [ax, ay, az, gx, gy, gz].
    private var _buf as Array<Number> = [] as Array<Number>;
    private var _size as Number = 0;
    private var _idx as Number = 0;

    private var _pre as Number = 0;
    private var _post as Number = 0;
    private var _refractory as Number = 0;
    private var _threshold2 as Number = 0;
    private var _eventActive as Boolean = false;
    private var _peakIdx as Number = 0;
    private var _peak2 as Number = 0;
    private var _nextAllowed as Number = 0;
    private var _secondPeak2 as Number = 0;
    private var _maxNorm2 as Number = 0;

    function initialize(streamer as WindowStreamer) {
        _streamer = streamer;
    }

    function start() as Void {
        if (!(Sensor has :registerSensorDataListener) || !(Sensor has :getMaxSampleRateForSensorType)) {
            error = "No sensor data API";
            return;
        }
        accMaxRate = Sensor.getMaxSampleRateForSensorType(:accelerometer);
        gyroMaxRate = Sensor.getMaxSampleRateForSensorType(:gyroscope);
        if (gyroMaxRate <= 0) {
            error = "No gyroscope";
            return;
        }
        rate = Config.TARGET_RATE_HZ;
        if (accMaxRate < rate) {
            rate = accMaxRate;
        }
        if (gyroMaxRate < rate) {
            rate = gyroMaxRate;
        }

        _pre = Config.WINDOW_PRE_MS * rate / 1000;
        _post = Config.WINDOW_POST_MS * rate / 1000;
        _refractory = Config.REFRACTORY_MS * rate / 1000;
        _threshold2 = Config.STROKE_THRESHOLD_DPS * Config.STROKE_THRESHOLD_DPS;
        // One second of margin beyond the window.
        _size = _pre + _post + rate;
        _buf = new [_size * 6] as Array<Number>;
        for (var i = 0; i < _size * 6; i++) {
            _buf[i] = 0;
        }
        resetStats();

        try {
            Sensor.registerSensorDataListener(method(:onData), {
                :period => 1,
                :accelerometer => {:enabled => true, :sampleRate => rate},
                :gyroscope => {:enabled => true, :sampleRate => rate}
            });
        } catch (e) {
            error = e.getErrorMessage();
        }
    }

    function stop() as Void {
        if (Sensor has :unregisterSensorDataListener) {
            Sensor.unregisterSensorDataListener();
        }
    }

    function resetStats() as Void {
        accSamples = 0;
        gyroSamples = 0;
        callbacks = 0;
        emptyCallbacks = 0;
        maxGyroAxis = 0;
        maxGyroNorm = 0;
        maxAccAxis = 0;
        strokes = 0;
        _firstDataMs = -1;
        _maxNorm2 = 0;
        _secondPeak2 = 0;
        _eventActive = false;
    }

    // Measured rates in Hz. The first callback already carries ~1 s of data.
    function accRate() as Number {
        return measuredRate(accSamples);
    }

    function gyroRate() as Number {
        return measuredRate(gyroSamples);
    }

    // Highest |omega| (deg/s) since the previous call, for the per-second chart.
    function takeSecondPeak() as Number {
        var peak = Math.sqrt(_secondPeak2).toNumber();
        _secondPeak2 = 0;
        return peak;
    }

    function onData(data as Sensor.SensorData) as Void {
        var now = System.getTimer();
        if (_firstDataMs < 0) {
            _firstDataMs = now;
        }
        _lastDataMs = now;
        callbacks++;

        var acc = data.accelerometerData;
        var gyro = data.gyroscopeData;
        if (acc == null || gyro == null) {
            emptyCallbacks++;
            return;
        }
        var ax = acc.x;
        var ay = acc.y;
        var az = acc.z;
        var gx = gyro.x;
        var gy = gyro.y;
        var gz = gyro.z;
        accSamples += ax.size();
        gyroSamples += gx.size();

        // If the two sensors deliver different counts, pair what we can;
        // the counters above show the mismatch.
        var n = ax.size() < gx.size() ? ax.size() : gx.size();
        for (var i = 0; i < n; i++) {
            addSample(ax[i], ay[i], az[i], gx[i].toNumber(), gy[i].toNumber(), gz[i].toNumber());
        }
    }

    private function measuredRate(samples as Number) as Number {
        if (_firstDataMs < 0) {
            return 0;
        }
        return samples * 1000 / (_lastDataMs - _firstDataMs + 1000);
    }

    private function addSample(ax as Number, ay as Number, az as Number, gx as Number, gy as Number, gz as Number) as Void {
        var base = (_idx % _size) * 6;
        _buf[base] = ax;
        _buf[base + 1] = ay;
        _buf[base + 2] = az;
        _buf[base + 3] = gx;
        _buf[base + 4] = gy;
        _buf[base + 5] = gz;

        trackMax(ax, ay, az, gx, gy, gz);

        var g2 = gx * gx + gy * gy + gz * gz;
        if (g2 > _secondPeak2) {
            _secondPeak2 = g2;
        }
        if (g2 > _maxNorm2) {
            _maxNorm2 = g2;
            maxGyroNorm = Math.sqrt(g2).toNumber();
        }

        if (_eventActive) {
            if (g2 > _peak2) {
                _peak2 = g2;
                _peakIdx = _idx;
            }
            if (_idx - _peakIdx >= _post) {
                finishEvent();
            }
        } else if (g2 >= _threshold2 && _idx >= _nextAllowed) {
            _eventActive = true;
            _peak2 = g2;
            _peakIdx = _idx;
        }
        _idx++;
    }

    private function trackMax(ax as Number, ay as Number, az as Number, gx as Number, gy as Number, gz as Number) as Void {
        var a = maxAbs3(ax, ay, az);
        if (a > maxAccAxis) {
            maxAccAxis = a;
        }
        var g = maxAbs3(gx, gy, gz);
        if (g > maxGyroAxis) {
            maxGyroAxis = g;
        }
    }

    private function maxAbs3(x as Number, y as Number, z as Number) as Number {
        var m = x < 0 ? -x : x;
        var v = y < 0 ? -y : y;
        if (v > m) {
            m = v;
        }
        v = z < 0 ? -z : z;
        return v > m ? v : m;
    }

    private function finishEvent() as Void {
        _eventActive = false;
        _nextAllowed = _peakIdx + _refractory;
        var start = _peakIdx - _pre;
        if (start < 0) {
            // Peak right after the listener started, no signal before it.
            return;
        }
        strokes++;

        var len = _pre + _post;
        var values = new [len * 6] as Array<Number>;
        for (var s = 0; s < len; s++) {
            var base = ((start + s) % _size) * 6;
            var o = s * 6;
            for (var k = 0; k < 6; k++) {
                values[o + k] = clamp16(_buf[base + k]);
            }
        }
        _streamer.enqueue(label, rate, _pre, values);

        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 80)]);
        }
    }

    private function clamp16(v as Number) as Number {
        if (v > Config.MAX_SINT16) {
            return Config.MAX_SINT16;
        }
        if (v < -Config.MAX_SINT16) {
            return -Config.MAX_SINT16;
        }
        return v;
    }
}
