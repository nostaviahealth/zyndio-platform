#!/usr/bin/env python3
"""APP-05 golden lab fixtures: FICTIONAL reports for the demo patient.

Jordan Rivera (flutter_app/lib/demo/data/fixtures.dart) is a made-up person;
every value, date and the lab are invented. Nothing here is a real report.

Writes, next to this script:
  jordan-rivera-<date>-<us|si>.pdf   one-page text PDF
  jordan-rivera-<date>-<us|si>.png   the same report as an image
  golden.json                        what a correct extractor reads off each
                                     file, and the canonical (US) values the
                                     pipeline must produce from it

US and SI versions of the same report print different numbers that must
normalise to identical canonical values (tests/lab-pipeline/golden.test.ts).

Run: python3 tests/fixtures/labs/generate_fixtures.py   (needs Pillow)
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

PATIENT = {"printed_name": "RIVERA, JORDAN", "printed_dob": "03/14/1979"}
LAB = "Fictional Reference Lab"

# (printed analyte, canonical key, {units: (value, unit, range)}, canonical value)
REPORTS = {
    "2026-04-02": [
        ("Hemoglobin A1c", "hba1c", {"us": ("6.2", "%", "<5.7"), "si": ("44", "mmol/mol", "<39")}, 6.2),
        ("Glucose, Fasting", "glucose_fasting", {"us": ("104", "mg/dL", "70-99"), "si": ("5.8", "mmol/L", "3.9-5.5")}, 104),
        ("Insulin, Fasting", "insulin_fasting", {"us": ("18.1", "uIU/mL", "2.6-24.9"), "si": ("108.6", "pmol/L", "15.6-149.4")}, 18.1),
        ("Apolipoprotein B", "apob", {"us": ("106", "mg/dL", "<90"), "si": ("1.06", "g/L", "<0.90")}, 106),
        ("hs-CRP", "hscrp", {"us": ("3.8", "mg/L", "<3.0"), "si": ("0.38", "mg/dL", "<0.30")}, 3.8),
        ("Triglycerides", "triglycerides", {"us": ("168", "mg/dL", "<150"), "si": ("1.90", "mmol/L", "<1.70")}, 168),
        ("Vitamin D, 25-Hydroxy", "vitamin_d", {"us": ("28", "ng/mL", "30-100"), "si": ("69.9", "nmol/L", "75-250")}, 28),
    ],
    "2026-10-14": [
        ("Hemoglobin A1c", "hba1c", {"us": ("5.5", "%", "<5.7"), "si": ("37", "mmol/mol", "<39")}, 5.5),
        ("Glucose, Fasting", "glucose_fasting", {"us": ("97", "mg/dL", "70-99"), "si": ("5.4", "mmol/L", "3.9-5.5")}, 97),
        ("Insulin, Fasting", "insulin_fasting", {"us": ("9.4", "uIU/mL", "2.6-24.9"), "si": ("56.4", "pmol/L", "15.6-149.4")}, 9.4),
        ("Apolipoprotein B", "apob", {"us": ("84", "mg/dL", "<90"), "si": ("0.84", "g/L", "<0.90")}, 84),
        ("hs-CRP", "hscrp", {"us": ("1.7", "mg/L", "<3.0"), "si": ("0.17", "mg/dL", "<0.30")}, 1.7),
        ("Triglycerides", "triglycerides", {"us": ("121", "mg/dL", "<150"), "si": ("1.37", "mmol/L", "<1.70")}, 121),
        ("Vitamin D, 25-Hydroxy", "vitamin_d", {"us": ("41", "ng/mL", "30-100"), "si": ("102.3", "nmol/L", "75-250")}, 41),
    ],
}

BANNER = "FICTIONAL SAMPLE REPORT - NOT A REAL PATIENT - FOR SOFTWARE TESTING ONLY"


def us_date(iso):
    y, m, d = iso.split("-")
    return f"{m}/{d}/{y}"


def lines_for(date, units):
    rows = [
        LAB,
        BANNER,
        "",
        f"Patient: {PATIENT['printed_name']}",
        f"DOB: {PATIENT['printed_dob']}",
        f"Collected: {us_date(date)}",
        "",
        f"{'Test':<26}{'Result':<10}{'Units':<12}Reference range",
    ]
    for printed, _key, by_units, _canon in REPORTS[date]:
        value, unit, rng = by_units[units]
        rows.append(f"{printed:<26}{value:<10}{unit:<12}{rng}")
    return rows


def pdf_escape(s):
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def write_pdf(path, lines):
    content = ["BT", "/F1 10 Tf", "12 TL", "50 780 Td"]
    for line in lines:
        content.append(f"({pdf_escape(line)}) Tj T*")
    content.append("ET")
    stream = "\n".join(content).encode("ascii")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + obj + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objects) + 1, xref)
    with open(path, "wb") as f:
        f.write(out)


def write_png(path, lines):
    font = ImageFont.load_default(size=18)
    img = Image.new("L", (1000, 60 + 26 * len(lines)), 255)
    draw = ImageDraw.Draw(img)
    for i, line in enumerate(lines):
        # Monospace-ish columns: draw each fixed-width cell at its own x.
        if i >= 7:
            cells = [line[0:26], line[26:36], line[36:48], line[48:]]
            for x, cell in zip((30, 330, 450, 600), cells):
                draw.text((x, 30 + 26 * i), cell.strip(), fill=0, font=font)
        else:
            draw.text((30, 30 + 26 * i), line, fill=0, font=font)
    img.save(path, optimize=True)


def main():
    golden = {"_comment": (
        "APP-05 golden fixtures (FICTIONAL - generated by generate_fixtures.py). "
        "`extraction` is what a correct extractor reads off the file (text exactly as printed, "
        "confidence 0.97); `expected` is the canonical US value the pipeline must file for each "
        "analyte. US and SI files of the same date must give identical `expected` values."
    ), "account": {"name": "Jordan Rivera", "dob": "1979-03-14"}, "reports": []}
    for date in REPORTS:
        for units in ("us", "si"):
            lines = lines_for(date, units)
            base = f"jordan-rivera-{date}-{units}"
            write_pdf(os.path.join(HERE, base + ".pdf"), lines)
            write_png(os.path.join(HERE, base + ".png"), lines)
            sure = {"analyte": 0.97, "value": 0.97, "unit": 0.97, "reference_range": 0.97}
            extraction = {
                "patient_name": PATIENT["printed_name"],
                "patient_dob": PATIENT["printed_dob"],
                "collection_date": us_date(date),
                "lab_name": LAB,
                "confidence": {"patient_name": 0.97, "patient_dob": 0.97, "collection_date": 0.97, "lab_name": 0.97},
                "results": [
                    {"analyte": p, "value": v[units][0], "unit": v[units][1], "reference_range": v[units][2], "confidence": sure}
                    for p, _k, v, _c in REPORTS[date]
                ],
            }
            golden["reports"].append({
                "files": [base + ".pdf", base + ".png"],
                "collected_on": date,
                "units": units,
                "extraction": extraction,
                "expected": {k: c for _p, k, _v, c in REPORTS[date]},
            })
    with open(os.path.join(HERE, "golden.json"), "w") as f:
        json.dump(golden, f, indent=2)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
