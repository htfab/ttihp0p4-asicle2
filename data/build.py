#!/usr/bin/env python3

import numpy as np
import freetype

np.set_printoptions(edgeitems=50, linewidth=330)

assets = {
    "font": "assets/font/Roboto-Bold.ttf",
    "wordlist": "assets/wordlist/wordlist.txt",
    "picks": "assets/wordlist/picks.txt",
}

outputs = {
    "hex": "asicle.hex",
    "bin": "asicle.bin",
}


def gen_calibration_data():
    for i in range(32):
        yield "0123456789abcdef"


def color_map(value, max_value):
    # "compromise" color map:
    # the ideal splitting points would be different based on the background color:
    #   background \ result: black |  dgrey  |  lgrey  | white
    #       black:           0-1/6 | 1/6-1/2 | 1/2-5/6 | 5/6-1
    #       dgrey:                     0-1/4 | 1/4-3/4 | 3/4-1
    #       lgrey:                               0-1/2 | 1/2-1
    #       white:                                         0-1
    # but then we would need 3 bits per pixel to identify the right range:
    #       0-1/6 | 1/6-1/4 | 1/4-1/2 | 1/2-3/4 | 3/4-5/6 | 5/6-1
    # instead we use 2 bits per pixel by rounding off both 1/6 and 1/4 to 1/5
    #       0-1/5 | 1/5-1/2 | 1/2-4/5 | 4/5-1
    # so the output becomes:
    #   background \ result: black |  dgrey  |  lgrey  | white
    #       black:           0-1/5 | 1/5-1/2 | 1/2-4/5 | 4/5-1
    #       dgrey:                     0-1/5 | 1/5-4/5 | 4/5-1
    #       lgrey:                               0-1/2 | 1/2-1
    #       white:                                         0-1
    fmap = (value * 10) // (max_value + 1)
    return [0, 0, 1, 1, 1, 2, 2, 2, 3, 3][fmap]


def gen_font_data():
    face = freetype.Face(assets["font"])
    face.set_char_size(int(75 * 64))

    for char_index in range(26):
        char = chr(ord('A') + char_index)
        face.load_char(char)
        glyph = face.glyph
        bitmap = glyph.bitmap
        rows, width = bitmap.rows, bitmap.width
        top, left = glyph.bitmap_top, glyph.bitmap_left
        pad_top = 55 - top
        pad_left = (64 - width) // 2
        bitmap_array = np.array(bitmap.buffer).reshape(rows, width)
        padded_array = np.zeros((66, 64), dtype=np.uint)
        padded_array[pad_top:pad_top+rows,pad_left:pad_left+width] = bitmap_array
        resized_array = sum(padded_array[j::2, i::2] for j in range(2) for i in range(2))
        quantized_array = np.vectorize(lambda x: color_map(x, 1020))(resized_array)
        assert not any(quantized_array[-1])
        quantized_array = quantized_array[:-1]
        hex_array = 4 * quantized_array[:, 0::2] + quantized_array[:, 1::2]
        for line in hex_array:
            yield ''.join(f'{i:1x}' for i in line)


def gen_picks_data():
    pl = open(assets["picks"]).read().strip().split("\n")

    yield f"{len(pl):08x}"
    for p in sorted(pl):
        l1, l2, l3, l4, l5 = [ord(c)-ord('A')+1 for c in p]
        pv = l1 << 20 | l2 << 15 | l3 << 10 | l4 << 5 | l5
        yield f"{(pv << 7):08x}"


def gen_trie_data():
    wl = open(assets["wordlist"]).read().strip().split("\n")

    prefixes = []
    for i in range(6):
        prefixes.append(set(w[:i] for w in wl))

    letters = "".join(chr(64+i) for i in range(32))

    states = {w: 1 for w in wl}
    states[""] = 2
    num_states = 3
    transfers = [(0,)*32, (1,)*32, ()]
    lookup = {(0,)*32: 0, (1,)*32: 1}

    for i in reversed(range(1, 5)):
        for p in sorted(prefixes[i]):
            transfer = tuple(states.get(p+l, 0) for l in letters)
            if (state := lookup.setdefault(transfer, num_states)) == num_states:
                transfers.append(transfer)
                num_states += 1
            states[p] = state
    root_transfer = tuple(states.get(l, 0) for l in letters)
    transfers[2] = root_transfer
    lookup[root_transfer] = 2

    for i in range(num_states):
        yield "".join(f"{j:04x}" for j in transfers[i])


def gen_combined_data():
    bin_size = 0x034c00
    mem_src = [
        (0x000000, 0x0000ff, "TEST", gen_calibration_data),
        (0x000100, 0x001fff, "FONT", gen_font_data),
        (0x002000, 0x007fff, "PICK", gen_picks_data),
        (0x008000, 0x034bff, "TRIE", gen_trie_data),
    ]

    bin_file = ["00"] * bin_size

    for start, end, name, generator in mem_src:
        pos = start
        for entry in generator():
            for i in range(len(entry) // 2):
                assert pos < bin_size, f"Section {name} extends beyond binary size"
                assert pos <= end, f"Section {name} extends beyond allocated range"
                assert bin_file[pos] == "00", f"Section {name} overlaps existing data"
                bin_file[pos] = entry[2*i:2*i+2]
                pos += 1

    line = ""
    for i in range(bin_size):
        line += bin_file[i]
        if (i+1) % 64 == 0:
            yield line
            line = ""
    if line:
        yield line


def write_data_file(write_hex=True, write_bin=True):
    if write_hex:
        hex_file = open(outputs["hex"], "w")
    if write_bin:
        bin_file = open(outputs["bin"], "wb")
    for line in gen_combined_data():
        if write_hex:
            print(line, file=hex_file)
        if write_bin:
            assert len(line) % 2 == 0
            for i in range(0, len(line), 2):
                byte = int(line[i:i+2], 16)
                bin_file.write(bytes([byte]))
    if write_hex:
        hex_file.close()
    if write_bin:
        bin_file.close()


if __name__ == "__main__":
    write_data_file()

