#!/usr/bin/env python3
"""Add module-relative PCs to Godot's MinGW crash trace for offline symbolization."""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'platform/windows/crash_handler_windows_signal.cpp'
s = path.read_text()
needle = '''\tCrashHandlerData *ch_data = reinterpret_cast<CrashHandlerData *>(data);
\tbacktrace_pcinfo(ch_data->state, pc - ch_data->offset, &symbol_callback, &error_callback, data);'''
replacement = '''\tCrashHandlerData *ch_data = reinterpret_cast<CrashHandlerData *>(data);
\tHMODULE module = nullptr;
\tchar module_path[MAX_PATH] = "unknown";
\tMODULEINFO info = {};
\tif (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCSTR>(pc), &module)) {
\t\tGetModuleFileNameA(module, module_path, sizeof(module_path));
\t\tGetModuleInformation(GetCurrentProcess(), module, &info, sizeof(info));
\t}
\tchar line[1024];
\tsnprintf(line, sizeof(line), "WMC_PC module=%s rva=0x%llx pc=0x%llx", module_path, (unsigned long long)(pc - reinterpret_cast<uintptr_t>(info.lpBaseOfDll)), (unsigned long long)pc);
\tprint_error(String::utf8(line));
\tbacktrace_pcinfo(ch_data->state, pc - ch_data->offset, &symbol_callback, &error_callback, data);'''
if s.count(needle) != 1:
    raise SystemExit('unexpected crash handler; refusing to patch')
s = s.replace(needle, replacement)
path.write_text(s)

# Test only: trigger a known native crash after engine initialization when the
# environment variable is present. Normal launches never set that variable.
os_path = Path(sys.argv[1]) / 'platform/windows/os_windows.cpp'
os_source = os_path.read_text()
needle = 'void OS_Windows::run() {'
replacement = """#include <signal.h>
#include <cstdlib>
__attribute__((noinline)) static void wmc_trace_test_crash() {
 raise(SIGSEGV);
 volatile int keep_frame = 1;
 (void)keep_frame;
}

void OS_Windows::run() {"""
if os_source.count(needle) != 1:
    raise SystemExit('unexpected OS_Windows::run')
os_source = os_source.replace(needle, replacement)
needle = '\tmain_loop->initialize();'
replacement = """\tmain_loop->initialize();
\tif (getenv("WMC_INTERNAL_TEST_CRASH") != nullptr) {
\t\twmc_trace_test_crash();
\t}"""
if os_source.count(needle) != 1:
    raise SystemExit('unexpected main loop initialization')
os_path.write_text(os_source.replace(needle, replacement))
