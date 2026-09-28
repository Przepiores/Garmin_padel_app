"""Analiza pliku FIT nagranego aplikacją Padel Probe.

Odpowiada na pytania spike'a technicznego (docs/SPECYFIKACJA.md, sekcja 7):
  1. z jaką częstotliwością zegarek oddaje akcelerometr i żyroskop,
  2. czy da się wyciągnąć surowe dane uderzeń z zegarka (SensorLogger
     i wycinki zapisane w polach deweloperskich FIT),
  3. jako jaki sport została zapisana aktywność.

Dodatkowo składa wycinki uderzeń z porcji zapisanych w rekordach i zapisuje
je do CSV, żeby można było na nich trenować klasyfikator.

Użycie:
    python fit_probe.py AKTYWNOSC.fit [--out KATALOG] [--plot]
"""

from __future__ import annotations

import argparse
import csv
import math
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from garmin_fit_sdk import Decoder, Stream

# Musi się zgadzać z app/source/Labels.mc.
LABELS = {
    0: "brak",
    1: "smash",
    2: "bandeja",
    3: "vibora",
    4: "inne_uderzenie",
    5: "nie_uderzenie",
}

# Musi się zgadzać z app/source/Config.mc.
HEADER_VALUES = 6
CHUNK_VALUES = 112
AXES = ("ax_mg", "ay_mg", "az_mg", "gx_dps", "gy_dps", "gz_dps")


@dataclass
class Window:
    """Wycinek sygnału wokół jednego wykrytego uderzenia."""

    window_id: int
    label: int
    sample_rate: int
    samples: int
    pre: int
    first_timestamp: int
    chunks: dict[int, list[int]] = field(default_factory=dict)
    duplicates: int = 0

    @property
    def expected_chunks(self) -> int:
        return math.ceil(self.samples * len(AXES) / CHUNK_VALUES)

    @property
    def complete(self) -> bool:
        return all(i in self.chunks for i in range(self.expected_chunks))

    def rows(self) -> list[list[int]]:
        """Zwraca próbki jako listę [ax, ay, az, gx, gy, gz]."""
        values: list[int] = []
        for i in range(self.expected_chunks):
            values.extend(self.chunks[i])
        values = values[: self.samples * len(AXES)]
        return [values[i : i + len(AXES)] for i in range(0, len(values), len(AXES))]

    def peak_dps(self) -> float:
        return max(math.sqrt(r[3] ** 2 + r[4] ** 2 + r[5] ** 2) for r in self.rows())


@dataclass
class SensorStream:
    """Dane zapisane przez SensorLogger (accelerometer_data / gyroscope_data)."""

    name: str
    messages: int = 0
    samples: int = 0
    first_timestamp: int | None = None
    last_timestamp: int | None = None
    samples_per_message: Counter = field(default_factory=Counter)
    value_fields: set[str] = field(default_factory=set)
    max_abs: float = 0.0

    @property
    def duration_s(self) -> int:
        if self.first_timestamp is None or self.last_timestamp is None:
            return 0
        # Ostatni komunikat obejmuje jeszcze około sekundy danych.
        return self.last_timestamp - self.first_timestamp + 1

    @property
    def rate_hz(self) -> float:
        return self.samples / self.duration_s if self.duration_s else 0.0


def decode(path: Path) -> dict:
    stream = Stream.from_file(str(path))
    decoder = Decoder(stream)
    if not decoder.is_fit():
        raise SystemExit(f"{path} nie jest plikiem FIT")
    messages, errors = decoder.read(convert_datetimes_to_dates=False)
    if errors:
        print(f"UWAGA: błędy dekodowania: {errors}", file=sys.stderr)
    return messages


def developer_keys(messages: dict) -> dict[str, int]:
    """Mapuje nazwy pól deweloperskich na klucze używane przez dekoder."""
    keys = {}
    for desc in messages.get("field_description_mesgs", []):
        name = desc.get("field_name")
        if name is not None and name not in keys:
            keys[name] = desc["key"]
    return keys


def dev(mesg: dict, keys: dict[str, int], name: str):
    key = keys.get(name)
    if key is None:
        return None
    return mesg.get("developer_fields", {}).get(key)


def as_list(value) -> list:
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return [v for v in value if v is not None]
    return [value]


def read_sensor_stream(messages: dict, key: str, name: str, prefix: str) -> SensorStream:
    result = SensorStream(name=name)
    candidates = (f"calibrated_{prefix}_x", f"compressed_calibrated_{prefix}_x", f"{prefix}_x")
    for mesg in messages.get(key, []):
        result.messages += 1
        ts = mesg.get("timestamp")
        if ts is not None:
            result.first_timestamp = ts if result.first_timestamp is None else result.first_timestamp
            result.last_timestamp = ts
        for field_name in candidates:
            values = as_list(mesg.get(field_name))
            if values:
                result.value_fields.add(field_name)
                result.samples += len(values)
                result.samples_per_message[len(values)] += 1
                if field_name.startswith("calibrated") or field_name.startswith("compressed"):
                    result.max_abs = max(result.max_abs, max(abs(v) for v in values))
                break
    return result


def collect_windows(messages: dict, keys: dict[str, int]) -> tuple[dict[int, Window], int]:
    windows: dict[int, Window] = {}
    chunk_records = 0
    for record in messages.get("record_mesgs", []):
        header = as_list(dev(record, keys, "win_hdr"))
        data = as_list(dev(record, keys, "win_data"))
        if len(header) != HEADER_VALUES or header[0] == 0:
            continue
        window_id, chunk_idx, samples, label, rate, pre = header
        chunk_records += 1
        window = windows.get(window_id)
        if window is None:
            window = Window(window_id, label, rate, samples, pre, record.get("timestamp", 0))
            windows[window_id] = window
        if chunk_idx in window.chunks:
            window.duplicates += 1
            continue
        window.chunks[chunk_idx] = data
    return windows, chunk_records


def write_windows(windows: dict[int, Window], out_dir: Path) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    samples_path = out_dir / "windows.csv"
    summary_path = out_dir / "windows_summary.csv"
    with samples_path.open("w", newline="") as f_samples, summary_path.open("w", newline="") as f_summary:
        samples_csv = csv.writer(f_samples)
        summary_csv = csv.writer(f_summary)
        samples_csv.writerow(["window_id", "label", "sample_rate", "sample", "t_ms", *AXES])
        summary_csv.writerow(
            ["window_id", "label", "sample_rate", "samples", "pre_samples",
             "chunks_received", "chunks_expected", "complete", "peak_dps", "fit_timestamp"]
        )
        for window in sorted(windows.values(), key=lambda w: w.window_id):
            label = LABELS.get(window.label, str(window.label))
            peak = ""
            if window.complete:
                for i, row in enumerate(window.rows()):
                    t_ms = round((i - window.pre) * 1000 / window.sample_rate) if window.sample_rate else ""
                    samples_csv.writerow([window.window_id, label, window.sample_rate, i, t_ms, *row])
                peak = round(window.peak_dps())
            summary_csv.writerow(
                [window.window_id, label, window.sample_rate, window.samples, window.pre,
                 len(window.chunks), window.expected_chunks, window.complete, peak, window.first_timestamp]
            )
    return samples_path, summary_path


def plot_windows(windows: dict[int, Window], out_dir: Path) -> Path | None:
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("Brak matplotlib, pomijam wykres (pip install matplotlib).")
        return None

    by_label: dict[int, list[Window]] = defaultdict(list)
    for window in windows.values():
        if window.complete:
            by_label[window.label].append(window)
    if not by_label:
        return None

    labels = sorted(by_label)
    fig, axes = plt.subplots(len(labels), 1, figsize=(9, 3 * len(labels)), squeeze=False)
    for ax, label in zip(axes[:, 0], labels):
        for window in by_label[label]:
            rows = window.rows()
            t = [(i - window.pre) * 1000 / window.sample_rate for i in range(len(rows))]
            omega = [math.sqrt(r[3] ** 2 + r[4] ** 2 + r[5] ** 2) for r in rows]
            ax.plot(t, omega, alpha=0.5, linewidth=1)
        ax.set_title(f"{LABELS.get(label, label)} (n={len(by_label[label])})")
        ax.set_xlabel("czas względem szczytu [ms]")
        ax.set_ylabel("|ω| [°/s]")
        ax.axvline(0, color="grey", linewidth=0.5)
    fig.tight_layout()
    path = out_dir / "windows_omega.png"
    fig.savefig(path, dpi=120)
    return path


def fmt_hist(counter: Counter, limit: int = 6) -> str:
    return ", ".join(f"{k}: {v}x" for k, v in counter.most_common(limit)) or "-"


def report(path: Path, out_dir: Path, plot: bool) -> int:
    messages = decode(path)
    keys = developer_keys(messages)

    print(f"Plik: {path}\n")

    # 3. Typ aktywności
    print("== Aktywność ==")
    for session in messages.get("session_mesgs", []):
        print(f"  sport: {session.get('sport')} / {session.get('sub_sport')}")
        print(f"  czas: {session.get('total_timer_time')} s")
        for name in ("total_strokes", "gyro_max", "acc_rate", "gyro_rate", "dropped_windows"):
            print(f"  {name}: {dev(session, keys, name)}")
    print()

    # Interwał zapisu rekordów (Smart Recording zgubi porcje wycinków)
    records = messages.get("record_mesgs", [])
    timestamps = [r["timestamp"] for r in records if r.get("timestamp") is not None]
    deltas = Counter(b - a for a, b in zip(timestamps, timestamps[1:]))
    print("== Rekordy ==")
    print(f"  liczba: {len(records)}, odstępy [s]: {fmt_hist(deltas)}")
    if deltas and set(deltas) - {1}:
        print("  UWAGA: odstępy inne niż 1 s. Włącz zapis 'Co sekundę' w ustawieniach zegarka.")
    print()

    # 1 i 2. SensorLogger
    print("== SensorLogger (surowe dane w pliku FIT) ==")
    for stream in (
        read_sensor_stream(messages, "accelerometer_data_mesgs", "akcelerometr", "accel"),
        read_sensor_stream(messages, "gyroscope_data_mesgs", "żyroskop", "gyro"),
    ):
        if stream.messages == 0:
            print(f"  {stream.name}: brak danych")
            continue
        print(
            f"  {stream.name}: {stream.samples} próbek w {stream.duration_s} s "
            f"≈ {stream.rate_hz:.1f} Hz; próbek na komunikat: {fmt_hist(stream.samples_per_message)}"
        )
        print(f"    pola: {', '.join(sorted(stream.value_fields))}; max |oś x|: {stream.max_abs:.1f}")
    calibrations = messages.get("three_d_sensor_calibration_mesgs", [])
    print(f"  komunikaty kalibracji 3D: {len(calibrations)}")
    print()

    # 2. Wycinki uderzeń w polach deweloperskich
    print("== Wycinki uderzeń (pola deweloperskie) ==")
    windows, chunk_records = collect_windows(messages, keys)
    complete = [w for w in windows.values() if w.complete]
    duplicates = sum(w.duplicates for w in windows.values())
    print(f"  rekordów z porcjami: {chunk_records} (duplikaty: {duplicates})")
    print(f"  wycinków: {len(windows)}, kompletnych: {len(complete)}")
    if windows:
        ids = sorted(windows)
        missing_ids = sorted(set(range(ids[0], ids[-1] + 1)) - set(ids))
        if missing_ids:
            print(f"  UWAGA: brakujące wycinki (zgubione w całości): {missing_ids[:20]}")
        rates = Counter(w.sample_rate for w in windows.values())
        print(f"  częstotliwość w wycinkach [Hz]: {fmt_hist(rates)}")
        per_label = Counter(LABELS.get(w.label, w.label) for w in complete)
        print(f"  kompletne wg etykiety: {dict(per_label)}")
        if complete:
            peaks = sorted((round(w.peak_dps()) for w in complete), reverse=True)
            print(f"  najwyższe szczyty |ω| [°/s]: {peaks[:10]}")
            axis_max = Counter(max(abs(v) for r in w.rows() for v in r[3:]) for w in complete)
            top_value, top_count = axis_max.most_common(1)[0]
            if top_count >= 3:
                print(f"  UWAGA: {top_count} wycinków ma identyczne maksimum osi {top_value} °/s "
                      "(możliwe nasycenie żyroskopu)")
        samples_path, summary_path = write_windows(windows, out_dir)
        print(f"  zapisano: {samples_path}, {summary_path}")
        if plot:
            plot_path = plot_windows(windows, out_dir)
            if plot_path:
                print(f"  wykres: {plot_path}")
    print()

    # Etykiety okrążeń (serie w trybie treningowym)
    laps = messages.get("lap_mesgs", [])
    if laps:
        print("== Okrążenia (serie z etykietą) ==")
        for i, lap in enumerate(laps, 1):
            label = dev(lap, keys, "lap_label")
            print(f"  {i}: {LABELS.get(label, label)}, {lap.get('total_timer_time')} s")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("fit", type=Path, help="plik .fit pobrany z Garmin Connect")
    parser.add_argument("--out", type=Path, default=None, help="katalog wynikowy (domyślnie obok pliku)")
    parser.add_argument("--plot", action="store_true", help="zapisz wykres |ω| wycinków")
    args = parser.parse_args(argv)
    out_dir = args.out or args.fit.with_suffix("")
    return report(args.fit, out_dir, args.plot)


if __name__ == "__main__":
    sys.exit(main())
