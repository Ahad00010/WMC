#!/usr/bin/env python3
"""Use Godot's existing unmapped canvas upload path on Windows.

The user's symbolized crash points to memcpy immediately after glMapBufferRange
in this block. glMapBufferRange can return null; use glBufferSubData on Windows
rather than dereferencing a mapped pointer or using an unsynchronized mapping.
This changes neither the 3D track nor non-Windows renderers.
"""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'drivers/gles3/rasterizer_canvas_gles3.cpp'
source = path.read_text()
old = '''#ifdef WEB_ENABLED
\tglBufferSubData(GL_ARRAY_BUFFER, state.last_item_index * sizeof(InstanceData), sizeof(InstanceData) * index, state.instance_data_array);
#else
\t// On Desktop and mobile we map the memory without synchronizing for maximum speed.'''
new = '''#if defined(WEB_ENABLED) || defined(WINDOWS_ENABLED)
\t// WMC: avoid dereferencing a failed / unsynchronized map on Windows ANGLE.
\t// This is the same upload path Godot already uses on the web.
\tglBufferSubData(GL_ARRAY_BUFFER, state.last_item_index * sizeof(InstanceData), sizeof(InstanceData) * index, state.instance_data_array);
#else
\t// On other desktop platforms and mobile we map without synchronizing for maximum speed.'''
if source.count(old) != 1:
    raise SystemExit('Canvas upload code differs from the reviewed Godot 4.4.1 version')
path.write_text(source.replace(old, new))
