#!/usr/bin/env python3
"""Rebuild only the rider's embedded suit texture from the supplied source.

Requires Pillow (python -m pip install Pillow); does not touch rider geometry,
UVs, the separate sponsor decals, or any bike asset. Run from the repo root.
"""
import colorsys
import io
import json
import struct
import zipfile
from pathlib import Path
from PIL import Image

GLB = Path('marc-rider.glb')
SOURCE = '4dadf5a8-cd38-45fd-8234-879c09398028.png'

# The Ducati base-color texture contains dominant paint around RGB (151, 8, 8).
# Recolor only saturated red/orange areas, retaining skin, white panels, navy,
# gray armor and black details. Keep per-pixel shading and antialiased edges.
def recolor(pixel):
    r, g, b, a = pixel
    hue, saturation, value = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if saturation > .60 and value > .15 and (hue < .09 or hue > .98):
        # Original orange is brighter than original red. Normalize each to the
        # bike's red paint without flattening highlights and shadows.
        orange = min(1., max(0., hue / .045)) if hue < .09 else 0.
        reference = 205 + 47 * orange
        intensity = r / reference
        return (min(255, round(151 * intensity)), min(255, round(8 * intensity)),
                min(255, round(8 * intensity)), a)
    return pixel

with zipfile.ZipFile('marquez_on_bike.zip') as z:
    source = Image.open(io.BytesIO(z.read(SOURCE))).convert('RGBA')
# Process tiles to avoid a multi-gigabyte list for the 4096px source texture.
for top in range(0, source.height, 512):
    for left in range(0, source.width, 512):
        box = (left, top, min(left + 512, source.width), min(top + 512, source.height))
        tile = source.crop(box)
        tile.putdata([recolor(pixel) for pixel in tile.getdata()])
        source.paste(tile, box)
source = source.resize((1024, 1024), Image.Resampling.LANCZOS)
image = io.BytesIO()
source.save(image, format='PNG', optimize=True)
new_image = image.getvalue()

blob = GLB.read_bytes()
magic, version, total = struct.unpack_from('<III', blob)
assert (magic, version, total) == (0x46546c67, 2, len(blob))
json_len, json_type = struct.unpack_from('<II', blob, 12)
assert json_type == 0x4e4f534a
doc = json.loads(blob[20:20 + json_len])
bin_header = 20 + json_len
bin_len, bin_type = struct.unpack_from('<II', blob, bin_header)
assert bin_type == 0x004e4942
binary = blob[bin_header + 8:bin_header + 8 + bin_len]
texture = next(x for x in doc['images'] if x.get('name') == 'red-suit')
view_index = texture['bufferView']
view = doc['bufferViews'][view_index]
start = view.get('byteOffset', 0)
end = start + view['byteLength']
old_end = (end + 3) & ~3
assert not any(start < v.get('byteOffset', 0) < old_end for i, v in enumerate(doc['bufferViews']) if i != view_index)
padded_image = new_image + bytes((-len(new_image)) % 4)
new_binary = binary[:start] + padded_image + binary[old_end:]
delta = len(padded_image) - (old_end - start)
view['byteLength'] = len(new_image)
for i, v in enumerate(doc['bufferViews']):
    if i != view_index and v.get('byteOffset', 0) >= old_end:
        v['byteOffset'] = v.get('byteOffset', 0) + delta
doc['buffers'][0]['byteLength'] += delta
encoded = json.dumps(doc, separators=(',', ':')).encode()
encoded += b' ' * ((-len(encoded)) % 4)
new_binary += bytes((-len(new_binary)) % 4)
result = (struct.pack('<III', magic, version, 12 + 8 + len(encoded) + 8 + len(new_binary)) +
          struct.pack('<II', len(encoded), json_type) + encoded +
          struct.pack('<II', len(new_binary), bin_type) + new_binary)
GLB.write_bytes(result)
