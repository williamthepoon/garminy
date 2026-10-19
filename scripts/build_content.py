#!/usr/bin/env python3
"""Validate content/*.json and generate chunked Connect IQ JSON resources.

Run from the repo root: python3 scripts/build_content.py
"""
import calendar
import json
import os
import sys

CHUNK = 40
MAX_LEN = 90
OUT = "resources/jsonData"


def fail(msg):
    sys.exit("content error: " + msg)


def check_text(label, text):
    if not isinstance(text, str) or not text.strip():
        fail(f"{label}: empty text")
    if len(text) > MAX_LEN:
        fail(f"{label}: {len(text)} chars > {MAX_LEN}: {text}")


def write_chunks(name, items, xml):
    if len(items) % CHUNK != 0:
        fail(f"{name}: {len(items)} entries is not a multiple of {CHUNK}")
    for i in range(len(items) // CHUNK):
        fname = f"{name}{i}.json"
        with open(os.path.join(OUT, fname), "w") as f:
            json.dump(items[i * CHUNK:(i + 1) * CHUNK], f, ensure_ascii=False)
        xml.append(f'    <jsonData id="{name}{i}" filename="{fname}" />')


def main():
    os.makedirs(OUT, exist_ok=True)
    xml = ["<jsonDataResources>"]

    fortunes = json.load(open("content/fortunes.json"))
    for i, t in enumerate(fortunes):
        check_text(f"fortune {i}", t)
    if len(set(fortunes)) != len(fortunes):
        fail("duplicate fortune")
    write_chunks("fortunes", fortunes, xml)

    quotes = json.load(open("content/quotes.json"))
    for i, q in enumerate(quotes):
        check_text(f"quote {i}", q[0])
        if not q[1].strip():
            fail(f"quote {i}: missing attribution")
    if len(set(q[0] for q in quotes)) != len(quotes):
        fail("duplicate quote")
    # Authors stay in content/quotes.json as the source record; the watch shows the text only.
    write_chunks("quotes", [q[0] for q in quotes], xml)

    otd = json.load(open("content/onthisday.json"))
    for m in range(1, 13):
        days = 29 if m == 2 else calendar.monthrange(2023, m)[1]
        month = []
        for d in range(1, days + 1):
            key = f"{m:02d}-{d:02d}"
            if key not in otd:
                fail(f"on this day: missing {key}")
            year, text = otd[key]
            if not isinstance(year, int) or year < 1 or year > 2100:
                fail(f"on this day {key}: bad year {year}")
            check_text(f"on this day {key}", text)
            month.append([year, text])
        fname = f"otd{m:02d}.json"
        with open(os.path.join(OUT, fname), "w") as f:
            json.dump(month, f, ensure_ascii=False)
        xml.append(f'    <jsonData id="otd{m:02d}" filename="{fname}" />')
    if len(otd) != 366:
        fail(f"on this day: {len(otd)} entries, expected 366")

    xml.append("</jsonDataResources>")
    with open(os.path.join(OUT, "jsonData.xml"), "w") as f:
        f.write("\n".join(xml) + "\n")
    print(f"ok: {len(fortunes)} fortunes, {len(quotes)} quotes, {len(otd)} days")


if __name__ == "__main__":
    main()
