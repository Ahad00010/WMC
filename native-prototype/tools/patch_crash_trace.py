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
# Explicitly opt-in CI-only crash test, never enabled in normal play.
needle = 'void CrashHandler::initialize() {\n#if defined(CRASH_HANDLER_EXCEPTION)'
replacement = '''#if defined(CRASH_HANDLER_EXCEPTION)
__attribute__((noinline)) static void wmc_trace_test_crash() {
\traise(SIGSEGV);
}
#endif

void CrashHandler::initialize() {
#if defined(CRASH_HANDLER_EXCEPTION)'''
if s.count(needle) != 1:
    raise SystemExit('unexpected initialize implementation')
s = s.replace(needle, replacement)
needle = '\tsignal(SIGILL, CrashHandlerException);\n#endif\n}'
replacement = '''\tsignal(SIGILL, CrashHandlerException);
\tif (getenv("WMC_INTERNAL_TEST_CRASH") != nullptr) {
\t\twmc_trace_test_crash();
\t}
#endif
}'''
if s.count(needle) != 1:
    raise SystemExit('unexpected signal setup')
s = s.replace(needle, replacement)
path.write_text(s)
