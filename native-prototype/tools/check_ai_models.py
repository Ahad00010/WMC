#!/usr/bin/env python3
"""Check AI LODs retain model hierarchy/textures and reduce triangle count."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets'

def model(filename):
    data = (ROOT / filename).read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    scene = json.loads(data[20:20 + size])
    start = 20 + size + 8
    def image_hash(image):
        view = scene['bufferViews'][image['bufferView']]
        offset = start + view.get('byteOffset', 0)
        return hashlib.sha256(data[offset:offset + view['byteLength']]).hexdigest()
    triangles = 0
    for mesh in scene['meshes']:
        for primitive in mesh['primitives']:
            accessor = primitive.get('indices', primitive['attributes']['POSITION'])
            assert primitive.get('mode', 4) == 4
            triangles += scene['accessors'][accessor]['count'] // 3
    nodes = [{k: node.get(k) for k in ('name', 'translation', 'rotation', 'scale')} for node in scene['nodes']]
    return nodes, [image_hash(image) for image in scene['images']], triangles

for source, optimized in [('bike-mobile.glb', 'bike-ai.glb'), ('marc-rider.glb', 'rider-ai.glb')]:
    a, b = model(source), model(optimized)
    assert a[:2] == b[:2], f'{optimized}: hierarchy/transforms or image bytes changed'
    assert b[2] < a[2] * .70, f'{optimized}: triangle reduction too small'
    print(f'{source}: {a[2]:,} -> {optimized}: {b[2]:,} triangles')
