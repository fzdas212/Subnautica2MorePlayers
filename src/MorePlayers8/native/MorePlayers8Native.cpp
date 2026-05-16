#define NOMINMAX
#include <windows.h>
#include <bcrypt.h>

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <mutex>
#include <new>
#include <sstream>
#include <string>
#include <vector>

#pragma comment(lib, "bcrypt.lib")

namespace {

constexpr int kDefaultMaxPlayers = 64;
constexpr int kMaxReasonablePlayers = 64;
constexpr const char* kKnownExeSha256 = "E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4";

struct Config {
    int maxPlayers = kDefaultMaxPlayers;
    bool enabled = false;
    bool requireKnownHash = true;
    bool patchLobbySetMaxMembers = true;
    bool patchSessionSetMaxPlayers = true;
    bool patchLobbyCreateLobby = true;
    bool patchSessionCreateModification = true;
    bool patchSteamLobbyCapacity = true;
    bool patchUnrealServerFullAdmission = true;
    bool patchJoinValidation = true;
    bool logAllCalls = true;
    std::string knownHash = kKnownExeSha256;
};

struct EOS_Lobby_CreateLobbyOptions_Min {
    int32_t ApiVersion;
    void* LocalUserId;
    uint32_t MaxLobbyMembers;
    int32_t PermissionLevel;
    int32_t bPresenceEnabled;
    int32_t bAllowInvites;
    const char* BucketId;
    int32_t bDisableHostMigration;
    int32_t bEnableRTCRoom;
    const void* LocalRTCOptions;
    const char* LobbyId;
    int32_t bEnableJoinById;
    int32_t bRejoinAfterKickRequiresInvite;
    const uint32_t* AllowedPlatformIds;
    uint32_t AllowedPlatformIdsCount;
    int32_t bCrossplayOptOut;
    int32_t RTCRoomJoinActionType;
};

struct EOS_LobbyModification_SetMaxMembersOptions_Min {
    int32_t ApiVersion;
    uint32_t MaxMembers;
};

struct EOS_Sessions_CreateSessionModificationOptions_Min {
    int32_t ApiVersion;
    const char* SessionName;
    const char* BucketId;
    uint32_t MaxPlayers;
    void* LocalUserId;
    int32_t bPresenceEnabled;
    const char* SessionId;
    int32_t bSanctionsEnabled;
    const uint32_t* AllowedPlatformIds;
    uint32_t AllowedPlatformIdsCount;
};

struct EOS_SessionModification_SetMaxPlayersOptions_Min {
    int32_t ApiVersion;
    uint32_t MaxPlayers;
};

union EOS_AttributeValue_Min {
    int64_t AsInt64;
    double AsDouble;
    int32_t AsBool;
    const char* AsUtf8;
};

struct EOS_Lobby_AttributeData_Min {
    int32_t ApiVersion;
    const char* Key;
    EOS_AttributeValue_Min Value;
    int32_t ValueType;
};

struct EOS_LobbyModification_AddAttributeOptions_Min {
    int32_t ApiVersion;
    const EOS_Lobby_AttributeData_Min* Attribute;
    int32_t Visibility;
};

struct EOS_LobbyModification_AddMemberAttributeOptions_Min {
    int32_t ApiVersion;
    const EOS_Lobby_AttributeData_Min* Attribute;
    int32_t Visibility;
};

struct EOS_LobbyDetails_CopyInfoOptions_Min {
    int32_t ApiVersion;
};

struct EOS_LobbyDetails_Info_Min {
    int32_t ApiVersion;
    const char* LobbyId;
    void* LobbyOwnerUserId;
    int32_t PermissionLevel;
    uint32_t AvailableSlots;
    uint32_t MaxMembers;
    int32_t bAllowInvites;
    const char* BucketId;
    int32_t bAllowHostMigration;
    int32_t bRTCRoomEnabled;
    int32_t bAllowJoinById;
    int32_t bRejoinAfterKickRequiresInvite;
    int32_t bPresenceEnabled;
    const uint32_t* AllowedPlatformIds;
    uint32_t AllowedPlatformIdsCount;
};

struct EOS_Lobby_Attribute_Min {
    int32_t ApiVersion;
    EOS_Lobby_AttributeData_Min* Data;
    int32_t Visibility;
};

struct EOS_LobbyDetails_CopyAttributeByIndexOptions_Min {
    int32_t ApiVersion;
    uint32_t AttrIndex;
};

struct EOS_Sessions_AttributeData_Min {
    int32_t ApiVersion;
    const char* Key;
    EOS_AttributeValue_Min Value;
    int32_t ValueType;
};

struct EOS_SessionModification_AddAttributeOptions_Min {
    int32_t ApiVersion;
    const EOS_Sessions_AttributeData_Min* SessionAttribute;
    int32_t AdvertisementType;
};

struct EOS_SessionDetails_Settings_Min {
    int32_t ApiVersion;
    const char* BucketId;
    uint32_t NumPublicConnections;
    int32_t bAllowJoinInProgress;
    int32_t PermissionLevel;
    int32_t bInvitesAllowed;
    int32_t bSanctionsEnabled;
    const uint32_t* AllowedPlatformIds;
    uint32_t AllowedPlatformIdsCount;
};

struct EOS_SessionDetails_Info_Min {
    int32_t ApiVersion;
    const char* SessionId;
    const char* HostAddress;
    uint32_t NumOpenPublicConnections;
    const EOS_SessionDetails_Settings_Min* Settings;
    void* OwnerUserId;
    const char* OwnerServerClientId;
};

struct EOS_SessionDetails_CopyInfoOptions_Min {
    int32_t ApiVersion;
};

struct EOS_SessionDetails_Attribute_Min {
    int32_t ApiVersion;
    EOS_Sessions_AttributeData_Min* Data;
    int32_t AdvertisementType;
};

struct EOS_SessionDetails_CopySessionAttributeByIndexOptions_Min {
    int32_t ApiVersion;
    uint32_t AttrIndex;
};

using EOS_Lobby_CreateLobby_t = void(__cdecl*)(void*, const EOS_Lobby_CreateLobbyOptions_Min*, void*, void*);
using EOS_LobbyModification_SetMaxMembers_t = int32_t(__cdecl*)(void*, const EOS_LobbyModification_SetMaxMembersOptions_Min*);
using EOS_Sessions_CreateSessionModification_t = int32_t(__cdecl*)(void*, const EOS_Sessions_CreateSessionModificationOptions_Min*, void**);
using EOS_SessionModification_SetMaxPlayers_t = int32_t(__cdecl*)(void*, const EOS_SessionModification_SetMaxPlayersOptions_Min*);
using EOS_LobbyModification_AddAttribute_t = int32_t(__cdecl*)(void*, const EOS_LobbyModification_AddAttributeOptions_Min*);
using EOS_LobbyModification_AddMemberAttribute_t = int32_t(__cdecl*)(void*, const EOS_LobbyModification_AddMemberAttributeOptions_Min*);
using EOS_LobbyDetails_CopyInfo_t = int32_t(__cdecl*)(void*, const EOS_LobbyDetails_CopyInfoOptions_Min*, EOS_LobbyDetails_Info_Min**);
using EOS_LobbyDetails_CopyAttributeByIndex_t = int32_t(__cdecl*)(void*, const EOS_LobbyDetails_CopyAttributeByIndexOptions_Min*, EOS_Lobby_Attribute_Min**);
using EOS_SessionModification_AddAttribute_t = int32_t(__cdecl*)(void*, const EOS_SessionModification_AddAttributeOptions_Min*);
using EOS_SessionDetails_CopyInfo_t = int32_t(__cdecl*)(void*, const EOS_SessionDetails_CopyInfoOptions_Min*, EOS_SessionDetails_Info_Min**);
using EOS_SessionDetails_CopySessionAttributeByIndex_t = int32_t(__cdecl*)(void*, const EOS_SessionDetails_CopySessionAttributeByIndexOptions_Min*, EOS_SessionDetails_Attribute_Min**);
using EOS_GenericCallback_t = void(__cdecl*)(const void*);
using SteamAPICall_t = std::uint64_t;
using CSteamID_Min = std::uint64_t;
using SteamAPI_ISteamMatchmaking_CreateLobby_t = SteamAPICall_t(__cdecl*)(void*, int, int);
using SteamAPI_ISteamMatchmaking_SetLobbyMemberLimit_t = bool(__cdecl*)(void*, CSteamID_Min, int);
using SteamAPI_ISteamMatchmaking_GetLobbyMemberLimit_t = int(__cdecl*)(void*, CSteamID_Min);

std::mutex g_logMutex;
std::filesystem::path g_modRoot;
std::filesystem::path g_logPath;
Config g_config;
EOS_Lobby_CreateLobby_t g_originalLobbyCreateLobby = nullptr;
EOS_LobbyModification_SetMaxMembers_t g_originalLobbySetMaxMembers = nullptr;
EOS_Sessions_CreateSessionModification_t g_originalSessionsCreateSessionModification = nullptr;
EOS_SessionModification_SetMaxPlayers_t g_originalSessionSetMaxPlayers = nullptr;
EOS_LobbyModification_AddAttribute_t g_originalLobbyAddAttribute = nullptr;
EOS_LobbyModification_AddMemberAttribute_t g_originalLobbyAddMemberAttribute = nullptr;
EOS_LobbyDetails_CopyInfo_t g_originalLobbyDetailsCopyInfo = nullptr;
EOS_LobbyDetails_CopyAttributeByIndex_t g_originalLobbyDetailsCopyAttributeByIndex = nullptr;
EOS_SessionModification_AddAttribute_t g_originalSessionAddAttribute = nullptr;
EOS_SessionDetails_CopyInfo_t g_originalSessionDetailsCopyInfo = nullptr;
EOS_SessionDetails_CopySessionAttributeByIndex_t g_originalSessionDetailsCopySessionAttributeByIndex = nullptr;
SteamAPI_ISteamMatchmaking_CreateLobby_t g_originalSteamCreateLobby = nullptr;
SteamAPI_ISteamMatchmaking_SetLobbyMemberLimit_t g_originalSteamSetLobbyMemberLimit = nullptr;
SteamAPI_ISteamMatchmaking_GetLobbyMemberLimit_t g_originalSteamGetLobbyMemberLimit = nullptr;
bool g_installed = false;

constexpr std::uintptr_t kApproveLoginServerFullBranchRva = 0x03FBC7E3;
constexpr unsigned char kApproveLoginServerFullExpected[] = {
    0x74, 0x0C, 0x48, 0x8D, 0x15, 0x24, 0xF8, 0x3B, 0x06, 0xE9, 0xB4, 0x00, 0x00, 0x00
};
constexpr unsigned char kApproveLoginServerFullPatched[] = {
    0xEB, 0x0C, 0x48, 0x8D, 0x15, 0x24, 0xF8, 0x3B, 0x06, 0xE9, 0xB4, 0x00, 0x00, 0x00
};

struct CallbackRelay {
    void* originalClientData = nullptr;
    EOS_GenericCallback_t originalCallback = nullptr;
};

std::string ToLower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

std::wstring Utf8ToWide(const std::string& value) {
    if (value.empty()) {
        return {};
    }
    int needed = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
    std::wstring out(static_cast<size_t>(needed), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), out.data(), needed);
    return out;
}

std::string WideToUtf8(const std::wstring& value) {
    if (value.empty()) {
        return {};
    }
    int needed = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    std::string out(static_cast<size_t>(needed), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), out.data(), needed, nullptr, nullptr);
    return out;
}

std::string ReadTextFile(const std::filesystem::path& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) {
        return {};
    }
    return std::string(std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>());
}

bool JsonBool(const std::string& text, const std::string& key, bool fallback) {
    std::string needle = "\"" + key + "\"";
    size_t pos = text.find(needle);
    if (pos == std::string::npos) {
        return fallback;
    }
    pos = text.find(':', pos + needle.size());
    if (pos == std::string::npos) {
        return fallback;
    }
    size_t valueStart = text.find_first_not_of(" \t\r\n", pos + 1);
    if (valueStart == std::string::npos) {
        return fallback;
    }
    if (text.compare(valueStart, 4, "true") == 0) {
        return true;
    }
    if (text.compare(valueStart, 5, "false") == 0) {
        return false;
    }
    return fallback;
}

int JsonInt(const std::string& text, const std::string& key, int fallback) {
    std::string needle = "\"" + key + "\"";
    size_t pos = text.find(needle);
    if (pos == std::string::npos) {
        return fallback;
    }
    pos = text.find(':', pos + needle.size());
    if (pos == std::string::npos) {
        return fallback;
    }
    size_t valueStart = text.find_first_of("-0123456789", pos + 1);
    if (valueStart == std::string::npos) {
        return fallback;
    }
    char* end = nullptr;
    long parsed = std::strtol(text.c_str() + valueStart, &end, 10);
    if (end == text.c_str() + valueStart) {
        return fallback;
    }
    return static_cast<int>(parsed);
}

std::string JsonString(const std::string& text, const std::string& key, const std::string& fallback) {
    std::string needle = "\"" + key + "\"";
    size_t pos = text.find(needle);
    if (pos == std::string::npos) {
        return fallback;
    }
    pos = text.find(':', pos + needle.size());
    if (pos == std::string::npos) {
        return fallback;
    }
    size_t quote = text.find('"', pos + 1);
    if (quote == std::string::npos) {
        return fallback;
    }
    size_t end = text.find('"', quote + 1);
    if (end == std::string::npos) {
        return fallback;
    }
    return text.substr(quote + 1, end - quote - 1);
}

void Log(const std::string& line) {
    std::lock_guard<std::mutex> lock(g_logMutex);
    if (g_logPath.empty()) {
        return;
    }
    std::error_code ec;
    std::filesystem::create_directories(g_logPath.parent_path(), ec);
    std::ofstream f(g_logPath, std::ios::app | std::ios::binary);
    if (!f) {
        return;
    }

    SYSTEMTIME st{};
    GetSystemTime(&st);
    char ts[64]{};
    std::snprintf(ts, sizeof(ts), "%04u-%02u-%02uT%02u:%02u:%02uZ",
                  st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
    f << ts << " [Subnautica2MorePlayers8.Native] " << line << "\r\n";
}

std::string HexBytes(const std::vector<unsigned char>& bytes) {
    std::ostringstream oss;
    for (unsigned char b : bytes) {
        oss << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(b);
    }
    return oss.str();
}

std::string HexBytesRaw(const unsigned char* bytes, size_t size) {
    std::ostringstream oss;
    for (size_t i = 0; i < size; ++i) {
        if (i > 0) {
            oss << ' ';
        }
        oss << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(bytes[i]);
    }
    return oss.str();
}

std::string Sha256File(const std::filesystem::path& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) {
        return {};
    }
    std::vector<unsigned char> data((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());

    BCRYPT_ALG_HANDLE alg = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    DWORD objectLength = 0;
    DWORD result = 0;
    DWORD hashLength = 0;
    std::vector<unsigned char> object;
    std::vector<unsigned char> digest;

    if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) != 0) {
        return {};
    }
    auto cleanup = [&]() {
        if (hash) {
            BCryptDestroyHash(hash);
        }
        if (alg) {
            BCryptCloseAlgorithmProvider(alg, 0);
        }
    };

    if (BCryptGetProperty(alg, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&objectLength), sizeof(objectLength), &result, 0) != 0 ||
        BCryptGetProperty(alg, BCRYPT_HASH_LENGTH, reinterpret_cast<PUCHAR>(&hashLength), sizeof(hashLength), &result, 0) != 0) {
        cleanup();
        return {};
    }

    object.resize(objectLength);
    digest.resize(hashLength);
    if (BCryptCreateHash(alg, &hash, object.data(), objectLength, nullptr, 0, 0) != 0 ||
        BCryptHashData(hash, data.data(), static_cast<ULONG>(data.size()), 0) != 0 ||
        BCryptFinishHash(hash, digest.data(), hashLength, 0) != 0) {
        cleanup();
        return {};
    }
    cleanup();
    return HexBytes(digest);
}

std::filesystem::path CurrentExePath() {
    std::wstring buffer(32768, L'\0');
    DWORD len = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    buffer.resize(len);
    return std::filesystem::path(buffer);
}

std::filesystem::path CurrentDllPath() {
    HMODULE module = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(&CurrentDllPath), &module)) {
        return {};
    }
    std::wstring buffer(32768, L'\0');
    DWORD len = GetModuleFileNameW(module, buffer.data(), static_cast<DWORD>(buffer.size()));
    buffer.resize(len);
    return std::filesystem::path(buffer);
}

Config LoadConfig() {
    Config cfg;
    std::string text = ReadTextFile(g_modRoot / "MorePlayers8.json");
    cfg.maxPlayers = JsonInt(text, "MaxPlayers", kDefaultMaxPlayers);
    if (cfg.maxPlayers < 1) {
        cfg.maxPlayers = 4;
    }
    if (cfg.maxPlayers > kMaxReasonablePlayers) {
        cfg.maxPlayers = kMaxReasonablePlayers;
    }
    cfg.enabled = JsonBool(text, "EnableNativeEOSCapacityPatch", false);
    cfg.requireKnownHash = JsonBool(text, "NativePatchRequireKnownHash", true);
    cfg.patchLobbySetMaxMembers = JsonBool(text, "EnableEOSLobbySetMaxMembersPatch", true);
    cfg.patchSessionSetMaxPlayers = JsonBool(text, "EnableEOSSessionSetMaxPlayersPatch", true);
    cfg.patchLobbyCreateLobby = JsonBool(text, "EnableEOSLobbyCreateLobbyPatch", true);
    cfg.patchSessionCreateModification = JsonBool(text, "EnableEOSSessionCreateModificationPatch", true);
    cfg.patchSteamLobbyCapacity = JsonBool(text, "EnableNativeSteamLobbyCapacityPatch", true);
    cfg.patchUnrealServerFullAdmission = JsonBool(text, "EnableNativeUnrealServerFullAdmissionPatch", true);
    cfg.patchJoinValidation = JsonBool(text, "EnableJoinValidationPatch", true);
    cfg.logAllCalls = JsonBool(text, "NativePatchLogAllCalls", true);
    cfg.knownHash = JsonString(text, "KnownGameExeSha256", kKnownExeSha256);
    return cfg;
}

bool LooksLikeEOSOptions(int32_t apiVersion, uint32_t count) {
    return apiVersion > 0 && apiVersion < 100 && count > 0 && count <= static_cast<uint32_t>(kMaxReasonablePlayers);
}

bool LooksLikeEOSApiVersion(int32_t apiVersion) {
    return apiVersion > 0 && apiVersion < 100;
}

bool IsCapacityKey(const char* key) {
    if (!key || !*key) {
        return false;
    }
    std::string value = ToLower(key);
    static const char* needles[] = {
        "max", "capacity", "member", "members", "players", "playerlimit",
        "lobbysize", "publicconnections", "numpublicconnections", "slots",
        "partysize", "limit"
    };
    for (const char* needle : needles) {
        if (value.find(needle) != std::string::npos) {
            return true;
        }
    }
    return false;
}

const char* AttributeTypeName(int32_t valueType) {
    switch (valueType) {
    case 0: return "Boolean";
    case 1: return "Int64";
    case 2: return "Double";
    case 3: return "String";
    default: return "Unknown";
    }
}

std::string AttributeValueToString(const EOS_AttributeValue_Min& value, int32_t valueType) {
    switch (valueType) {
    case 0:
        return value.AsBool ? "true" : "false";
    case 1:
        return std::to_string(value.AsInt64);
    case 2:
        return std::to_string(value.AsDouble);
    case 3:
        return value.AsUtf8 ? std::string("\"") + value.AsUtf8 + "\"" : "<null>";
    default:
        return "<unknown>";
    }
}

const char* PersistentCapacityString(int value) {
    static std::mutex tableMutex;
    static std::vector<std::string> table(static_cast<size_t>(kMaxReasonablePlayers) + 1);
    if (value < 1 || value > kMaxReasonablePlayers) {
        value = kDefaultMaxPlayers;
    }
    std::lock_guard<std::mutex> lock(tableMutex);
    std::string& slot = table[static_cast<size_t>(value)];
    if (slot.empty()) {
        slot = std::to_string(value);
    }
    return slot.c_str();
}

bool PatchAttributeValue(const char* source, const char* key, EOS_AttributeValue_Min& value, int32_t valueType, bool allowStringPointerPatch) {
    if (!IsCapacityKey(key)) {
        return false;
    }

    bool changed = false;
    if (valueType == 1 && value.AsInt64 > 0 && value.AsInt64 < g_config.maxPlayers) {
        value.AsInt64 = g_config.maxPlayers;
        changed = true;
    } else if (valueType == 3 && value.AsUtf8 && allowStringPointerPatch) {
        char* end = nullptr;
        long parsed = std::strtol(value.AsUtf8, &end, 10);
        if (end != value.AsUtf8 && *end == '\0' && parsed > 0 && parsed < g_config.maxPlayers) {
            value.AsUtf8 = PersistentCapacityString(g_config.maxPlayers);
            changed = true;
        }
    }

    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << source
            << " key=" << (key ? key : "<null>")
            << " type=" << AttributeTypeName(valueType)
            << " value=" << AttributeValueToString(value, valueType)
            << " changed=" << (changed ? "true" : "false");
        Log(oss.str());
    }
    return changed;
}

std::string PtrToString(const void* value);

int32_t ReadEosCallbackResultCode(const void* data) {
    if (!data) {
        return -999999;
    }
    return *reinterpret_cast<const int32_t*>(data);
}

void* ReadEosCallbackClientData(const void* data) {
    if (!data) {
        return nullptr;
    }
    return *reinterpret_cast<void* const*>(reinterpret_cast<const std::uint8_t*>(data) + sizeof(void*));
}

void WriteEosCallbackClientData(void* data, void* clientData) {
    if (!data) {
        return;
    }
    *reinterpret_cast<void**>(reinterpret_cast<std::uint8_t*>(data) + sizeof(void*)) = clientData;
}

void __cdecl Relay_LobbyCreateLobbyCallback(const void* data) {
    int32_t result = ReadEosCallbackResultCode(data);
    void* callbackClientData = ReadEosCallbackClientData(data);
    auto* relay = reinterpret_cast<CallbackRelay*>(callbackClientData);
    Log("EOS_Lobby_CreateLobby callback result=" + std::to_string(result) +
        " relay=" + PtrToString(relay));
    if (!relay) {
        return;
    }

    void* mutableData = const_cast<void*>(data);
    WriteEosCallbackClientData(mutableData, relay->originalClientData);
    EOS_GenericCallback_t originalCallback = relay->originalCallback;
    delete relay;
    if (originalCallback) {
        originalCallback(data);
    }
}

void __cdecl Hook_LobbyCreateLobby(void* handle, const EOS_Lobby_CreateLobbyOptions_Min* options, void* clientData, void* completionDelegate) {
    if (!g_originalLobbyCreateLobby) {
        return;
    }
    EOS_Lobby_CreateLobbyOptions_Min patched{};
    const EOS_Lobby_CreateLobbyOptions_Min* pass = options;
    bool changed = false;

    if (g_config.patchLobbyCreateLobby && options && LooksLikeEOSOptions(options->ApiVersion, options->MaxLobbyMembers) &&
        options->MaxLobbyMembers < static_cast<uint32_t>(g_config.maxPlayers)) {
        patched = *options;
        patched.MaxLobbyMembers = static_cast<uint32_t>(g_config.maxPlayers);
        pass = &patched;
        changed = true;
    }

    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << "EOS_Lobby_CreateLobby api="
            << (options ? options->ApiVersion : -1)
            << " beforeMaxLobbyMembers=" << (options ? options->MaxLobbyMembers : 0)
            << " afterMaxLobbyMembers=" << (pass ? pass->MaxLobbyMembers : 0)
            << " permission=" << (options ? options->PermissionLevel : -1)
            << " presence=" << (options ? options->bPresenceEnabled : -1)
            << " allowInvites=" << (options ? options->bAllowInvites : -1)
            << " bucket=" << (options && options->BucketId ? options->BucketId : "<null>")
            << " disableHostMigration=" << (options ? options->bDisableHostMigration : -1)
            << " rtc=" << (options ? options->bEnableRTCRoom : -1)
            << " joinById=" << (options ? options->bEnableJoinById : -1)
            << " changed=" << (changed ? "true" : "false");
        Log(oss.str());
    }

    CallbackRelay* relay = nullptr;
    void* callbackToPass = completionDelegate;
    void* clientDataToPass = clientData;
    if (completionDelegate) {
        relay = new (std::nothrow) CallbackRelay{ clientData, reinterpret_cast<EOS_GenericCallback_t>(completionDelegate) };
        if (relay) {
            clientDataToPass = relay;
            callbackToPass = reinterpret_cast<void*>(&Relay_LobbyCreateLobbyCallback);
        } else {
            Log("Failed to allocate EOS_Lobby_CreateLobby callback relay");
        }
    }

    g_originalLobbyCreateLobby(handle, pass, clientDataToPass, callbackToPass);
}

int32_t __cdecl Hook_LobbySetMaxMembers(void* handle, const EOS_LobbyModification_SetMaxMembersOptions_Min* options) {
    if (!g_originalLobbySetMaxMembers) {
        return -1;
    }
    EOS_LobbyModification_SetMaxMembersOptions_Min patched{};
    const EOS_LobbyModification_SetMaxMembersOptions_Min* pass = options;
    bool changed = false;

    if (g_config.patchLobbySetMaxMembers && options && LooksLikeEOSOptions(options->ApiVersion, options->MaxMembers) &&
        options->MaxMembers < static_cast<uint32_t>(g_config.maxPlayers)) {
        patched = *options;
        patched.MaxMembers = static_cast<uint32_t>(g_config.maxPlayers);
        pass = &patched;
        changed = true;
    }

    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << "EOS_LobbyModification_SetMaxMembers api="
            << (options ? options->ApiVersion : -1)
            << " before=" << (options ? options->MaxMembers : 0)
            << " after=" << (pass ? pass->MaxMembers : 0)
            << " changed=" << (changed ? "true" : "false");
        Log(oss.str());
    }
    return g_originalLobbySetMaxMembers(handle, pass);
}

int32_t __cdecl Hook_SessionsCreateSessionModification(void* handle, const EOS_Sessions_CreateSessionModificationOptions_Min* options, void** outSessionModificationHandle) {
    if (!g_originalSessionsCreateSessionModification) {
        return -1;
    }
    EOS_Sessions_CreateSessionModificationOptions_Min patched{};
    const EOS_Sessions_CreateSessionModificationOptions_Min* pass = options;
    bool changed = false;

    if (g_config.patchSessionCreateModification && options && LooksLikeEOSOptions(options->ApiVersion, options->MaxPlayers) &&
        options->MaxPlayers < static_cast<uint32_t>(g_config.maxPlayers)) {
        patched = *options;
        patched.MaxPlayers = static_cast<uint32_t>(g_config.maxPlayers);
        pass = &patched;
        changed = true;
    }

    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << "EOS_Sessions_CreateSessionModification api="
            << (options ? options->ApiVersion : -1)
            << " beforeMaxPlayers=" << (options ? options->MaxPlayers : 0)
            << " afterMaxPlayers=" << (pass ? pass->MaxPlayers : 0)
            << " sessionName=" << (options && options->SessionName ? options->SessionName : "<null>")
            << " bucket=" << (options && options->BucketId ? options->BucketId : "<null>")
            << " presence=" << (options ? options->bPresenceEnabled : -1)
            << " sessionId=" << (options && options->SessionId ? options->SessionId : "<null>")
            << " sanctions=" << (options ? options->bSanctionsEnabled : -1)
            << " changed=" << (changed ? "true" : "false");
        Log(oss.str());
    }
    return g_originalSessionsCreateSessionModification(handle, pass, outSessionModificationHandle);
}

int32_t __cdecl Hook_SessionSetMaxPlayers(void* handle, const EOS_SessionModification_SetMaxPlayersOptions_Min* options) {
    if (!g_originalSessionSetMaxPlayers) {
        return -1;
    }
    EOS_SessionModification_SetMaxPlayersOptions_Min patched{};
    const EOS_SessionModification_SetMaxPlayersOptions_Min* pass = options;
    bool changed = false;

    if (g_config.patchSessionSetMaxPlayers && options && LooksLikeEOSOptions(options->ApiVersion, options->MaxPlayers) &&
        options->MaxPlayers < static_cast<uint32_t>(g_config.maxPlayers)) {
        patched = *options;
        patched.MaxPlayers = static_cast<uint32_t>(g_config.maxPlayers);
        pass = &patched;
        changed = true;
    }

    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << "EOS_SessionModification_SetMaxPlayers api="
            << (options ? options->ApiVersion : -1)
            << " before=" << (options ? options->MaxPlayers : 0)
            << " after=" << (pass ? pass->MaxPlayers : 0)
            << " changed=" << (changed ? "true" : "false");
        Log(oss.str());
    }
    return g_originalSessionSetMaxPlayers(handle, pass);
}

int32_t __cdecl Hook_LobbyAddAttribute(void* handle, const EOS_LobbyModification_AddAttributeOptions_Min* options) {
    if (!g_originalLobbyAddAttribute) {
        return -1;
    }

    EOS_Lobby_AttributeData_Min patchedAttr{};
    EOS_LobbyModification_AddAttributeOptions_Min patchedOptions{};
    const EOS_LobbyModification_AddAttributeOptions_Min* pass = options;
    bool changed = false;

    if (options && LooksLikeEOSApiVersion(options->ApiVersion) && options->Attribute &&
        LooksLikeEOSApiVersion(options->Attribute->ApiVersion)) {
        patchedAttr = *options->Attribute;
        changed = PatchAttributeValue("EOS_LobbyModification_AddAttribute", patchedAttr.Key, patchedAttr.Value, patchedAttr.ValueType, true);
        if (changed) {
            patchedOptions = *options;
            patchedOptions.Attribute = &patchedAttr;
            pass = &patchedOptions;
        }
    }

    return g_originalLobbyAddAttribute(handle, pass);
}

int32_t __cdecl Hook_LobbyAddMemberAttribute(void* handle, const EOS_LobbyModification_AddMemberAttributeOptions_Min* options) {
    if (!g_originalLobbyAddMemberAttribute) {
        return -1;
    }

    EOS_Lobby_AttributeData_Min patchedAttr{};
    EOS_LobbyModification_AddMemberAttributeOptions_Min patchedOptions{};
    const EOS_LobbyModification_AddMemberAttributeOptions_Min* pass = options;
    bool changed = false;

    if (options && LooksLikeEOSApiVersion(options->ApiVersion) && options->Attribute &&
        LooksLikeEOSApiVersion(options->Attribute->ApiVersion)) {
        patchedAttr = *options->Attribute;
        changed = PatchAttributeValue("EOS_LobbyModification_AddMemberAttribute", patchedAttr.Key, patchedAttr.Value, patchedAttr.ValueType, true);
        if (changed) {
            patchedOptions = *options;
            patchedOptions.Attribute = &patchedAttr;
            pass = &patchedOptions;
        }
    }

    return g_originalLobbyAddMemberAttribute(handle, pass);
}

int32_t __cdecl Hook_LobbyDetailsCopyInfo(void* handle, const EOS_LobbyDetails_CopyInfoOptions_Min* options, EOS_LobbyDetails_Info_Min** outLobbyInfo) {
    if (!g_originalLobbyDetailsCopyInfo) {
        return -1;
    }
    int32_t result = g_originalLobbyDetailsCopyInfo(handle, options, outLobbyInfo);
    if (result == 0 && outLobbyInfo && *outLobbyInfo && LooksLikeEOSApiVersion((*outLobbyInfo)->ApiVersion)) {
        auto* info = *outLobbyInfo;
        uint32_t beforeMax = info->MaxMembers;
        uint32_t beforeSlots = info->AvailableSlots;
        bool changed = false;
        if (info->MaxMembers > 0 && info->MaxMembers < static_cast<uint32_t>(g_config.maxPlayers)) {
            info->MaxMembers = static_cast<uint32_t>(g_config.maxPlayers);
            changed = true;
        }
        if (info->AvailableSlots > 0 && beforeMax > 0 && beforeMax < static_cast<uint32_t>(g_config.maxPlayers)) {
            uint32_t usedSlots = beforeMax > beforeSlots ? beforeMax - beforeSlots : 0;
            info->AvailableSlots = static_cast<uint32_t>(g_config.maxPlayers) > usedSlots
                ? static_cast<uint32_t>(g_config.maxPlayers) - usedSlots
                : 0;
            changed = true;
        }
        if (g_config.logAllCalls || changed) {
            std::ostringstream oss;
            oss << "EOS_LobbyDetails_CopyInfo result=" << result
                << " lobbyId=" << (info->LobbyId ? info->LobbyId : "<null>")
                << " beforeMaxMembers=" << beforeMax
                << " afterMaxMembers=" << info->MaxMembers
                << " beforeAvailableSlots=" << beforeSlots
                << " afterAvailableSlots=" << info->AvailableSlots
                << " changed=" << (changed ? "true" : "false");
            Log(oss.str());
        }
    } else if (g_config.logAllCalls) {
        Log("EOS_LobbyDetails_CopyInfo result=" + std::to_string(result) + " info=<null-or-unexpected>");
    }
    return result;
}

int32_t __cdecl Hook_LobbyDetailsCopyAttributeByIndex(void* handle, const EOS_LobbyDetails_CopyAttributeByIndexOptions_Min* options, EOS_Lobby_Attribute_Min** outAttribute) {
    if (!g_originalLobbyDetailsCopyAttributeByIndex) {
        return -1;
    }
    int32_t result = g_originalLobbyDetailsCopyAttributeByIndex(handle, options, outAttribute);
    if (result == 0 && outAttribute && *outAttribute && (*outAttribute)->Data &&
        LooksLikeEOSApiVersion((*outAttribute)->Data->ApiVersion)) {
        auto* attr = *outAttribute;
        EOS_AttributeValue_Min before = attr->Data->Value;
        bool changed = PatchAttributeValue("EOS_LobbyDetails_CopyAttributeByIndex", attr->Data->Key, attr->Data->Value, attr->Data->ValueType, false);
        if (changed) {
            Log("EOS_LobbyDetails_CopyAttributeByIndex patched copied attribute key=" +
                std::string(attr->Data->Key ? attr->Data->Key : "<null>") +
                " before=" + AttributeValueToString(before, attr->Data->ValueType) +
                " after=" + AttributeValueToString(attr->Data->Value, attr->Data->ValueType));
        }
    }
    return result;
}

int32_t __cdecl Hook_SessionAddAttribute(void* handle, const EOS_SessionModification_AddAttributeOptions_Min* options) {
    if (!g_originalSessionAddAttribute) {
        return -1;
    }

    EOS_Sessions_AttributeData_Min patchedAttr{};
    EOS_SessionModification_AddAttributeOptions_Min patchedOptions{};
    const EOS_SessionModification_AddAttributeOptions_Min* pass = options;
    bool changed = false;

    if (options && LooksLikeEOSApiVersion(options->ApiVersion) && options->SessionAttribute &&
        LooksLikeEOSApiVersion(options->SessionAttribute->ApiVersion)) {
        patchedAttr = *options->SessionAttribute;
        changed = PatchAttributeValue("EOS_SessionModification_AddAttribute", patchedAttr.Key, patchedAttr.Value, patchedAttr.ValueType, true);
        if (changed) {
            patchedOptions = *options;
            patchedOptions.SessionAttribute = &patchedAttr;
            pass = &patchedOptions;
        }
    }

    return g_originalSessionAddAttribute(handle, pass);
}

int32_t __cdecl Hook_SessionDetailsCopyInfo(void* handle, const EOS_SessionDetails_CopyInfoOptions_Min* options, EOS_SessionDetails_Info_Min** outSessionInfo) {
    if (!g_originalSessionDetailsCopyInfo) {
        return -1;
    }
    int32_t result = g_originalSessionDetailsCopyInfo(handle, options, outSessionInfo);
    if (result == 0 && outSessionInfo && *outSessionInfo && LooksLikeEOSApiVersion((*outSessionInfo)->ApiVersion)) {
        auto* info = *outSessionInfo;
        uint32_t beforeOpen = info->NumOpenPublicConnections;
        uint32_t beforePublic = info->Settings ? info->Settings->NumPublicConnections : 0;
        bool changed = false;
        if (info->Settings && beforePublic > 0 && beforePublic < static_cast<uint32_t>(g_config.maxPlayers)) {
            auto* mutableSettings = const_cast<EOS_SessionDetails_Settings_Min*>(info->Settings);
            mutableSettings->NumPublicConnections = static_cast<uint32_t>(g_config.maxPlayers);
            changed = true;
        }
        if (beforeOpen > 0 && beforePublic > 0 && beforePublic < static_cast<uint32_t>(g_config.maxPlayers)) {
            uint32_t used = beforePublic > beforeOpen ? beforePublic - beforeOpen : 0;
            info->NumOpenPublicConnections = static_cast<uint32_t>(g_config.maxPlayers) > used
                ? static_cast<uint32_t>(g_config.maxPlayers) - used
                : 0;
            changed = true;
        }
        if (g_config.logAllCalls || changed) {
            std::ostringstream oss;
            oss << "EOS_SessionDetails_CopyInfo result=" << result
                << " sessionId=" << (info->SessionId ? info->SessionId : "<null>")
                << " beforeNumPublicConnections=" << beforePublic
                << " afterNumPublicConnections=" << (info->Settings ? info->Settings->NumPublicConnections : 0)
                << " beforeOpenPublicConnections=" << beforeOpen
                << " afterOpenPublicConnections=" << info->NumOpenPublicConnections
                << " changed=" << (changed ? "true" : "false");
            Log(oss.str());
        }
    } else if (g_config.logAllCalls) {
        Log("EOS_SessionDetails_CopyInfo result=" + std::to_string(result) + " info=<null-or-unexpected>");
    }
    return result;
}

int32_t __cdecl Hook_SessionDetailsCopySessionAttributeByIndex(void* handle, const EOS_SessionDetails_CopySessionAttributeByIndexOptions_Min* options, EOS_SessionDetails_Attribute_Min** outAttribute) {
    if (!g_originalSessionDetailsCopySessionAttributeByIndex) {
        return -1;
    }
    int32_t result = g_originalSessionDetailsCopySessionAttributeByIndex(handle, options, outAttribute);
    if (result == 0 && outAttribute && *outAttribute && (*outAttribute)->Data &&
        LooksLikeEOSApiVersion((*outAttribute)->Data->ApiVersion)) {
        auto* attr = *outAttribute;
        EOS_AttributeValue_Min before = attr->Data->Value;
        bool changed = PatchAttributeValue("EOS_SessionDetails_CopySessionAttributeByIndex", attr->Data->Key, attr->Data->Value, attr->Data->ValueType, false);
        if (changed) {
            Log("EOS_SessionDetails_CopySessionAttributeByIndex patched copied attribute key=" +
                std::string(attr->Data->Key ? attr->Data->Key : "<null>") +
                " before=" + AttributeValueToString(before, attr->Data->ValueType) +
                " after=" + AttributeValueToString(attr->Data->Value, attr->Data->ValueType));
        }
    }
    return result;
}

SteamAPICall_t __cdecl Hook_SteamCreateLobby(void* matchmaking, int lobbyType, int maxMembers) {
    if (!g_originalSteamCreateLobby) {
        return 0;
    }

    int patchedMembers = maxMembers;
    bool changed = false;
    if (g_config.patchSteamLobbyCapacity && maxMembers > 0 && maxMembers < g_config.maxPlayers) {
        patchedMembers = g_config.maxPlayers;
        changed = true;
    }

    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << "SteamAPI_ISteamMatchmaking_CreateLobby"
            << " lobbyType=" << lobbyType
            << " beforeMaxMembers=" << maxMembers
            << " afterMaxMembers=" << patchedMembers
            << " changed=" << (changed ? "true" : "false");
        Log(oss.str());
    }

    return g_originalSteamCreateLobby(matchmaking, lobbyType, patchedMembers);
}

bool __cdecl Hook_SteamSetLobbyMemberLimit(void* matchmaking, CSteamID_Min lobby, int maxMembers) {
    if (!g_originalSteamSetLobbyMemberLimit) {
        return false;
    }

    int patchedMembers = maxMembers;
    bool changed = false;
    if (g_config.patchSteamLobbyCapacity && maxMembers > 0 && maxMembers < g_config.maxPlayers) {
        patchedMembers = g_config.maxPlayers;
        changed = true;
    }

    bool result = g_originalSteamSetLobbyMemberLimit(matchmaking, lobby, patchedMembers);
    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << "SteamAPI_ISteamMatchmaking_SetLobbyMemberLimit"
            << " lobby=0x" << std::uppercase << std::hex << lobby << std::dec
            << " beforeMaxMembers=" << maxMembers
            << " afterMaxMembers=" << patchedMembers
            << " changed=" << (changed ? "true" : "false")
            << " result=" << (result ? "true" : "false");
        Log(oss.str());
    }

    return result;
}

int __cdecl Hook_SteamGetLobbyMemberLimit(void* matchmaking, CSteamID_Min lobby) {
    if (!g_originalSteamGetLobbyMemberLimit) {
        return 0;
    }

    int before = g_originalSteamGetLobbyMemberLimit(matchmaking, lobby);
    int after = before;
    bool changed = false;
    if (g_config.patchSteamLobbyCapacity && before > 0 && before < g_config.maxPlayers) {
        after = g_config.maxPlayers;
        changed = true;
    }

    if (g_config.logAllCalls || changed) {
        std::ostringstream oss;
        oss << "SteamAPI_ISteamMatchmaking_GetLobbyMemberLimit"
            << " lobby=0x" << std::uppercase << std::hex << lobby << std::dec
            << " before=" << before
            << " after=" << after
            << " changed=" << (changed ? "true" : "false");
        Log(oss.str());
    }

    return after;
}

std::string PtrToString(const void* value) {
    std::ostringstream oss;
    oss << "0x" << std::uppercase << std::hex << reinterpret_cast<std::uintptr_t>(value);
    return oss.str();
}

std::uint8_t* PtrFromRvaOrVa(std::uint8_t* base, DWORD sizeOfImage, ULONGLONG value, bool rvaBased) {
    if (value == 0) {
        return nullptr;
    }
    if (rvaBased || value < sizeOfImage) {
        return base + static_cast<std::uintptr_t>(value);
    }
    return reinterpret_cast<std::uint8_t*>(static_cast<std::uintptr_t>(value));
}

std::filesystem::path EosSdkDllPath() {
    std::filesystem::path exe = CurrentExePath();
    std::filesystem::path root = exe.parent_path();
    for (int i = 0; i < 3 && root.has_parent_path(); ++i) {
        root = root.parent_path();
    }
    return root / "Engine" / "Binaries" / "Win64" / "EOSSDK-Win64-Shipping.dll";
}

HMODULE LoadEosSdkModule() {
    HMODULE eos = GetModuleHandleW(L"EOSSDK-Win64-Shipping.dll");
    if (eos) {
        return eos;
    }

    std::filesystem::path eosPath = EosSdkDllPath();
    if (std::filesystem::exists(eosPath)) {
        eos = LoadLibraryW(eosPath.c_str());
        if (eos) {
            Log("Loaded EOS SDK for original exports from " + WideToUtf8(eosPath.wstring()));
            return eos;
        }
        Log("LoadLibrary failed for " + WideToUtf8(eosPath.wstring()) + " error=" + std::to_string(GetLastError()));
    }

    eos = LoadLibraryW(L"EOSSDK-Win64-Shipping.dll");
    if (eos) {
        Log("Loaded EOS SDK by DLL search path");
        return eos;
    }
    Log("Could not load EOSSDK-Win64-Shipping.dll error=" + std::to_string(GetLastError()));
    return nullptr;
}

std::filesystem::path SteamApiDllPath() {
    std::filesystem::path exe = CurrentExePath();
    std::filesystem::path root = exe.parent_path();
    for (int i = 0; i < 3 && root.has_parent_path(); ++i) {
        root = root.parent_path();
    }
    return root / "Engine" / "Binaries" / "ThirdParty" / "Steamworks" / "Steamv157" / "Win64" / "steam_api64.dll";
}

HMODULE LoadSteamApiModule() {
    HMODULE steam = GetModuleHandleW(L"steam_api64.dll");
    if (steam) {
        return steam;
    }

    std::filesystem::path steamPath = SteamApiDllPath();
    if (std::filesystem::exists(steamPath)) {
        steam = LoadLibraryW(steamPath.c_str());
        if (steam) {
            Log("Loaded Steam API for original exports from " + WideToUtf8(steamPath.wstring()));
            return steam;
        }
        Log("LoadLibrary failed for " + WideToUtf8(steamPath.wstring()) + " error=" + std::to_string(GetLastError()));
    }

    steam = LoadLibraryW(L"steam_api64.dll");
    if (steam) {
        Log("Loaded Steam API by DLL search path");
        return steam;
    }
    Log("Could not load steam_api64.dll error=" + std::to_string(GetLastError()));
    return nullptr;
}

void* ResolveEosExport(const char* functionName) {
    HMODULE eos = LoadEosSdkModule();
    if (!eos) {
        return nullptr;
    }
    void* proc = reinterpret_cast<void*>(GetProcAddress(eos, functionName));
    if (!proc) {
        Log(std::string("GetProcAddress failed for EOSSDK-Win64-Shipping.dll!") + functionName +
            " error=" + std::to_string(GetLastError()));
        return nullptr;
    }
    Log(std::string("Resolved EOS export ") + functionName + "=" + PtrToString(proc));
    return proc;
}

void* ResolveSteamExport(const char* functionName) {
    HMODULE steam = LoadSteamApiModule();
    if (!steam) {
        return nullptr;
    }
    void* proc = reinterpret_cast<void*>(GetProcAddress(steam, functionName));
    if (!proc) {
        Log(std::string("GetProcAddress failed for steam_api64.dll!") + functionName +
            " error=" + std::to_string(GetLastError()));
        return nullptr;
    }
    Log(std::string("Resolved Steam export ") + functionName + "=" + PtrToString(proc));
    return proc;
}

void* ResolveOriginalExport(const char* importModuleNeedle, const char* functionName) {
    std::string module = ToLower(importModuleNeedle ? importModuleNeedle : "");
    if (module.find("eos") != std::string::npos) {
        return ResolveEosExport(functionName);
    }
    if (module.find("steam") != std::string::npos) {
        return ResolveSteamExport(functionName);
    }
    Log(std::string("No resolver for import module ") + (importModuleNeedle ? importModuleNeedle : "<null>") +
        "!" + (functionName ? functionName : "<null>"));
    return nullptr;
}

bool PatchThunkPointer(void* slot, const char* tableName, const char* dllName, const char* functionName,
                       void* replacement, void* resolvedOriginal, void** original) {
    if (!slot || !replacement || !original) {
        return false;
    }
    void** typedSlot = reinterpret_cast<void**>(slot);
    void* current = *typedSlot;
    if (current == replacement) {
        if (*original == nullptr && resolvedOriginal != nullptr) {
            *original = resolvedOriginal;
        }
        Log(std::string(tableName) + " already patched " + dllName + "!" + functionName +
            " slot=" + PtrToString(slot));
        return true;
    }

    if (*original == nullptr) {
        *original = resolvedOriginal ? resolvedOriginal : current;
    }

    DWORD oldProtect = 0;
    if (!VirtualProtect(typedSlot, sizeof(*typedSlot), PAGE_READWRITE, &oldProtect)) {
        Log(std::string("VirtualProtect failed for ") + tableName + " " + functionName +
            " slot=" + PtrToString(slot) + " error=" + std::to_string(GetLastError()));
        return false;
    }
    *typedSlot = replacement;
    DWORD ignored = 0;
    VirtualProtect(typedSlot, sizeof(*typedSlot), oldProtect, &ignored);
    FlushInstructionCache(GetCurrentProcess(), typedSlot, sizeof(*typedSlot));
    Log(std::string("Patched ") + tableName + " " + dllName + "!" + functionName +
        " slot=" + PtrToString(slot) +
        " current=" + PtrToString(current) +
        " original=" + PtrToString(*original) +
        " replacement=" + PtrToString(replacement));
    return true;
}

bool PatchRegularImportByName(HMODULE module, const char* importModuleNeedle, const char* functionName, void* replacement, void** original) {
    if (!module || !replacement || !original) {
        return false;
    }
    auto* base = reinterpret_cast<std::uint8_t*>(module);
    auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) {
        return false;
    }
    auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) {
        return false;
    }
    auto& dir = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    if (dir.VirtualAddress == 0 || dir.Size == 0) {
        return false;
    }

    auto* desc = reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR*>(base + dir.VirtualAddress);
    std::string importNeedle = ToLower(importModuleNeedle);

    for (; desc->Name != 0; ++desc) {
        const char* dllName = reinterpret_cast<const char*>(base + desc->Name);
        std::string dllNameLower = ToLower(dllName);
        if (g_config.logAllCalls && (dllNameLower.find("eos") != std::string::npos || dllNameLower.find("steam") != std::string::npos)) {
            Log(std::string("Regular import DLL: ") + dllName);
        }
        if (dllNameLower.find(importNeedle) == std::string::npos) {
            continue;
        }

        auto* originalThunk = reinterpret_cast<IMAGE_THUNK_DATA*>(base + (desc->OriginalFirstThunk ? desc->OriginalFirstThunk : desc->FirstThunk));
        auto* firstThunk = reinterpret_cast<IMAGE_THUNK_DATA*>(base + desc->FirstThunk);
        for (; originalThunk->u1.AddressOfData != 0; ++originalThunk, ++firstThunk) {
            if (IMAGE_SNAP_BY_ORDINAL(originalThunk->u1.Ordinal)) {
                continue;
            }
            auto* importByName = reinterpret_cast<IMAGE_IMPORT_BY_NAME*>(base + originalThunk->u1.AddressOfData);
            const char* importedName = reinterpret_cast<const char*>(importByName->Name);
            if (g_config.logAllCalls && (std::strstr(importedName, "EOS_") == importedName ||
                std::strstr(importedName, "SteamAPI_") == importedName)) {
                Log(std::string("Regular import candidate ") + dllName + "!" + importedName);
            }
            if (std::strcmp(importedName, functionName) != 0) {
                continue;
            }

            return PatchThunkPointer(&firstThunk->u1.Function, "IAT", dllName, functionName, replacement, nullptr, original);
        }
    }

    if (g_config.logAllCalls) {
        Log(std::string("Regular IAT target not found: ") + importModuleNeedle + "!" + functionName);
    }
    return false;
}

bool PatchDelayImportByName(HMODULE module, const char* importModuleNeedle, const char* functionName, void* replacement, void** original) {
    if (!module || !replacement || !original) {
        return false;
    }
    auto* base = reinterpret_cast<std::uint8_t*>(module);
    auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) {
        return false;
    }
    auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) {
        return false;
    }
    auto& dir = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT];
    if (dir.VirtualAddress == 0 || dir.Size == 0) {
        Log("No delay import directory in main module");
        return false;
    }

    auto* desc = reinterpret_cast<IMAGE_DELAYLOAD_DESCRIPTOR*>(base + dir.VirtualAddress);
    std::string importNeedle = ToLower(importModuleNeedle);
    DWORD sizeOfImage = nt->OptionalHeader.SizeOfImage;

    for (; desc->DllNameRVA != 0; ++desc) {
        bool rvaBased = (desc->Attributes.AllAttributes & 1) != 0;
        const char* dllName = reinterpret_cast<const char*>(
            PtrFromRvaOrVa(base, sizeOfImage, desc->DllNameRVA, rvaBased));
        if (!dllName) {
            continue;
        }
        std::string dllNameLower = ToLower(dllName);
        if (g_config.logAllCalls && (dllNameLower.find("eos") != std::string::npos || dllNameLower.find("steam") != std::string::npos)) {
            Log(std::string("Delay import DLL: ") + dllName +
                " rvaBased=" + (rvaBased ? "true" : "false"));
        }
        if (dllNameLower.find(importNeedle) == std::string::npos) {
            continue;
        }

        auto* nameThunk = reinterpret_cast<IMAGE_THUNK_DATA*>(
            PtrFromRvaOrVa(base, sizeOfImage, desc->ImportNameTableRVA, rvaBased));
        auto* iatThunk = reinterpret_cast<IMAGE_THUNK_DATA*>(
            PtrFromRvaOrVa(base, sizeOfImage, desc->ImportAddressTableRVA, rvaBased));
        if (!nameThunk || !iatThunk) {
            Log(std::string("Delay import descriptor missing thunk table for ") + dllName);
            continue;
        }

        for (; nameThunk->u1.AddressOfData != 0; ++nameThunk, ++iatThunk) {
            if (IMAGE_SNAP_BY_ORDINAL(nameThunk->u1.Ordinal)) {
                continue;
            }
            auto* importByName = reinterpret_cast<IMAGE_IMPORT_BY_NAME*>(
                PtrFromRvaOrVa(base, sizeOfImage, nameThunk->u1.AddressOfData, rvaBased));
            if (!importByName) {
                continue;
            }
            const char* importedName = reinterpret_cast<const char*>(importByName->Name);
            if (g_config.logAllCalls && (std::strstr(importedName, "EOS_") == importedName ||
                std::strstr(importedName, "SteamAPI_") == importedName)) {
                Log(std::string("Delay import candidate ") + dllName + "!" + importedName +
                    " slot=" + PtrToString(&iatThunk->u1.Function));
            }
            if (std::strcmp(importedName, functionName) != 0) {
                continue;
            }

            void* resolvedOriginal = ResolveOriginalExport(importModuleNeedle, functionName);
            if (!resolvedOriginal) {
                Log(std::string("Delay IAT target found but original export missing: ") + dllName + "!" + functionName);
                return false;
            }
            return PatchThunkPointer(&iatThunk->u1.Function, "Delay IAT", dllName, functionName,
                                     replacement, resolvedOriginal, original);
        }
    }

    if (g_config.logAllCalls) {
        Log(std::string("Delay IAT target not found: ") + importModuleNeedle + "!" + functionName);
    }
    return false;
}

bool PatchImportByName(HMODULE module, const char* importModuleNeedle, const char* functionName, void* replacement, void** original) {
    if (PatchRegularImportByName(module, importModuleNeedle, functionName, replacement, original)) {
        return true;
    }
    return PatchDelayImportByName(module, importModuleNeedle, functionName, replacement, original);
}

bool PatchKnownApproveLoginServerFullBranch(HMODULE module) {
    if (!module) {
        Log("Unreal Server full admission patch skipped: main module is null");
        return false;
    }

    auto* base = reinterpret_cast<std::uint8_t*>(module);
    auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) {
        Log("Unreal Server full admission patch skipped: invalid DOS header");
        return false;
    }
    auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) {
        Log("Unreal Server full admission patch skipped: invalid NT header");
        return false;
    }
    if (kApproveLoginServerFullBranchRva + sizeof(kApproveLoginServerFullExpected) > nt->OptionalHeader.SizeOfImage) {
        Log("Unreal Server full admission patch skipped: target RVA outside image");
        return false;
    }

    std::uint8_t* target = base + kApproveLoginServerFullBranchRva;
    if (std::memcmp(target, kApproveLoginServerFullPatched, sizeof(kApproveLoginServerFullPatched)) == 0) {
        Log("Unreal Server full admission patch already active at RVA=0x" + [] {
            std::ostringstream oss;
            oss << std::uppercase << std::hex << kApproveLoginServerFullBranchRva;
            return oss.str();
        }());
        return true;
    }
    if (std::memcmp(target, kApproveLoginServerFullExpected, sizeof(kApproveLoginServerFullExpected)) != 0) {
        Log("Unreal Server full admission patch disabled: expected bytes mismatch at RVA=0x" + [] {
            std::ostringstream oss;
            oss << std::uppercase << std::hex << kApproveLoginServerFullBranchRva;
            return oss.str();
        }() + " actual=" + HexBytesRaw(target, sizeof(kApproveLoginServerFullExpected)) +
            " expected=" + HexBytesRaw(kApproveLoginServerFullExpected, sizeof(kApproveLoginServerFullExpected)));
        return false;
    }

    DWORD oldProtect = 0;
    if (!VirtualProtect(target, sizeof(kApproveLoginServerFullPatched), PAGE_EXECUTE_READWRITE, &oldProtect)) {
        Log("Unreal Server full admission patch VirtualProtect failed error=" + std::to_string(GetLastError()));
        return false;
    }
    std::memcpy(target, kApproveLoginServerFullPatched, sizeof(kApproveLoginServerFullPatched));
    DWORD ignored = 0;
    VirtualProtect(target, sizeof(kApproveLoginServerFullPatched), oldProtect, &ignored);
    FlushInstructionCache(GetCurrentProcess(), target, sizeof(kApproveLoginServerFullPatched));

    std::ostringstream rva;
    rva << std::uppercase << std::hex << kApproveLoginServerFullBranchRva;
    Log("Unreal Server full admission patch active: ApproveLogin Server full branch forced to skip at RVA=0x" +
        rva.str() + " before=" + HexBytesRaw(kApproveLoginServerFullExpected, sizeof(kApproveLoginServerFullExpected)) +
        " after=" + HexBytesRaw(target, sizeof(kApproveLoginServerFullPatched)));
    return true;
}

bool InstallHooks() {
    std::filesystem::path dll = CurrentDllPath();
    if (dll.empty()) {
        return false;
    }
    g_modRoot = dll.parent_path().parent_path();
    g_logPath = g_modRoot / "Logs" / "native_eos_patch.log";
    g_config = LoadConfig();

    Log("Native loader entered dll=" + WideToUtf8(dll.wstring()) + " modRoot=" + WideToUtf8(g_modRoot.wstring()));
    Log("Config enabled=" + std::string(g_config.enabled ? "true" : "false") +
        " maxPlayers=" + std::to_string(g_config.maxPlayers) +
        " requireKnownHash=" + (g_config.requireKnownHash ? "true" : "false") +
        " lobbyCreate=" + (g_config.patchLobbyCreateLobby ? "true" : "false") +
        " lobbySetMax=" + (g_config.patchLobbySetMaxMembers ? "true" : "false") +
        " sessionCreateModification=" + (g_config.patchSessionCreateModification ? "true" : "false") +
        " sessionSetMax=" + (g_config.patchSessionSetMaxPlayers ? "true" : "false") +
        " steamLobbyCapacity=" + (g_config.patchSteamLobbyCapacity ? "true" : "false") +
        " unrealServerFullAdmission=" + (g_config.patchUnrealServerFullAdmission ? "true" : "false") +
        " joinValidation=" + (g_config.patchJoinValidation ? "true" : "false"));

    if (!g_config.enabled) {
        Log("Native EOS capacity patch disabled by config");
        return true;
    }

    std::filesystem::path exe = CurrentExePath();
    std::string hash = Sha256File(exe);
    Log("Shipping EXE=" + WideToUtf8(exe.wstring()));
    Log("Shipping EXE SHA256=" + hash);

    if (g_config.requireKnownHash && ToLower(hash) != ToLower(g_config.knownHash)) {
        Log("Hash mismatch; native EOS capacity patch disabled");
        return false;
    }

    HMODULE mainModule = GetModuleHandleW(nullptr);
    bool unrealServerFullAdmissionOk = true;
    bool lobbyCreateOk = true;
    bool lobbySetMaxOk = true;
    bool sessionCreateModificationOk = true;
    bool sessionSetMaxOk = true;
    bool lobbyAddAttributeOk = true;
    bool lobbyAddMemberAttributeOk = true;
    bool lobbyDetailsCopyInfoOk = true;
    bool lobbyDetailsCopyAttributeOk = true;
    bool sessionAddAttributeOk = true;
    bool sessionDetailsCopyInfoOk = true;
    bool sessionDetailsCopyAttributeOk = true;
    bool steamCreateLobbyOk = true;
    bool steamSetLobbyMemberLimitOk = true;
    bool steamGetLobbyMemberLimitOk = true;
    if (g_config.patchUnrealServerFullAdmission && g_config.patchJoinValidation && g_config.maxPlayers > 4) {
        unrealServerFullAdmissionOk = PatchKnownApproveLoginServerFullBranch(mainModule);
    } else if (g_config.patchUnrealServerFullAdmission) {
        Log("Unreal Server full admission patch skipped because MaxPlayers<=4 or EnableJoinValidationPatch=false");
    }
    if (g_config.patchLobbyCreateLobby) {
        lobbyCreateOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_Lobby_CreateLobby",
                                          reinterpret_cast<void*>(&Hook_LobbyCreateLobby),
                                          reinterpret_cast<void**>(&g_originalLobbyCreateLobby));
    }
    if (g_config.patchLobbySetMaxMembers) {
        lobbySetMaxOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_LobbyModification_SetMaxMembers",
                                          reinterpret_cast<void*>(&Hook_LobbySetMaxMembers),
                                          reinterpret_cast<void**>(&g_originalLobbySetMaxMembers));
    }
    if (g_config.patchSessionCreateModification) {
        sessionCreateModificationOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_Sessions_CreateSessionModification",
                                                        reinterpret_cast<void*>(&Hook_SessionsCreateSessionModification),
                                                        reinterpret_cast<void**>(&g_originalSessionsCreateSessionModification));
    }
    if (g_config.patchSessionSetMaxPlayers) {
        sessionSetMaxOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_SessionModification_SetMaxPlayers",
                                            reinterpret_cast<void*>(&Hook_SessionSetMaxPlayers),
                                            reinterpret_cast<void**>(&g_originalSessionSetMaxPlayers));
    }

    lobbyAddAttributeOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_LobbyModification_AddAttribute",
                                            reinterpret_cast<void*>(&Hook_LobbyAddAttribute),
                                            reinterpret_cast<void**>(&g_originalLobbyAddAttribute));
    lobbyAddMemberAttributeOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_LobbyModification_AddMemberAttribute",
                                                  reinterpret_cast<void*>(&Hook_LobbyAddMemberAttribute),
                                                  reinterpret_cast<void**>(&g_originalLobbyAddMemberAttribute));
    lobbyDetailsCopyInfoOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_LobbyDetails_CopyInfo",
                                               reinterpret_cast<void*>(&Hook_LobbyDetailsCopyInfo),
                                               reinterpret_cast<void**>(&g_originalLobbyDetailsCopyInfo));
    lobbyDetailsCopyAttributeOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_LobbyDetails_CopyAttributeByIndex",
                                                    reinterpret_cast<void*>(&Hook_LobbyDetailsCopyAttributeByIndex),
                                                    reinterpret_cast<void**>(&g_originalLobbyDetailsCopyAttributeByIndex));
    sessionAddAttributeOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_SessionModification_AddAttribute",
                                              reinterpret_cast<void*>(&Hook_SessionAddAttribute),
                                              reinterpret_cast<void**>(&g_originalSessionAddAttribute));
    sessionDetailsCopyInfoOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_SessionDetails_CopyInfo",
                                                 reinterpret_cast<void*>(&Hook_SessionDetailsCopyInfo),
                                                 reinterpret_cast<void**>(&g_originalSessionDetailsCopyInfo));
    sessionDetailsCopyAttributeOk = PatchImportByName(mainModule, "EOSSDK-Win64-Shipping.dll", "EOS_SessionDetails_CopySessionAttributeByIndex",
                                                      reinterpret_cast<void*>(&Hook_SessionDetailsCopySessionAttributeByIndex),
                                                      reinterpret_cast<void**>(&g_originalSessionDetailsCopySessionAttributeByIndex));

    if (g_config.patchSteamLobbyCapacity) {
        steamCreateLobbyOk = PatchImportByName(mainModule, "steam_api64.dll", "SteamAPI_ISteamMatchmaking_CreateLobby",
                                               reinterpret_cast<void*>(&Hook_SteamCreateLobby),
                                               reinterpret_cast<void**>(&g_originalSteamCreateLobby));
        steamSetLobbyMemberLimitOk = PatchImportByName(mainModule, "steam_api64.dll", "SteamAPI_ISteamMatchmaking_SetLobbyMemberLimit",
                                                       reinterpret_cast<void*>(&Hook_SteamSetLobbyMemberLimit),
                                                       reinterpret_cast<void**>(&g_originalSteamSetLobbyMemberLimit));
        steamGetLobbyMemberLimitOk = PatchImportByName(mainModule, "steam_api64.dll", "SteamAPI_ISteamMatchmaking_GetLobbyMemberLimit",
                                                       reinterpret_cast<void*>(&Hook_SteamGetLobbyMemberLimit),
                                                       reinterpret_cast<void**>(&g_originalSteamGetLobbyMemberLimit));
    }

    bool eosInstalled = lobbyCreateOk && lobbySetMaxOk && sessionCreateModificationOk && sessionSetMaxOk &&
        lobbyAddAttributeOk && lobbyAddMemberAttributeOk && lobbyDetailsCopyInfoOk && lobbyDetailsCopyAttributeOk &&
        sessionAddAttributeOk && sessionDetailsCopyInfoOk && sessionDetailsCopyAttributeOk;
    bool steamInstalled = steamCreateLobbyOk && steamSetLobbyMemberLimitOk && steamGetLobbyMemberLimitOk;
    g_installed = eosInstalled && unrealServerFullAdmissionOk;
    Log("Patch status unrealServerFullAdmission=" + std::string(unrealServerFullAdmissionOk ? "true" : "false") +
        " lobbyCreate=" + (lobbyCreateOk ? "true" : "false") +
        " lobbySetMax=" + (lobbySetMaxOk ? "true" : "false") +
        " sessionCreateModification=" + (sessionCreateModificationOk ? "true" : "false") +
        " sessionSetMax=" + (sessionSetMaxOk ? "true" : "false") +
        " lobbyAddAttribute=" + (lobbyAddAttributeOk ? "true" : "false") +
        " lobbyAddMemberAttribute=" + (lobbyAddMemberAttributeOk ? "true" : "false") +
        " lobbyDetailsCopyInfo=" + (lobbyDetailsCopyInfoOk ? "true" : "false") +
        " lobbyDetailsCopyAttribute=" + (lobbyDetailsCopyAttributeOk ? "true" : "false") +
        " sessionAddAttribute=" + (sessionAddAttributeOk ? "true" : "false") +
        " sessionDetailsCopyInfo=" + (sessionDetailsCopyInfoOk ? "true" : "false") +
        " sessionDetailsCopyAttribute=" + (sessionDetailsCopyAttributeOk ? "true" : "false") +
        " steamCreateLobby=" + (steamCreateLobbyOk ? "true" : "false") +
        " steamSetLobbyMemberLimit=" + (steamSetLobbyMemberLimitOk ? "true" : "false") +
        " steamGetLobbyMemberLimit=" + (steamGetLobbyMemberLimitOk ? "true" : "false"));
    if (g_config.patchSteamLobbyCapacity && !steamInstalled) {
        Log("Steamworks lobby hook incomplete or unused by this executable; treating Steam hook status as non-fatal diagnostic");
    }
    Log(std::string("Native capacity/admission patch install result=") + (g_installed ? "true" : "false"));
    return g_installed;
}

} // namespace

extern "C" __declspec(dllexport) int MorePlayers8_InstallHooks(void*) {
    static std::once_flag once;
    std::call_once(once, [&]() {
        InstallHooks();
    });
    // package.loadlib expects a lua_CFunction-style return value: number of Lua
    // values pushed onto the stack. Status is reported through native_eos_patch.log.
    return 0;
}

BOOL APIENTRY DllMain(HMODULE, DWORD, LPVOID) {
    return TRUE;
}
