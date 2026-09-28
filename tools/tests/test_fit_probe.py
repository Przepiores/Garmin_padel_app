"""Testy parsera na syntetycznym pliku FIT w formacie aplikacji Padel Probe.

Uruchomienie (z katalogu tools/):
    python -m unittest discover tests
"""

import csv
import io
import math
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from garmin_fit_sdk import Encoder, Profile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fit_probe  # noqa: E402

MESG = Profile["mesg_num"]
START = 1_000_000_000  # znacznik czasu FIT (sekundy od 1989-12-31)

# (nazwa, numer pola, typ bazowy FIT, liczba elementów)
DEV_FIELDS = [
    ("label", 0, 0x02, 1),
    ("gyro_peak", 1, 0x84, 1),
    ("strokes", 2, 0x84, 1),
    ("win_hdr", 3, 0x84, fit_probe.HEADER_VALUES),
    ("win_data", 4, 0x83, fit_probe.CHUNK_VALUES),
    ("lap_label", 5, 0x02, 1),
    ("total_strokes", 6, 0x84, 1),
    ("dropped_windows", 7, 0x84, 1),
    ("acc_rate", 8, 0x84, 1),
    ("gyro_rate", 9, 0x84, 1),
    ("gyro_max", 10, 0x84, 1),
]
KEY = {name: i for i, (name, *_rest) in enumerate(DEV_FIELDS)}


def make_window(seed: int, samples: int = 80) -> list[int]:
    """Deterministyczny sygnał: 6 osi przeplatanych, szczyt |ω| w środku."""
    values = []
    for i in range(samples):
        bump = math.exp(-((i - 50) ** 2) / 30)
        values += [
            seed * 10 + i,
            -500 + i,
            1000,
            round(1500 * bump) + seed,
            round(-800 * bump),
            i % 7,
        ]
    return values


def chunks_of(values: list[int]) -> list[list[int]]:
    n = fit_probe.CHUNK_VALUES
    out = []
    for i in range(0, len(values), n):
        chunk = values[i : i + n]
        out.append(chunk + [0] * (n - len(chunk)))
    return out


def build_fit(path: Path, windows: dict[int, tuple[int, list[int]]], drop: set, duplicate: set) -> None:
    dev_id = {
        "mesg_num": MESG["DEVELOPER_DATA_ID"],
        "developer_data_index": 0,
        "application_id": list(range(16)),
    }
    descriptions = {}
    for key, (name, number, base_type, count) in enumerate(DEV_FIELDS):
        descriptions[key] = {
            "developer_data_id_mesg": dev_id,
            "field_description_mesg": {
                "mesg_num": MESG["FIELD_DESCRIPTION"],
                "developer_data_index": 0,
                "field_definition_number": number,
                "fit_base_type_id": base_type,
                "field_name": name,
                "array": count if count > 1 else None,
            },
        }

    enc = Encoder(field_descriptions=descriptions)
    enc.write_mesg({"mesg_num": MESG["FILE_ID"], "type": "activity", "manufacturer": "garmin",
                    "product": 1, "time_created": START})
    enc.write_mesg(dev_id)
    for desc in descriptions.values():
        enc.write_mesg(desc["field_description_mesg"])

    t = START
    # Rekordy: nagłówek + porcja wycinka co sekundę, jak w WindowStreamer.
    for window_id, (label, values) in windows.items():
        for chunk_idx, chunk in enumerate(chunks_of(values)):
            if (window_id, chunk_idx) in drop:
                continue
            header = [window_id, chunk_idx, len(values) // 6, label, 100, 50]
            repeat = 2 if (window_id, chunk_idx) in duplicate else 1
            for _ in range(repeat):
                enc.write_mesg({"mesg_num": MESG["RECORD"], "timestamp": t, "heart_rate": 120,
                                "developer_fields": {KEY["label"]: label, KEY["gyro_peak"]: 900,
                                                     KEY["strokes"]: window_id,
                                                     KEY["win_hdr"]: header, KEY["win_data"]: chunk}})
                t += 1
    # Rekord bezczynny: nagłówek wyzerowany.
    enc.write_mesg({"mesg_num": MESG["RECORD"], "timestamp": t,
                    "developer_fields": {KEY["win_hdr"]: [0] * 6, KEY["win_data"]: [0] * 112}})

    # SensorLogger: 25 próbek na komunikat przez 10 s.
    for s in range(10):
        enc.write_mesg({"mesg_num": MESG["ACCELEROMETER_DATA"], "timestamp": START + s,
                        "sample_time_offset": [i * 40 for i in range(25)],
                        "calibrated_accel_x": [0.5] * 25, "calibrated_accel_y": [0.1] * 25,
                        "calibrated_accel_z": [-1.0] * 25})
        enc.write_mesg({"mesg_num": MESG["GYROSCOPE_DATA"], "timestamp": START + s,
                        "sample_time_offset": [i * 40 for i in range(25)],
                        "calibrated_gyro_x": [100.0] * 25, "calibrated_gyro_y": [0.0] * 25,
                        "calibrated_gyro_z": [-50.0] * 25})

    enc.write_mesg({"mesg_num": MESG["LAP"], "timestamp": t, "start_time": START,
                    "total_timer_time": 30.0, "developer_fields": {KEY["lap_label"]: 2}})
    enc.write_mesg({"mesg_num": MESG["SESSION"], "timestamp": t, "start_time": START,
                    "total_timer_time": 60.0, "sport": 64, "sub_sport": 85,
                    "developer_fields": {KEY["total_strokes"]: len(windows), KEY["gyro_max"]: 1510,
                                         KEY["acc_rate"]: 100, KEY["gyro_rate"]: 100,
                                         KEY["dropped_windows"]: 0}})
    path.write_bytes(enc.close())


class FitProbeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.windows = {1: (2, make_window(1)), 2: (1, make_window(2)), 3: (3, make_window(3))}
        self.fit = self.dir / "probe.fit"
        build_fit(self.fit, self.windows, drop={(3, 1)}, duplicate={(1, 2)})

    def tearDown(self):
        self.tmp.cleanup()

    def run_report(self) -> str:
        buf = io.StringIO()
        with redirect_stdout(buf):
            fit_probe.report(self.fit, self.dir / "out", plot=False)
        return buf.getvalue()

    def test_windows_are_reassembled_exactly(self):
        messages = fit_probe.decode(self.fit)
        keys = fit_probe.developer_keys(messages)
        windows, chunk_records = fit_probe.collect_windows(messages, keys)

        self.assertEqual(sorted(windows), [1, 2, 3])
        self.assertEqual(windows[1].duplicates, 1)
        self.assertTrue(windows[1].complete)
        self.assertTrue(windows[2].complete)
        self.assertFalse(windows[3].complete)
        for window_id in (1, 2):
            label, values = self.windows[window_id]
            flat = [v for row in windows[window_id].rows() for v in row]
            self.assertEqual(flat, values)
            self.assertEqual(windows[window_id].label, label)

    def test_report_and_csv(self):
        out = self.run_report()
        self.assertIn("racket / padel", out)
        self.assertIn("wycinków: 3, kompletnych: 2", out)
        self.assertIn("akcelerometr: 250 próbek w 10 s ≈ 25.0 Hz", out)
        self.assertIn("żyroskop: 250 próbek w 10 s ≈ 25.0 Hz", out)
        self.assertIn("1: bandeja", out)

        with (self.dir / "out" / "windows_summary.csv").open() as f:
            rows = list(csv.DictReader(f))
        self.assertEqual([r["complete"] for r in rows], ["True", "True", "False"])
        self.assertEqual(rows[0]["label"], "bandeja")
        with (self.dir / "out" / "windows.csv").open() as f:
            samples = list(csv.DictReader(f))
        self.assertEqual(len(samples), 2 * 80)
        self.assertEqual(samples[50]["t_ms"], "0")


if __name__ == "__main__":
    unittest.main()
