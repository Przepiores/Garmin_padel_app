import Toybox.Lang;
import Toybox.WatchUi;

// Stroke labels, stored as uint8 in the FIT file. Keep in sync with LABELS in
// tools/fit_probe.py.
module Labels {
    const NONE = 0;
    const SMASH = 1;
    const BANDEJA = 2;
    const VIBORA = 3;
    const OTHER_STROKE = 4;
    const NOT_STROKE = 5;
    const COUNT = 6;

    function name(label as Number) as String {
        var ids = [
            Rez.Strings.LabelNone,
            Rez.Strings.LabelSmash,
            Rez.Strings.LabelBandeja,
            Rez.Strings.LabelVibora,
            Rez.Strings.LabelOther,
            Rez.Strings.LabelNotStroke
        ];
        return WatchUi.loadResource(ids[label]) as String;
    }
}
