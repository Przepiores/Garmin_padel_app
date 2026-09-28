import Toybox.Lang;

// Tunable parameters of the probe. The values are first guesses; refine them
// after the first court session (see docs/PLAN_TESTU.md).
module Config {
    // Requested sensor rate in Hz, capped by the device maximum.
    const TARGET_RATE_HZ = 100;

    // |omega| above which a stroke candidate starts (deg/s).
    const STROKE_THRESHOLD_DPS = 400;

    // Part of the signal saved around the |omega| peak (ms).
    const WINDOW_PRE_MS = 500;
    const WINDOW_POST_MS = 300;

    // Minimum time between two detected strokes (ms).
    const REFRACTORY_MS = 600;

    // Stroke windows waiting to be written; newer ones are dropped when full.
    const MAX_QUEUED_WINDOWS = 20;

    // FIT chunk layout, must match tools/fit_probe.py. Header (6 x uint16) +
    // data (112 x sint16) + the small record fields stay below the 256 B
    // per-message limit that Connect IQ apps have.
    const HEADER_VALUES = 6;
    const CHUNK_VALUES = 112;

    // A chunk stays in the fields longer than the 1 s record interval, so it
    // is never overwritten before being written. Duplicates are removed by
    // tools/fit_probe.py.
    const CHUNK_PERIOD_MS = 1250;

    // uint16 FIT fields treat 65535 as "invalid", sint16 fields 32767.
    const MAX_WINDOW_ID = 60000;
    const MAX_SINT16 = 32000;
}
