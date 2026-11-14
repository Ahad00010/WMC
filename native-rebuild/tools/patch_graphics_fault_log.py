#!/usr/bin/env python3
"""Add failure-only ANGLE diagnostics to the reviewed Godot 4.4.1 Windows build.

No graphics errors are ignored and no attempt is made to recreate a GL context:
all Godot resources would have to be rebuilt after an actual context loss.
"""
from pathlib import Path
import sys

root = Path(sys.argv[1])

def replace(path, old, new):
    target = root / path
    source = target.read_text()
    if source.count(old) != 1:
        raise SystemExit(f"unexpected engine source in {path}; refusing to patch")
    target.write_text(source.replace(old, new))

replace('drivers/egl/egl_manager.cpp',
        '\teglSwapBuffers(current_display.egl_display, current_window->egl_surface);',
        '''#ifdef WINDOWS_ENABLED
	// Failure-only logging: EGL error is retrieved only when the swap fails.
	static bool wmc_swap_failed = false;
	if (eglSwapBuffers(current_display.egl_display, current_window->egl_surface) == EGL_FALSE) {
		EGLint error = eglGetError();
		if (!wmc_swap_failed) {
			ERR_PRINT(vformat("WMC_GRAPHICS eglSwapBuffers failed: EGL error 0x%04X (0x300E means context lost)", error));
		}
		wmc_swap_failed = true;
	} else if (wmc_swap_failed) {
		WARN_PRINT("WMC_GRAPHICS eglSwapBuffers succeeded again; this alone does not prove resources recovered");
		wmc_swap_failed = false;
	}
#else
	eglSwapBuffers(current_display.egl_display, current_window->egl_surface);
#endif''')
replace('drivers/gles3/storage/texture_storage.cpp',
        '''		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if (status != GL_FRAMEBUFFER_COMPLETE) {
			glDeleteFramebuffers(1, &rt->fbo);''',
        '''		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if (status != GL_FRAMEBUFFER_COMPLETE) {
#ifdef WINDOWS_ENABLED
			// The pending GL error is sampled before cleanup can overwrite it.
			// It may be from an earlier GL call, not necessarily the status query.
			static unsigned int wmc_failures = 0;
			GLenum pending_error = glGetError();
			if (wmc_failures++ < 4) {
				ERR_PRINT(vformat("WMC_GRAPHICS framebuffer status=0x%04X pending_gl_error=0x%04X fbo=%u color=%u depth=%u size=%dx%d", status, pending_error, rt->fbo, rt->color, rt->depth, rt->size.x, rt->size.y));
			}
#endif
			glDeleteFramebuffers(1, &rt->fbo);''')
for kind in ('buffer', 'texture'):
    replace('drivers/gles3/storage/utilities.h',
            f'\t\tERR_FAIL_COND(!{kind}_allocs_cache.has(p_id));',
            f'''#ifdef WINDOWS_ENABLED
		if (!{kind}_allocs_cache.has(p_id)) {{
			static unsigned int wmc_missing_{kind} = 0;
			if (wmc_missing_{kind}++ < 4) {{
				ERR_PRINT(vformat("WMC_GRAPHICS missing {kind} allocation id=%u", p_id));
			}}
		}}
#endif
		ERR_FAIL_COND(!{kind}_allocs_cache.has(p_id));''')
