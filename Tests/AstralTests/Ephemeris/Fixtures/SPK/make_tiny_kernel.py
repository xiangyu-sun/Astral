// swiftlint:disable no_direct_standard_out_logs
#!/usr/bin/env python3
"""Cut a tiny, valid NAIF DAF/SPK kernel out of de440s.bsp.

Usage:  python3 -I make_tiny_kernel.py /path/to/de440s.bsp tiny.bsp

de440s.bsp (about 31 MB) is NOT committed; it is public at
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de440s.bsp
(MD5 3917ee56769db332790c751e2168843d). The output keeps, for every Type 2 segment of de440s, only the Chebyshev
records that overlap WINDOW (2026-07-01 .. 2026-12-31). The coefficient records are copied unchanged; only the
DAF framing (file record, comment record, summary/name records, segment trailer INIT/INTLEN/RSIZE/N) is rewritten,
so the result is a self-contained little-endian DAF/SPK. Segment descriptor start/stop times are clamped to WINDOW.

Standard library only.
"""
import struct
import sys

ND, NI = 2, 6
SS = ND + (NI + 1) // 2  # summary size in doubles (5)
J2000_JD = 2451545.0
# 2026-07-01 00:00 and 2026-12-31 00:00 as TDB seconds past J2000.
WINDOW = ((2461222.5 - J2000_JD) * 86400.0, (2461405.5 - J2000_JD) * 86400.0)


def read_daf(path):
    """Return (endian prefix, list of segment tuples, raw bytes) for a DAF/SPK file."""
    raw = open(path, "rb").read()
    assert raw[:7] == b"DAF/SPK", "not an SPK"
    fmt = raw[88:96].decode("ascii").strip()
    e = "<" if fmt == "LTL-IEEE" else ">"
    nd, ni = struct.unpack(e + "ii", raw[8:16])
    assert (nd, ni) == (ND, NI)
    fward = struct.unpack(e + "i", raw[76:80])[0]
    segs = []
    rec = fward
    while rec:
        base = (rec - 1) * 1024
        nxt, _prev, n = struct.unpack(e + "ddd", raw[base:base + 24])
        for k in range(int(n)):
            off = base + 24 + k * SS * 8
            start, stop = struct.unpack(e + "dd", raw[off:off + 16])
            target, center, frame, dtype, a0, a1 = struct.unpack(e + "6i", raw[off + 16:off + 40])
            noff = rec * 1024 + k * SS * 8  # the name record follows its summary record
            name = raw[noff:noff + SS * 8].decode("ascii").strip()
            segs.append((name, target, center, frame, dtype, start, stop, a0, a1))
        rec = int(nxt)
    return e, segs, raw


def main(src, dst):
    e, segs, raw = read_daf(src)
    w0, w1 = WINDOW
    out_segs = []
    for name, target, center, frame, dtype, start, stop, a0, a1 in segs:
        assert dtype == 2, "only Type 2 expected in de440s"
        init, intlen, rsize, n = struct.unpack(e + "4d", raw[a1 * 8 - 32:a1 * 8])
        rsize, n = int(rsize), int(n)
        first = max(0, int((w0 - init) // intlen))
        last = min(n - 1, int((w1 - init) // intlen))
        recs = b"".join(
            raw[(a0 - 1 + i * rsize) * 8:(a0 - 1 + (i + 1) * rsize) * 8] for i in range(first, last + 1))
        if e == ">":  # re-encode big-endian coefficients as little-endian
            vals = struct.unpack(">%dd" % (len(recs) // 8), recs)
            recs = struct.pack("<%dd" % len(vals), *vals)
        count = last - first + 1
        trailer = struct.pack("<4d", init + first * intlen, intlen, float(rsize), float(count))
        out_segs.append((name, target, center, frame, max(start, w0), min(stop, w1), recs + trailer))

    comment = (
        "Tiny SPK cut from de440s.bsp for Astral's tests.\n"
        "Type 2 records overlapping 2026-07-01..2026-12-31 only.\n"
        "Source: NAIF generic_kernels/spk/planets/de440s.bsp (JPL DE440).\n"
    )
    comment_rec = (comment.replace("\n", "\0") + "\x04").encode("ascii").ljust(1024, b"\0")

    # Layout: rec 1 file record, rec 2 comments, rec 3 summaries, rec 4 names, data from rec 5.
    assert len(out_segs) <= 24
    next_word = 4 * 128 + 1  # first data word address (1-based)
    summaries, names, blob = b"", b"", b""
    for name, target, center, frame, start, stop, data in out_segs:
        nwords = len(data) // 8
        a0, a1 = next_word, next_word + nwords - 1
        summaries += struct.pack("<dd6i", start, stop, target, center, frame, 2, a0, a1)
        names += name.encode("ascii")[:SS * 8].ljust(SS * 8)
        blob += data
        next_word = a1 + 1
    sum_rec = (struct.pack("<ddd", 0.0, 0.0, float(len(out_segs))) + summaries).ljust(1024, b"\0")
    name_rec = names.ljust(1024, b" ")
    blob = blob.ljust(((len(blob) + 1023) // 1024) * 1024, b"\0")

    file_rec = bytearray(1024)
    file_rec[0:8] = b"DAF/SPK "
    file_rec[8:16] = struct.pack("<ii", ND, NI)
    file_rec[16:76] = b"Astral test kernel (DE440s excerpt)".ljust(60)
    file_rec[76:88] = struct.pack("<iii", 3, 3, next_word)  # FWARD, BWARD, FREE
    file_rec[88:96] = b"LTL-IEEE"
    file_rec[699:727] = b"FTPSTR:\r:\n:\r\n:\r\x00:\x81:\x10\xce:ENDFTP"
    with open(dst, "wb") as f:
        f.write(bytes(file_rec) + comment_rec + sum_rec + name_rec + blob)
    print("wrote", dst, len(out_segs), "segments")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
