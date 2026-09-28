import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.SensorLogging;

// FIT developer field ids. Must match resources/fit/fit_contributions.xml;
// tools/fit_probe.py finds the fields by name.
module FitIds {
    const LABEL = 0;
    const GYRO_PEAK = 1;
    const STROKES = 2;
    const WIN_HDR = 3;
    const WIN_DATA = 4;
    const LAP_LABEL = 5;
    const TOTAL_STROKES = 6;
    const DROPPED = 7;
    const ACC_RATE = 8;
    const GYRO_RATE = 9;
    const GYRO_MAX = 10;
}

// Owns the activity recording: session, optional SensorLogger and the FIT
// developer fields.
class Recorder {
    var isPadel as Boolean = false;
    var usesLogger as Boolean = false;

    private var _session as ActivityRecording.Session? = null;
    private var _labelField as FitContributor.Field? = null;
    private var _peakField as FitContributor.Field? = null;
    private var _strokesField as FitContributor.Field? = null;
    private var _lapLabelField as FitContributor.Field? = null;
    private var _totalField as FitContributor.Field? = null;
    private var _droppedField as FitContributor.Field? = null;
    private var _accRateField as FitContributor.Field? = null;
    private var _gyroRateField as FitContributor.Field? = null;
    private var _gyroMaxField as FitContributor.Field? = null;
    private var _lastStrokes as Number = -1;

    function initialize() {
    }

    function hasSession() as Boolean {
        return _session != null;
    }

    function isRecording() as Boolean {
        var session = _session;
        return session != null && session.isRecording();
    }

    function start(useLogger as Boolean, label as Number, streamer as WindowStreamer) as Void {
        var sport = Activity.SPORT_TENNIS;
        var subSport = Activity.SUB_SPORT_MATCH;
        isPadel = (Activity has :SPORT_RACKET) && (Activity has :SUB_SPORT_PADEL);
        if (isPadel) {
            sport = Activity.SPORT_RACKET;
            subSport = Activity.SUB_SPORT_PADEL;
        }

        usesLogger = useLogger && (Toybox has :SensorLogging);
        var session;
        if (usesLogger) {
            var logger = new SensorLogging.SensorLogger({
                :accelerometer => {:enabled => true},
                :gyroscope => {:enabled => true}
            });
            session = ActivityRecording.createSession({
                :name => "Padel Probe",
                :sport => sport,
                :subSport => subSport,
                :sensorLogger => logger
            });
        } else {
            session = ActivityRecording.createSession({
                :name => "Padel Probe",
                :sport => sport,
                :subSport => subSport
            });
        }
        _session = session;

        var record = {:mesgType => FitContributor.MESG_TYPE_RECORD};
        var summary = {:mesgType => FitContributor.MESG_TYPE_SESSION};
        _labelField = session.createField("label", FitIds.LABEL, FitContributor.DATA_TYPE_UINT8, record);
        _peakField = session.createField("gyro_peak", FitIds.GYRO_PEAK, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "deg/s"});
        _strokesField = session.createField("strokes", FitIds.STROKES, FitContributor.DATA_TYPE_UINT16, record);
        streamer.setFields(
            session.createField("win_hdr", FitIds.WIN_HDR, FitContributor.DATA_TYPE_UINT16,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :count => Config.HEADER_VALUES}),
            session.createField("win_data", FitIds.WIN_DATA, FitContributor.DATA_TYPE_SINT16,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :count => Config.CHUNK_VALUES})
        );
        _lapLabelField = session.createField("lap_label", FitIds.LAP_LABEL, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_LAP});
        _totalField = session.createField("total_strokes", FitIds.TOTAL_STROKES, FitContributor.DATA_TYPE_UINT16, summary);
        _droppedField = session.createField("dropped_windows", FitIds.DROPPED, FitContributor.DATA_TYPE_UINT16, summary);
        _accRateField = session.createField("acc_rate", FitIds.ACC_RATE, FitContributor.DATA_TYPE_UINT16, summary);
        _gyroRateField = session.createField("gyro_rate", FitIds.GYRO_RATE, FitContributor.DATA_TYPE_UINT16, summary);
        _gyroMaxField = session.createField("gyro_max", FitIds.GYRO_MAX, FitContributor.DATA_TYPE_UINT16, summary);

        setField(_labelField, label);
        setField(_lapLabelField, label);
        setField(_peakField, 0);
        setField(_strokesField, 0);
        _lastStrokes = 0;

        session.start();
    }

    // Starts a new lap, so every training series gets its own label.
    function setLabel(label as Number) as Void {
        var session = _session;
        if (session != null && session.isRecording()) {
            // The closed lap keeps the previous label.
            session.addLap();
        }
        setField(_lapLabelField, label);
        setField(_labelField, label);
    }

    function lap() as Void {
        var session = _session;
        if (session != null && session.isRecording()) {
            session.addLap();
        }
    }

    // Called once per second while recording.
    function updateSecond(gyroPeak as Number, strokes as Number) as Void {
        setField(_peakField, gyroPeak);
        if (strokes != _lastStrokes) {
            setField(_strokesField, strokes);
            _lastStrokes = strokes;
        }
    }

    function stop(probe as SensorProbe, streamer as WindowStreamer) as Void {
        var session = _session;
        if (session != null && session.isRecording()) {
            writeSummary(probe, streamer);
            session.stop();
        }
    }

    function resume() as Void {
        var session = _session;
        if (session != null && !session.isRecording()) {
            session.start();
        }
    }

    function save(probe as SensorProbe, streamer as WindowStreamer) as Void {
        var session = _session;
        if (session != null) {
            writeSummary(probe, streamer);
            if (session.isRecording()) {
                session.stop();
            }
            session.save();
        }
        clear();
    }

    function discard() as Void {
        var session = _session;
        if (session != null) {
            if (session.isRecording()) {
                session.stop();
            }
            session.discard();
        }
        clear();
    }

    private function writeSummary(probe as SensorProbe, streamer as WindowStreamer) as Void {
        setField(_totalField, probe.strokes);
        setField(_droppedField, streamer.dropped);
        setField(_accRateField, probe.accRate());
        setField(_gyroRateField, probe.gyroRate());
        setField(_gyroMaxField, probe.maxGyroNorm > 65000 ? 65000 : probe.maxGyroNorm);
    }

    private function setField(field as FitContributor.Field?, value as Number) as Void {
        if (field != null) {
            field.setData(value);
        }
    }

    private function clear() as Void {
        _session = null;
        _labelField = null;
        _peakField = null;
        _strokesField = null;
        _lapLabelField = null;
        _totalField = null;
        _droppedField = null;
        _accRateField = null;
        _gyroRateField = null;
        _gyroMaxField = null;
    }
}
