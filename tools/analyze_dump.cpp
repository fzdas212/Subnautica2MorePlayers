#define NOMINMAX
#include <windows.h>
#include <dbghelp.h>

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#pragma comment(lib, "dbghelp.lib")

struct ModuleInfo {
    DWORD64 base = 0;
    DWORD64 size = 0;
    std::wstring path;
    std::string utf8Path;
};

static std::string WideToUtf8(const std::wstring& value) {
    if (value.empty()) {
        return {};
    }
    int needed = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    std::string out(static_cast<size_t>(needed), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), out.data(), needed, nullptr, nullptr);
    return out;
}

static std::wstring ReadDumpString(const BYTE* dumpBase, RVA rva) {
    if (rva == 0) {
        return {};
    }
    const auto* s = reinterpret_cast<const MINIDUMP_STRING*>(dumpBase + rva);
    size_t wcharCount = s->Length / sizeof(wchar_t);
    return std::wstring(s->Buffer, s->Buffer + wcharCount);
}

static std::string Hex64(DWORD64 value) {
    std::ostringstream oss;
    oss << "0x" << std::uppercase << std::hex << value;
    return oss.str();
}

static const ModuleInfo* FindModule(const std::vector<ModuleInfo>& modules, DWORD64 address) {
    for (const auto& m : modules) {
        if (address >= m.base && address < m.base + m.size) {
            return &m;
        }
    }
    return nullptr;
}

static std::string BaseNameUtf8(const ModuleInfo& m) {
    std::filesystem::path p(m.path);
    return WideToUtf8(p.filename().wstring());
}

static std::string Symbolize(HANDLE process, DWORD64 address) {
    char storage[sizeof(SYMBOL_INFO) + MAX_SYM_NAME] = {};
    auto* sym = reinterpret_cast<SYMBOL_INFO*>(storage);
    sym->SizeOfStruct = sizeof(SYMBOL_INFO);
    sym->MaxNameLen = MAX_SYM_NAME;
    DWORD64 displacement = 0;

    std::ostringstream oss;
    if (SymFromAddr(process, address, &displacement, sym)) {
        oss << sym->Name;
        if (displacement != 0) {
            oss << "+" << Hex64(displacement);
        }

        IMAGEHLP_LINE64 line = {};
        line.SizeOfStruct = sizeof(line);
        DWORD lineDisp = 0;
        if (SymGetLineFromAddr64(process, address, &lineDisp, &line)) {
            oss << " (" << line.FileName << ":" << line.LineNumber << ")";
        }
        return oss.str();
    }

    oss << "<no symbol>";
    return oss.str();
}

static bool LooksLikeReturnAddress(const std::vector<ModuleInfo>& modules, DWORD64 value) {
    const ModuleInfo* module = FindModule(modules, value);
    if (!module) {
        return false;
    }
    std::string name = BaseNameUtf8(*module);
    std::transform(name.begin(), name.end(), name.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return name == "ue4ss.dll" || name == "subnautica2-win64-shipping.exe" || name == "lua54.dll" ||
        name == "kernel32.dll" || name == "ntdll.dll" || name == "vcruntime140.dll" || name == "msvcp140.dll";
}

int wmain(int argc, wchar_t** argv) {
    if (argc < 2) {
        std::wcerr << L"Usage: analyze_dump.exe <dump-path> [symbol-root]\n";
        return 2;
    }

    std::filesystem::path dumpPath = argv[1];
    std::filesystem::path symbolRoot = argc >= 3 ? std::filesystem::path(argv[2]) : dumpPath.parent_path();

    std::ifstream file(dumpPath, std::ios::binary);
    if (!file) {
        std::wcerr << L"Could not open dump: " << dumpPath.wstring() << L"\n";
        return 3;
    }
    std::vector<BYTE> dump((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    if (dump.empty()) {
        std::wcerr << L"Dump is empty: " << dumpPath.wstring() << L"\n";
        return 4;
    }

    const BYTE* dumpBase = dump.data();
    MINIDUMP_EXCEPTION_STREAM* exception = nullptr;
    ULONG streamSize = 0;
    if (!MiniDumpReadDumpStream(const_cast<BYTE*>(dumpBase), ExceptionStream, nullptr, reinterpret_cast<PVOID*>(&exception), &streamSize) || !exception) {
        std::cerr << "ExceptionStream not found\n";
        return 5;
    }

    MINIDUMP_MODULE_LIST* moduleList = nullptr;
    if (!MiniDumpReadDumpStream(const_cast<BYTE*>(dumpBase), ModuleListStream, nullptr, reinterpret_cast<PVOID*>(&moduleList), &streamSize) || !moduleList) {
        std::cerr << "ModuleListStream not found\n";
        return 6;
    }

    std::vector<ModuleInfo> modules;
    modules.reserve(moduleList->NumberOfModules);
    for (ULONG i = 0; i < moduleList->NumberOfModules; ++i) {
        const auto& raw = moduleList->Modules[i];
        ModuleInfo m;
        m.base = raw.BaseOfImage;
        m.size = raw.SizeOfImage;
        m.path = ReadDumpString(dumpBase, raw.ModuleNameRva);
        m.utf8Path = WideToUtf8(m.path);
        modules.push_back(std::move(m));
    }

    HANDLE process = GetCurrentProcess();
    std::wstring symbolPath = symbolRoot.wstring() + L";" + dumpPath.parent_path().wstring() + L";srv*C:\\symbols*https://msdl.microsoft.com/download/symbols";
    SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES | SYMOPT_FAIL_CRITICAL_ERRORS);
    if (!SymInitializeW(process, symbolPath.c_str(), FALSE)) {
        std::cerr << "SymInitialize failed: " << GetLastError() << "\n";
        return 7;
    }

    for (const auto& m : modules) {
        SymLoadModuleExW(process, nullptr, m.path.empty() ? nullptr : m.path.c_str(), nullptr, m.base, static_cast<DWORD>(m.size), nullptr, 0);
    }

    const auto& er = exception->ExceptionRecord;
    DWORD64 exceptionAddress = er.ExceptionAddress;
    const ModuleInfo* faultModule = FindModule(modules, exceptionAddress);

    std::cout << "# Minidump Analysis\n\n";
    std::cout << "Dump: `" << WideToUtf8(dumpPath.wstring()) << "`\n";
    std::cout << "Symbol path: `" << WideToUtf8(symbolPath) << "`\n\n";

    std::cout << "## Exception\n\n";
    std::cout << "- ThreadId: " << exception->ThreadId << "\n";
    std::cout << "- ExceptionCode: " << Hex64(er.ExceptionCode) << "\n";
    std::cout << "- ExceptionFlags: " << Hex64(er.ExceptionFlags) << "\n";
    std::cout << "- ExceptionAddress: " << Hex64(exceptionAddress);
    if (faultModule) {
        std::cout << " (" << BaseNameUtf8(*faultModule) << "+" << Hex64(exceptionAddress - faultModule->base) << ")";
    }
    std::cout << "\n";
    std::cout << "- Symbol: " << Symbolize(process, exceptionAddress) << "\n";
    if (er.NumberParameters > 0) {
        std::cout << "- ExceptionInformation:\n";
        for (ULONG i = 0; i < er.NumberParameters; ++i) {
            std::cout << "  - [" << i << "] " << Hex64(er.ExceptionInformation[i]) << "\n";
        }
    }

#if defined(_M_X64) || defined(_M_AMD64)
    const CONTEXT* ctx = reinterpret_cast<const CONTEXT*>(dumpBase + exception->ThreadContext.Rva);
    std::cout << "\n## Context\n\n";
    std::cout << "- RIP: " << Hex64(ctx->Rip) << " " << Symbolize(process, ctx->Rip) << "\n";
    std::cout << "- RSP: " << Hex64(ctx->Rsp) << "\n";
    std::cout << "- RBP: " << Hex64(ctx->Rbp) << "\n";
    std::cout << "- RCX: " << Hex64(ctx->Rcx) << "\n";
    std::cout << "- RDX: " << Hex64(ctx->Rdx) << "\n";
    std::cout << "- R8: " << Hex64(ctx->R8) << "\n";
    std::cout << "- R9: " << Hex64(ctx->R9) << "\n";
#endif

    std::cout << "\n## Loaded Modules Of Interest\n\n";
    for (const auto& m : modules) {
        std::string name = BaseNameUtf8(m);
        std::string lower = name;
        std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        if (lower == "ue4ss.dll" || lower == "subnautica2-win64-shipping.exe" || lower.find("eos") != std::string::npos ||
            lower.find("steam") != std::string::npos || lower.find("sonar") != std::string::npos) {
            std::cout << "- " << name << " base=" << Hex64(m.base) << " size=" << Hex64(m.size) << " path=`" << m.utf8Path << "`\n";
        }
    }

    MINIDUMP_THREAD_LIST* threadList = nullptr;
    if (MiniDumpReadDumpStream(const_cast<BYTE*>(dumpBase), ThreadListStream, nullptr, reinterpret_cast<PVOID*>(&threadList), &streamSize) && threadList) {
        const MINIDUMP_THREAD* faultThread = nullptr;
        for (ULONG i = 0; i < threadList->NumberOfThreads; ++i) {
            if (threadList->Threads[i].ThreadId == exception->ThreadId) {
                faultThread = &threadList->Threads[i];
                break;
            }
        }

        if (faultThread && faultThread->Stack.Memory.DataSize >= sizeof(DWORD64)) {
            std::cout << "\n## Stack Address Scan\n\n";
            std::cout << "This is an aligned scan of the captured thread stack, not a full unwind.\n\n";
            const BYTE* stack = dumpBase + faultThread->Stack.Memory.Rva;
            ULONG64 stackBase = faultThread->Stack.StartOfMemoryRange;
            ULONG64 count = faultThread->Stack.Memory.DataSize / sizeof(DWORD64);
            int printed = 0;
            for (ULONG64 i = 0; i < count && printed < 80; ++i) {
                DWORD64 value = 0;
                std::memcpy(&value, stack + i * sizeof(DWORD64), sizeof(value));
                if (!LooksLikeReturnAddress(modules, value)) {
                    continue;
                }
                const ModuleInfo* m = FindModule(modules, value);
                std::cout << "- stack+" << Hex64(i * sizeof(DWORD64)) << " [" << Hex64(stackBase + i * sizeof(DWORD64)) << "] = "
                          << Hex64(value) << " (" << BaseNameUtf8(*m) << "+" << Hex64(value - m->base) << ") "
                          << Symbolize(process, value) << "\n";
                ++printed;
            }
            if (printed == 0) {
                std::cout << "No module return-address candidates were found in captured stack memory.\n";
            }
        }
    }

    SymCleanup(process);
    return 0;
}
