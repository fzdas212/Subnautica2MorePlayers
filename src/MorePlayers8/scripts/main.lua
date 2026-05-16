local MOD_NAME = "Subnautica2MorePlayers8"
local MOD_VERSION = "0.3.6-64-production"

local function script_dir()
    local src = debug.getinfo(1, "S").source
    if string.sub(src, 1, 1) == "@" then src = string.sub(src, 2) end
    local root = src:match("^(.*)[/\\]scripts[/\\]main%.lua$")
    if root ~= nil then return root end
    local cwd = io.popen("cd")
    if cwd then
        local line = cwd:read("*l")
        cwd:close()
        if line ~= nil and line ~= "" then
            local installed = line .. "\\ue4ss\\Mods\\" .. MOD_NAME
            local probe = io.open(installed .. "\\MorePlayers8.json", "r")
            if probe then
                probe:close()
                return installed
            end
        end
    end
    return ".\\ue4ss\\Mods\\" .. MOD_NAME
end

local ROOT = script_dir()
local LOG_DIR = ROOT .. "\\Logs"
os.execute('mkdir "' .. LOG_DIR .. '" 2>nul')

local LOG_FILE = LOG_DIR .. "\\MorePlayers8.log"
local DISCOVERY_FILE = LOG_DIR .. "\\discovery_candidates.txt"
local PROPERTY_FILE = LOG_DIR .. "\\property_probe.txt"
local SIGNATURE_FILE = LOG_DIR .. "\\function_signature_probe.txt"
local HOST_TRACE_FILE = LOG_DIR .. "\\host_session_args.txt"
local UI_TRACE_FILE = LOG_DIR .. "\\ui_probe.txt"
local CAPACITY_TRACE_FILE = LOG_DIR .. "\\capacity_trace.txt"
local ADMISSION_TRACE_FILE = LOG_DIR .. "\\admission_trace.txt"
local SESSION_DIRECT_TRACE_FILE = LOG_DIR .. "\\session_direct_patch.txt"

local SESSION_ID = os.date("!%Y%m%dT%H%M%SZ")
local config = nil

local function append(path, line)
    if config ~= nil and path ~= LOG_FILE and config.EnableTraceFiles ~= true then
        return
    end
    local f = io.open(path, "a")
    if f then
        f:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), " ", line, "\n")
        f:close()
    end
end

local function log_level_value(level)
    local v = string.lower(tostring(level or ""))
    if v == "debug" then return 10 end
    if v == "info" then return 20 end
    if v == "warn" or v == "warning" then return 30 end
    if v == "error" then return 40 end
    return 20
end

local function should_log(level)
    if config ~= nil and config.EnableLogging == false then return false end
    local configured = "Info"
    if config ~= nil and config.LogLevel ~= nil then configured = config.LogLevel end
    return log_level_value(level) >= log_level_value(configured)
end

local function log(level, msg)
    if not should_log(level) then return end
    local line = string.format("[%s] [%s] %s", MOD_NAME, level, msg)
    print(line .. "\n")
    append(LOG_FILE, line)
end

local function read_all(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function json_bool(text, key, default)
    local raw = text:match('"' .. key .. '"%s*:%s*(true)') or text:match('"' .. key .. '"%s*:%s*(false)')
    if raw == nil then return default end
    return raw == "true"
end

local function json_int(text, key, default)
    local raw = text:match('"' .. key .. '"%s*:%s*(%d+)')
    return tonumber(raw) or default
end

local function json_string(text, key, default)
    return text:match('"' .. key .. '"%s*:%s*"([^"]*)"') or default
end

local function load_config()
    local text = read_all(ROOT .. "\\MorePlayers8.json") or "{}"
    local maxPlayers = json_int(text, "MaxPlayers", 64)
    if maxPlayers < 1 then maxPlayers = 4 end
    if maxPlayers > 64 then maxPlayers = 64 end
    return {
        MaxPlayers = maxPlayers,
        EnableLobbyPatch = json_bool(text, "EnableLobbyPatch", true),
        EnableSessionPatch = json_bool(text, "EnableSessionPatch", true),
        EnableJoinValidationPatch = json_bool(text, "EnableJoinValidationPatch", true),
        EnableLogging = json_bool(text, "EnableLogging", true),
        LogLevel = json_string(text, "LogLevel", "Info"),
        EnableTraceFiles = json_bool(text, "EnableTraceFiles", false),
        EnableHooks = json_bool(text, "EnableHooks", false),
        HookProfile = json_string(text, "HookProfile", "None"),
        EnableDelayedTasks = json_bool(text, "EnableDelayedTasks", false),
        RetryUnavailableHooks = json_bool(text, "RetryUnavailableHooks", false),
        EnableUnsafeObjectReflection = json_bool(text, "EnableUnsafeObjectReflection", false),
        EnableUIPatch = json_bool(text, "EnableUIPatch", false),
        EnableTargetedUIPatch = json_bool(text, "EnableTargetedUIPatch", false),
        EnableTargetedUISweeps = json_bool(text, "EnableTargetedUISweeps", false),
        EnableTargetedUIAllTextSweep = json_bool(text, "EnableTargetedUIAllTextSweep", false),
        EnableSafeParamProbe = json_bool(text, "EnableSafeParamProbe", true),
        EnableSafeNumericParamPatch = json_bool(text, "EnableSafeNumericParamPatch", false),
        EnableDiscoveryScan = json_bool(text, "EnableDiscoveryScan", false),
        EnableClassDiscovery = json_bool(text, "EnableClassDiscovery", false),
        EnableDynamicDiscoveryHooks = json_bool(text, "EnableDynamicDiscoveryHooks", false),
        EnableObjectWatchers = json_bool(text, "EnableObjectWatchers", false),
        EnableUITraceHooks = json_bool(text, "EnableUITraceHooks", false),
        EnableUISweep = json_bool(text, "EnableUISweep", false),
        EnableInitGameStateTrace = json_bool(text, "EnableInitGameStateTrace", false),
        EnableAdmissionGameSessionPatch = json_bool(text, "EnableAdmissionGameSessionPatch", true),
        AdmissionPatchIntervalMs = json_int(text, "AdmissionPatchIntervalMs", 5000),
        EnableDirectSessionCapacityPatch = json_bool(text, "EnableDirectSessionCapacityPatch", true),
        DirectSessionPatchIntervalMs = json_int(text, "DirectSessionPatchIntervalMs", 10000),
        EnableAdmissionReturnPatch = json_bool(text, "EnableAdmissionReturnPatch", true),
        EnableDelayedSessionSweep = json_bool(text, "EnableDelayedSessionSweep", false),
        EnableHostTriggeredSessionSweep = json_bool(text, "EnableHostTriggeredSessionSweep", false),
        EnableReflectedPropertyPatch = json_bool(text, "EnableReflectedPropertyPatch", false),
        EnableFullPropertyProbe = json_bool(text, "EnableFullPropertyProbe", false),
        EnableObjectDumpOnStartup = json_bool(text, "EnableObjectDumpOnStartup", false),
        DisableOnUnknownGameHash = json_bool(text, "DisableOnUnknownGameHash", false),
        KnownGameExeSha256 = json_string(text, "KnownGameExeSha256", ""),
        EnableNativeEOSCapacityPatch = json_bool(text, "EnableNativeEOSCapacityPatch", false),
        NativePatchRequireKnownHash = json_bool(text, "NativePatchRequireKnownHash", true)
    }
end

config = load_config()

local retainedCallbacks = {}
local playercountPatchSeen = 0
local playercountPatchLogged = 0
local lowNoiseHookSeen = {}
local lastPlayercountBefore = nil
local lastPlayercountAfter = nil

local function retain_callback(label, fn)
    retainedCallbacks[#retainedCallbacks + 1] = { label = label, fn = fn }
    return fn
end

local function schedule_game_thread_delay(delayMs, label, fn)
    return ExecuteInGameThreadWithDelay(delayMs, retain_callback("delay " .. tostring(label), fn))
end

for _, path in ipairs({LOG_FILE, DISCOVERY_FILE, PROPERTY_FILE, SIGNATURE_FILE, HOST_TRACE_FILE, UI_TRACE_FILE, CAPACITY_TRACE_FILE, ADMISSION_TRACE_FILE, SESSION_DIRECT_TRACE_FILE}) do
    append(path, "===== " .. MOD_NAME .. " session " .. SESSION_ID .. " version=" .. MOD_VERSION .. " =====")
end

local function safe(fn, default)
    local ok, result = pcall(fn)
    if ok then return result end
    return default
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function contains_any(text, keywords)
    local s = lower(text)
    for _, kw in ipairs(keywords) do
        if string.find(s, lower(kw), 1, true) then return true end
    end
    return false
end

local function unsafe_reflection_enabled()
    return config ~= nil and config.EnableUnsafeObjectReflection == true
end

local function bool_text(v)
    if v then return "true" end
    return "false"
end

local function count_char(text, needle)
    local _, n = string.gsub(tostring(text or ""), needle, "")
    return n
end

local function ftext_to_string(value)
    if value == nil then return nil end
    if type(value) == "string" then return value end
    if type(value) ~= "userdata" then return nil end

    local text = safe(function() return value:ToString() end, nil)
    if text ~= nil then return tostring(text) end

    local inner = safe(function() return value:get() end, nil)
    if inner ~= nil and inner ~= value then
        return ftext_to_string(inner)
    end

    return nil
end

local function text_param_to_string(param)
    if param == nil then return nil end
    local direct = ftext_to_string(param)
    if direct ~= nil then return direct end
    if type(param) == "userdata" then
        local value = safe(function() return param:get() end, nil)
        return ftext_to_string(value)
    end
    return nil
end

local function rewrite_player_count_text(text)
    if type(text) ~= "string" then return nil end
    if count_char(text, "/") ~= 1 then return nil end
    if #text > 64 then return nil end

    local prefix, currentText, denominatorText, suffix = string.match(text, "^(.-)(%d+)%s*/%s*(%d+)(.-)$")
    if currentText == nil then return nil end

    local current = tonumber(currentText)
    local denominator = tonumber(denominatorText)
    if current == nil or current < 0 or current > config.MaxPlayers then return nil end
    if denominator == nil or denominator < 1 or denominator >= config.MaxPlayers then return nil end
    if string.find(lower(text), "http", 1, true) ~= nil then return nil end

    return string.format("%s%d/%d%s", prefix, current, config.MaxPlayers, suffix)
end

local function patch_ui_text_param(path, phase, param)
    if not config.EnableUIPatch then return false end
    if param == nil or type(param) ~= "userdata" then return false end

    local before = text_param_to_string(param)
    local after = rewrite_player_count_text(before)
    if after == nil or after == before then return false end

    local okSet = safe(function()
        param:set(FText(after))
        return true
    end, false)

    append(CAPACITY_TRACE_FILE, string.format("UI_TEXT_PATCH path=%s phase=%s before=%s after=%s ok=%s", path, phase, tostring(before), tostring(after), tostring(okSet)))
    log(okSet and "Info" or "Warn", string.format("UI player-count text patch %s -> %s ok=%s", tostring(before), tostring(after), tostring(okSet)))
    return okSet
end

local function get_widget_text(widget)
    if widget == nil or type(widget) ~= "userdata" then return nil end

    local text = safe(function()
        local value = widget:GetText()
        return ftext_to_string(value)
    end, nil)
    if text ~= nil then return text end

    local propText = safe(function() return widget.Text end, nil)
    return ftext_to_string(propText)
end

local function set_widget_text(widget, text)
    if widget == nil or type(widget) ~= "userdata" or type(text) ~= "string" then return false end
    return safe(function()
        widget:SetText(FText(text))
        return true
    end, false)
end

local targetedTextWidgetNames = {
    "SessionNameText",
    "FriendCodeFeedbackText",
    "NetworkWarning_Text",
    "SaveListDescriptionText",
    "PlayerCountText",
    "PlayerCount_Text",
    "PartyCountText",
    "PartyCount_Text",
    "MemberCountText",
    "MemberCount_Text",
    "LobbyCountText",
    "LobbyCount_Text",
    "NumPlayersText",
    "NumPlayers_Text",
    "CurrentPlayersText",
    "CurrentPlayers_Text"
}

local targetedTextWidgetClasses = {
    "CommonTextBlock",
    "TextBlock",
    "RichTextBlock",
    "CommonRichTextBlock",
    "CommonNumericTextBlock",
    "AutoWrapTextBlock",
    "GPPTextBlockList",
    "UWEBlockWithLinks"
}

local function patch_text_widget(widget, source, reason)
    local before = get_widget_text(widget)
    if before == nil then return false end

    local after = rewrite_player_count_text(before)
    if after == nil or after == before then
        if string.find(before, "/4", 1, true) ~= nil then
            append(UI_TRACE_FILE, string.format("TARGETED_UI_CANDIDATE source=%s reason=%s text=%s", source, reason, before))
        end
        return false
    end

    local okSet = set_widget_text(widget, after)
    local exactTopCount = string.match(before, "^%s*%d+%s*/%s*4%s*$") ~= nil
    append(CAPACITY_TRACE_FILE, string.format("TARGETED_UI_PATCH source=%s reason=%s before=%s after=%s ok=%s", source, reason, before, after, tostring(okSet)))
    append(UI_TRACE_FILE, string.format("TARGETED_UI_PATCH source=%s reason=%s before=%s after=%s ok=%s", source, reason, before, after, tostring(okSet)))
    if exactTopCount then
        append(CAPACITY_TRACE_FILE, string.format("TARGETED_UI_EXACT_COUNT_PATCH source=%s reason=%s before=%s after=%s ok=%s", source, reason, before, after, tostring(okSet)))
        append(UI_TRACE_FILE, string.format("TARGETED_UI_EXACT_COUNT_PATCH source=%s reason=%s before=%s after=%s ok=%s", source, reason, before, after, tostring(okSet)))
    end
    log(okSet and "Info" or "Warn", string.format("Targeted UI player-count patch %s -> %s source=%s ok=%s", tostring(before), tostring(after), source, tostring(okSet)))
    return okSet
end

local function find_named_text_widgets(className, objectName)
    local objects = safe(function()
        return FindObjects(0, className, objectName, 0x10, 0, false)
    end, nil)
    if objects ~= nil then return objects end

    local one = safe(function()
        return FindObject(className, objectName, 0x10, 0)
    end, nil)
    if one ~= nil then return { one } end
    return nil
end

local function patch_known_named_text_widgets(reason)
    local scanned = 0
    local patched = 0

    for _, className in ipairs(targetedTextWidgetClasses) do
        for _, objectName in ipairs(targetedTextWidgetNames) do
            local objects = find_named_text_widgets(className, objectName)
            if objects ~= nil then
                for _, widget in pairs(objects) do
                    scanned = scanned + 1
                    if patch_text_widget(widget, className .. ":" .. objectName, reason) then
                        patched = patched + 1
                    end
                end
            end
        end
    end

    return scanned, patched
end

local function patch_all_loaded_text_widgets(reason)
    if not config.EnableTargetedUIAllTextSweep then return 0, 0 end

    local scanned = 0
    local patched = 0
    local scanLimitPerClass = 4096

    for _, className in ipairs(targetedTextWidgetClasses) do
        local objects = safe(function() return FindAllOf(className) end, nil)
        if objects ~= nil then
            local classCount = 0
            local classPatched = 0
            for _, widget in pairs(objects) do
                classCount = classCount + 1
                if classCount > scanLimitPerClass then break end
                scanned = scanned + 1
                if patch_text_widget(widget, className .. ":loaded-sweep", reason) then
                    patched = patched + 1
                    classPatched = classPatched + 1
                end
            end
            append(UI_TRACE_FILE, string.format("TARGETED_UI_CLASS_SWEEP reason=%s class=%s scanned=%d patched=%d", reason, className, classCount, classPatched))
        else
            append(UI_TRACE_FILE, string.format("TARGETED_UI_CLASS_SWEEP reason=%s class=%s scanned=0 patched=0 unavailable=true", reason, className))
        end
    end

    return scanned, patched
end

local function run_targeted_ui_patch(reason)
    if not config.EnableTargetedUIPatch then return 0 end
    if not config.EnableTargetedUISweeps then
        append(UI_TRACE_FILE, string.format("TARGETED_UI_SWEEP_SKIPPED reason=%s EnableTargetedUISweeps=false", reason))
        return 0
    end

    local namedScanned, namedPatched = patch_known_named_text_widgets(reason)
    local allScanned, allPatched = patch_all_loaded_text_widgets(reason)
    local totalPatched = namedPatched + allPatched

    append(UI_TRACE_FILE, string.format("TARGETED_UI_SWEEP reason=%s namedScanned=%d namedPatched=%d allScanned=%d allPatched=%d", reason, namedScanned, namedPatched, allScanned, allPatched))
    if totalPatched > 0 then
        append(CAPACITY_TRACE_FILE, string.format("TARGETED_UI_SWEEP_PATCHED reason=%s totalPatched=%d", reason, totalPatched))
    end
    return totalPatched
end

local function schedule_targeted_ui_patch(reason)
    if not config.EnableTargetedUIPatch then return end
    if not config.EnableTargetedUISweeps then
        append(UI_TRACE_FILE, string.format("TARGETED_UI_SCHEDULE_SKIPPED reason=%s EnableTargetedUISweeps=false", reason))
        return
    end
    run_targeted_ui_patch(reason .. " immediate")
    schedule_game_thread_delay(100, reason .. " +100ms targeted-ui", function()
        run_targeted_ui_patch(reason .. " +100ms")
    end)
    schedule_game_thread_delay(1000, reason .. " +1000ms targeted-ui", function()
        run_targeted_ui_patch(reason .. " +1000ms")
    end)
    schedule_game_thread_delay(3000, reason .. " +3000ms targeted-ui", function()
        run_targeted_ui_patch(reason .. " +3000ms")
    end)
    schedule_game_thread_delay(7000, reason .. " +7000ms targeted-ui", function()
        run_targeted_ui_patch(reason .. " +7000ms")
    end)
    schedule_game_thread_delay(12000, reason .. " +12000ms targeted-ui", function()
        run_targeted_ui_patch(reason .. " +12000ms")
    end)
end

local function patch_playercount_return(path, phase, args)
    if not config.EnableTargetedUIPatch then return nil end
    if phase ~= "post" then return nil end
    if string.find(path, ":AssemblePlayercountString", 1, true) == nil then return nil end
    if args == nil or #args < 1 then
        append(UI_TRACE_FILE, string.format("VIEWMODEL_PLAYERCOUNT_RETURN path=%s phase=%s args=0", path, phase))
        return nil
    end

    local ret = args[1]
    local before = text_param_to_string(ret)
    if before == nil and type(ret) == "userdata" then
        local value = safe(function() return ret:get() end, nil)
        if type(value) == "string" then
            before = value
        else
            before = ftext_to_string(value)
        end
    end

    local after = rewrite_player_count_text(before)
    if after == nil or after == before then
        if playercountPatchSeen < 10 then
            append(UI_TRACE_FILE, string.format("VIEWMODEL_PLAYERCOUNT_RETURN path=%s phase=%s before=%s no_patch=true", path, phase, tostring(before)))
        end
        if before ~= nil and string.find(before, "/4", 1, true) ~= nil then
            append(CAPACITY_TRACE_FILE, string.format("VIEWMODEL_PLAYERCOUNT_UNPATCHED path=%s before=%s", path, before))
        end
        return nil
    end

    local okString = false
    local okFText = false
    if type(ret) == "userdata" then
        okString = safe(function()
            ret:set(after)
            return true
        end, false)
        if not okString then
            okFText = safe(function()
                ret:set(FText(after))
                return true
            end, false)
        end
    end

    playercountPatchSeen = playercountPatchSeen + 1
    local shouldLog = playercountPatchSeen <= 10 or before ~= lastPlayercountBefore or after ~= lastPlayercountAfter
    lastPlayercountBefore = before
    lastPlayercountAfter = after
    if shouldLog then
        playercountPatchLogged = playercountPatchLogged + 1
        append(CAPACITY_TRACE_FILE, string.format("VIEWMODEL_PLAYERCOUNT_PATCH path=%s before=%s after=%s setString=%s setFText=%s count=%d", path, before, after, tostring(okString), tostring(okFText), playercountPatchSeen))
        append(UI_TRACE_FILE, string.format("VIEWMODEL_PLAYERCOUNT_PATCH path=%s before=%s after=%s setString=%s setFText=%s count=%d", path, before, after, tostring(okString), tostring(okFText), playercountPatchSeen))
        log("Info", string.format("Patched ViewModel player count %s -> %s via %s count=%d", tostring(before), tostring(after), path, playercountPatchSeen))
    end

    if okString then return after end
    if okFText then return FText(after) end
    return nil
end

local function should_trace_low_noise_event(entry, phase)
    if entry == nil then return true end
    if entry.kind ~= "ui-playercount" then return true end

    local key = tostring(entry.path) .. " " .. tostring(phase)
    if lowNoiseHookSeen[key] == true then return false end
    lowNoiseHookSeen[key] = true
    return true
end

local playerLimitProperties = {
    "MaxPlayers", "MaxPlayer", "PlayerLimit", "PlayerCap", "PlayerCapacity",
    "MaxPlayerCapacity", "MaxConnections", "NumPublicConnections",
    "NumPrivateConnections", "MaxPublicConnections", "PublicConnections",
    "PrivateConnections", "MaxPartySize", "PartySize", "LobbySize",
    "Capacity", "MaxCapacity", "LobbyCapacity", "MemberLimit", "MaxMembers",
    "MaxMemberCount", "MaxLobbyMembers", "MaxSlots", "SlotCount", "TotalSlots",
    "MaxNumPlayers", "MaxNumberOfPlayers", "MaxPlayerCount",
    "NumOpenPublicConnections", "NumOpenPrivateConnections", "TotalPlayerSlots"
}

local directProbeProperties = {
    "MaxPlayers", "MaxPlayer", "MaxPlayerCount", "MaxPublicConnections",
    "MaxPrivateConnections", "NumPublicConnections", "NumPrivateConnections",
    "NumOpenPublicConnections", "NumOpenPrivateConnections", "PlayerCount",
    "CurrentPlayers", "CurrentPlayerCount", "PlayerLimit", "PlayerCapacity",
    "LobbySize", "LobbyCapacity", "Capacity", "MaxCapacity", "MemberLimit",
    "MaxMembers", "MaxMemberCount", "CurrentMembers", "MemberCount",
    "OpenSlots", "SlotCount", "PartySize", "MaxPartySize",
    "HostSessionRequest", "Request", "SessionRequest", "OnlineMode",
    "Privacy", "PrivacyMode", "CrossPlayMode", "GameMode", "FriendCode",
    "SessionName", "SessionId", "GameSessionId", "LobbyId", "ClientSessionInfo",
    "SessionInfo", "HostedSession", "CurrentSession", "SearchResult", "Result",
    "IsFull", "bIsFull", "CanJoin", "CanJoinGame", "NumPlayers", "PlayerNum",
    "Text", "DefaultText", "Content", "DisplayText", "PresenceText", "FriendName"
}

local targetClasses = {
    "/Script/UWESonar.UWEMultiplayerHostedSessionViewModel",
    "/Script/UWESonar.UWEHostSessionRequest",
    "/Script/UWESonar.UWESearchSessionResult",
    "/Script/UWESonar.UWEOnlineSessionSubsystem",
    "/Script/UWESonar.UWEClientSessionInfo",
    "/Script/UWELobby.UWELobbyGameMode",
    "/Script/UWELobby.UWELobbyGameState",
    "/Script/UWELobby.UWEServerLobbyComponent",
    "/Script/CommonUser.CommonSession_HostSessionRequest",
    "/Script/CommonUser.CommonSessionSubsystem",
    "/Script/Subnautica2.SN2GameSession",
    "/Script/Subnautica2.SN2LobbyGameMode",
    "/Script/Subnautica2.SN2FriendScreenViewModel",
    "/Script/Subnautica2.SN2InGameFriendScreenViewModel",
    "/Script/Subnautica2.SN2FriendEntryViewModel",
    "/Script/Subnautica2.SN2PlayerState",
    "/Script/Subnautica2.SN2GameState"
}

local interestingPropertyKeywords = {
    "player", "session", "lobby", "party", "connection", "public", "private",
    "max", "num", "count", "capacity", "invite", "friend", "privacy", "join",
    "host", "slot", "member", "presence", "code", "online", "full", "limit",
    "text"
}

local capacityNameKeywords = {
    "max", "capacity", "limit", "numpublicconnections", "numprivateconnections",
    "publicconnections", "privateconnections", "lobbysize", "partysize",
    "memberlimit", "maxmembers", "maxmember", "maxslots", "totalslots",
    "totalplayerslots"
}

local capacityNameExclusions = {
    "current", "open", "consumed", "used", "available", "remaining", "text",
    "friendcode", "sessionid", "lobbyid"
}

local uiKeywords = {
    "WBP_MainLobbyScreen", "WBP_ClientLobbyHUD", "WBP_LoadGamePanel",
    "WBP_CreateGameScreen", "WBP_Friend", "MainLobby", "ClientLobby",
    "MultiplayerHostedSession", "HostedSession", "FriendScreen",
    "CommonTextBlock", "TextBlock", "PlayerCount", "Lobby"
}

local sessionObjectKeywords = {
    "UWEHostSessionRequest", "UWEClientSessionInfo", "UWESearchSessionResult",
    "UWEMultiplayerHostedSessionViewModel", "UWEOnlineSessionSubsystem",
    "UWELobby", "CommonSession_HostSessionRequest", "CommonSession",
    "ClientSessionInfo", "HostedSession", "SessionInfo", "Lobby",
    "FriendCode", "Invite"
}

local function object_name(obj)
    if obj == nil then return "nil" end
    if not unsafe_reflection_enabled() then return "<reflection-disabled:" .. type(obj) .. ">" end
    local full = safe(function() return obj:GetFullName() end, nil)
    if full ~= nil then return tostring(full) end
    local fname = safe(function() return obj:GetFName() end, nil)
    if fname ~= nil then
        local shortName = safe(function() return fname:ToString() end, nil)
        if shortName ~= nil then return tostring(shortName) end
    end
    return "<" .. type(obj) .. ">"
end

local function object_addr(obj)
    if not unsafe_reflection_enabled() then return "<reflection-disabled>" end
    local addr = safe(function() return obj:GetAddress() end, nil)
    if type(addr) == "number" then return string.format("0x%X", addr) end
    return "<noaddr>"
end

local function class_name(obj)
    if not unsafe_reflection_enabled() then return "<reflection-disabled>" end
    local cls = safe(function() return obj:GetClass() end, nil)
    if cls ~= nil then return object_name(cls) end
    return "<noclass>"
end

local function outer_chain(obj, maxDepth)
    if not unsafe_reflection_enabled() then return "<reflection-disabled>" end
    local out = {}
    local current = obj
    for _ = 1, maxDepth or 6 do
        local outer = safe(function() return current:GetOuter() end, nil)
        if outer == nil then break end
        out[#out + 1] = object_name(outer)
        current = outer
    end
    return table.concat(out, " <- ")
end

local function property_name(prop)
    if not unsafe_reflection_enabled() then return nil end
    local fname = safe(function() return prop:GetFName() end, nil)
    if fname ~= nil then
        local text = safe(function() return fname:ToString() end, nil)
        if text ~= nil then return tostring(text) end
    end
    local full = safe(function() return prop:GetFullName() end, nil)
    if full ~= nil then return tostring(full):match("%.([^%.]+)$") or tostring(full) end
    return nil
end

local function property_type_name(prop)
    if not unsafe_reflection_enabled() then return "<reflection-disabled>" end
    local cls = safe(function() return prop:GetClass() end, nil)
    if cls ~= nil then
        local fname = safe(function() return cls:GetFName() end, nil)
        if fname ~= nil then
            local text = safe(function() return fname:ToString() end, nil)
            if text ~= nil then return tostring(text) end
        end
        return object_name(cls)
    end
    return "<unknown property type>"
end

local function property_offset(prop)
    if not unsafe_reflection_enabled() then return "0x????" end
    local offset = safe(function() return prop:GetOffset_Internal() end, nil)
    if type(offset) == "number" then return string.format("0x%04X", offset) end
    return "0x????"
end

local function value_to_string(value, depth)
    if value == nil then return "nil" end
    local t = type(value)
    if t == "string" or t == "number" or t == "boolean" then return tostring(value) end
    if t ~= "userdata" then return "<" .. t .. ">" end
    if not unsafe_reflection_enabled() then return "<userdata reflection-disabled>" end

    local arrayNum = safe(function() return value:GetArrayNum() end, nil)
    if type(arrayNum) == "number" then
        local arrayMax = safe(function() return value:GetArrayMax() end, "?")
        local parts = { string.format("TArray num=%s max=%s", tostring(arrayNum), tostring(arrayMax)) }
        local limit = arrayNum
        if limit > 5 then limit = 5 end
        for i = 1, limit do
            local elem = safe(function() return value[i] end, nil)
            parts[#parts + 1] = string.format("[%d]=%s", i, value_to_string(elem, (depth or 0) - 1))
        end
        return table.concat(parts, " ")
    end

    local text = safe(function() return value:ToString() end, nil)
    if text ~= nil then return tostring(text) end

    local full = safe(function() return value:GetFullName() end, nil)
    if full ~= nil then return tostring(full) .. " @" .. object_addr(value) end

    local got = safe(function() return value:get() end, nil)
    if got ~= nil and depth ~= nil and depth > 0 then
        return "ref(" .. value_to_string(got, depth - 1) .. ")"
    end

    return "<userdata>"
end

local function is_capacity_property_name(name)
    local s = lower(name)
    if s == "" then return false end
    for _, ex in ipairs(capacityNameExclusions) do
        if string.find(s, ex, 1, true) then return false end
    end
    return contains_any(s, capacityNameKeywords)
end

local function should_dump_property(name, full)
    if full then return true end
    return contains_any(name, interestingPropertyKeywords)
end

local function read_property(obj, propName)
    if not unsafe_reflection_enabled() then return nil end
    return safe(function() return obj[propName] end, nil)
end

local function write_property(obj, propName, value)
    if not unsafe_reflection_enabled() then return false end
    return safe(function()
        obj[propName] = value
        return true
    end, false)
end

local function patch_named_capacity_property(obj, propName, reason)
    if obj == nil or propName == nil or not is_capacity_property_name(propName) then return false end
    local current = read_property(obj, propName)
    if type(current) ~= "number" then return false end
    local shouldPatch = current == 4
    if not shouldPatch and current == -1 and contains_any(propName, {"max", "party", "slot", "member", "capacity", "limit"}) then
        shouldPatch = true
    end
    if not shouldPatch then return false end
    local name = object_name(obj)
    append(CAPACITY_TRACE_FILE, string.format("PATCH_ATTEMPT reason=%s object=%s property=%s before=%s target=%d", reason, name, propName, tostring(current), config.MaxPlayers))
    if write_property(obj, propName, config.MaxPlayers) then
        local after = read_property(obj, propName)
        append(CAPACITY_TRACE_FILE, string.format("PATCH_RESULT reason=%s object=%s property=%s before=%s after=%s", reason, name, propName, tostring(current), tostring(after)))
        log("Info", string.format("Set capacity candidate %s.%s from %s to %s via %s", name, propName, tostring(current), tostring(after), reason))
        return true
    end
    append(CAPACITY_TRACE_FILE, string.format("PATCH_FAILED reason=%s object=%s property=%s before=%s", reason, name, propName, tostring(current)))
    return false
end

local function patch_limit_properties(obj, reason)
    if obj == nil then return 0 end
    if not unsafe_reflection_enabled() then return 0 end
    local count = 0
    for _, propName in ipairs(playerLimitProperties) do
        if patch_named_capacity_property(obj, propName, reason .. " direct") then count = count + 1 end
    end

    if not config.EnableReflectedPropertyPatch then
        if count > 0 then
            log("Info", string.format("Patched %d direct capacity-like properties via %s", count, reason))
        end
        return count
    end

    local cls = safe(function() return obj:GetClass() end, nil)
    local visited = 0
    while cls ~= nil and visited < 12 do
        visited = visited + 1
        safe(function()
            cls:ForEachProperty(function(prop)
                local pn = property_name(prop)
                if pn ~= nil and patch_named_capacity_property(obj, pn, reason .. " reflected") then
                    count = count + 1
                end
            end)
        end, nil)
        local nextCls = safe(function() return cls:GetSuperStruct() end, nil)
        if nextCls == nil or object_name(nextCls) == object_name(cls) then break end
        cls = nextCls
    end

    if count > 0 then
        log("Info", string.format("Patched %d capacity-like properties via %s", count, reason))
    end
    return count
end

local directAdmissionProperties = {
    "MaxPlayers",
    "MaxPartySize",
    "MaxSpectators",
    "MaxSplitscreens",
    "MaxPublicConnections",
    "MaxPrivateConnections",
    "TotalPlayerSlots"
}

local directSessionCapacityProperties = {
    "MaxPlayers",
    "MaxPlayer",
    "MaxPlayerCount",
    "MaxNumPlayers",
    "MaxNumberOfPlayers",
    "MaxConnections",
    "MaxPublicConnections",
    "MaxPrivateConnections",
    "NumPrivateConnections",
    "NumOpenPrivateConnections",
    "NumPublicConnections",
    "NumOpenPublicConnections",
    "MaxPartySize",
    "PartySize",
    "PlayerLimit",
    "PlayerCapacity",
    "LobbyCapacity",
    "Capacity",
    "MaxCapacity",
    "MemberLimit",
    "MaxMembers",
    "MaxMemberCount",
    "MaxLobbyMembers",
    "MaxSlots",
    "SlotCount",
    "TotalSlots",
    "TotalPlayerSlots"
}

local directSessionSweepClasses = {
    "UWEHostSessionRequest",
    "UWEClientSessionInfo",
    "UWESearchSessionResult",
    "UWEMultiplayerHostedSessionViewModel",
    "UWEOnlineSessionSubsystem",
    "UWELobbyGameState",
    "UWELobbyGameMode",
    "UWEServerLobbyComponent",
    "CommonSession_HostSessionRequest",
    "CommonSessionSubsystem",
    "SN2GameSession",
    "GameSession"
}

local function safe_object_label(obj)
    if obj == nil then return "nil" end
    local text = safe(function() return obj:ToString() end, nil)
    if text ~= nil then return tostring(text) end
    return "<" .. type(obj) .. ">"
end

local patch_direct_capacity_object

local function patch_admission_object(obj, reason)
    if obj == nil or not config.EnableJoinValidationPatch then return 0 end

    local patched = 0
    local objectLabel = safe_object_label(obj)
    for _, propName in ipairs(directAdmissionProperties) do
        local before = safe(function() return obj[propName] end, nil)
        if type(before) == "number" and before < config.MaxPlayers then
            local okSet = safe(function()
                obj[propName] = config.MaxPlayers
                return true
            end, false)
            local after = safe(function() return obj[propName] end, nil)
            append(ADMISSION_TRACE_FILE, string.format("ADMISSION_PROPERTY_PATCH reason=%s object=%s property=%s before=%s after=%s ok=%s", tostring(reason), objectLabel, propName, tostring(before), tostring(after), tostring(okSet)))
            append(CAPACITY_TRACE_FILE, string.format("ADMISSION_PROPERTY_PATCH reason=%s object=%s property=%s before=%s after=%s ok=%s", tostring(reason), objectLabel, propName, tostring(before), tostring(after), tostring(okSet)))
            if okSet then patched = patched + 1 end
        elseif before ~= nil then
            append(ADMISSION_TRACE_FILE, string.format("ADMISSION_PROPERTY_OBSERVED reason=%s object=%s property=%s value=%s", tostring(reason), objectLabel, propName, tostring(before)))
        end
    end

    if patch_direct_capacity_object ~= nil then
        patched = patched + patch_direct_capacity_object(obj, tostring(reason) .. " admission-direct")
    end

    if patched > 0 then
        log("Info", string.format("Patched admission GameSession fields on %s via %s count=%d", objectLabel, tostring(reason), patched))
    end
    return patched
end

local function should_patch_direct_capacity_property(propName, current)
    if type(current) ~= "number" then return false end
    local name = lower(propName)
    if string.find(name, "current", 1, true) or string.find(name, "used", 1, true) or
        string.find(name, "consumed", 1, true) or string.find(name, "playercount", 1, true) then
        return false
    end
    if current == 4 then return true end
    if current > 0 and current < config.MaxPlayers then return true end
    if current == -1 and (string.find(name, "max", 1, true) or string.find(name, "limit", 1, true) or
        string.find(name, "capacity", 1, true) or string.find(name, "partysize", 1, true)) then
        return true
    end
    return false
end

function patch_direct_capacity_object(obj, reason)
    if obj == nil or not config.EnableDirectSessionCapacityPatch then return 0 end

    local patched = 0
    local objectLabel = safe_object_label(obj)
    for _, propName in ipairs(directSessionCapacityProperties) do
        local before = safe(function() return obj[propName] end, nil)
        if should_patch_direct_capacity_property(propName, before) then
            local okSet = safe(function()
                obj[propName] = config.MaxPlayers
                return true
            end, false)
            local after = safe(function() return obj[propName] end, nil)
            append(SESSION_DIRECT_TRACE_FILE, string.format("DIRECT_CAPACITY_PATCH reason=%s object=%s property=%s before=%s after=%s ok=%s", tostring(reason), objectLabel, propName, tostring(before), tostring(after), tostring(okSet)))
            append(CAPACITY_TRACE_FILE, string.format("DIRECT_CAPACITY_PATCH reason=%s object=%s property=%s before=%s after=%s ok=%s", tostring(reason), objectLabel, propName, tostring(before), tostring(after), tostring(okSet)))
            if okSet then patched = patched + 1 end
        elseif before ~= nil and (before == 4 or before == -1) then
            append(SESSION_DIRECT_TRACE_FILE, string.format("DIRECT_CAPACITY_OBSERVED reason=%s object=%s property=%s value=%s", tostring(reason), objectLabel, propName, tostring(before)))
        end
    end

    if patched > 0 then
        log("Info", string.format("Patched %d direct session capacity fields on %s via %s", patched, objectLabel, tostring(reason)))
    end
    return patched
end

local function patch_direct_capacity_param(param, reason)
    if param == nil or not config.EnableDirectSessionCapacityPatch then return 0 end

    local total = 0
    if type(param) == "userdata" then
        local value = safe(function() return param:get() end, nil)
        if value ~= nil and value ~= param then
            total = total + patch_direct_capacity_object(value, reason .. " param:get")
        end
        total = total + patch_direct_capacity_object(param, reason .. " raw-param")
    elseif type(param) == "table" then
        total = total + patch_direct_capacity_object(param, reason .. " table")
    end
    return total
end

local function patch_direct_session_hook_payload(entry, phase, context, args)
    if not config.EnableDirectSessionCapacityPatch then return 0 end
    if entry == nil then return 0 end
    if entry.kind ~= "host-viewmodel" and entry.kind ~= "uwe-host" and entry.kind ~= "uwe-lobby" and
        entry.kind ~= "session" and entry.kind ~= "join" and entry.kind ~= "join-log" and
        entry.kind ~= "friend-code" and entry.kind ~= "ui-session-name" then
        return 0
    end

    local total = 0
    total = total + patch_direct_capacity_param(context, entry.path .. " " .. phase .. " context")
    for i = 1, #args do
        total = total + patch_direct_capacity_param(args[i], entry.path .. " " .. phase .. " arg" .. tostring(i))
    end
    if total > 0 then
        append(SESSION_DIRECT_TRACE_FILE, string.format("DIRECT_HOOK_PAYLOAD_PATCH path=%s phase=%s patched=%d", entry.path, phase, total))
    end
    return total
end

local function patch_direct_session_instances(reason)
    if not config.EnableDirectSessionCapacityPatch then return 0 end

    local total = 0
    for _, className in ipairs(directSessionSweepClasses) do
        local instances = safe(function() return FindAllOf(className) end, nil)
        local seen = 0
        if instances ~= nil then
            for _, obj in pairs(instances) do
                seen = seen + 1
                if seen > 16 then break end
                total = total + patch_direct_capacity_object(obj, reason .. " " .. className)
            end
        end
        append(SESSION_DIRECT_TRACE_FILE, string.format("DIRECT_SESSION_SWEEP reason=%s class=%s seen=%d patchedTotal=%d", tostring(reason), className, seen, total))
    end
    return total
end

local function patch_admission_return(path, phase, args)
    if not config.EnableAdmissionReturnPatch or not config.EnableJoinValidationPatch then return nil end
    if phase ~= "post" or args == nil or #args < 1 then return nil end

    local lowerPath = lower(path)
    if string.find(lowerPath, "atcapacity", 1, true) ~= nil then
        local ret = args[1]
        local before = safe(function() return ret:get() end, nil)
        if before == true then
            local okSet = safe(function()
                ret:set(false)
                return true
            end, false)
            local after = safe(function() return ret:get() end, nil)
            append(ADMISSION_TRACE_FILE, string.format("ADMISSION_RETURN_PATCH path=%s before=%s after=%s ok=%s", path, tostring(before), tostring(after), tostring(okSet)))
            append(CAPACITY_TRACE_FILE, string.format("ADMISSION_RETURN_PATCH path=%s before=%s after=%s ok=%s", path, tostring(before), tostring(after), tostring(okSet)))
            if okSet then
                log("Info", "Overrode GameSession AtCapacity return true -> false")
                return false
            end
        end
    end

    if string.find(lowerPath, "approvelogin", 1, true) ~= nil or string.find(lowerPath, "prelogin", 1, true) ~= nil then
        for i = 1, #args do
            local param = args[i]
            if type(param) == "userdata" then
                local before = safe(function() return param:get() end, nil)
                if type(before) == "string" and contains_any(before, { "server full", "full" }) then
                    local okSet = safe(function()
                        param:set("")
                        return true
                    end, false)
                    local after = safe(function() return param:get() end, nil)
                    append(ADMISSION_TRACE_FILE, string.format("ADMISSION_ERROR_STRING_PATCH path=%s arg=%d before=%s after=%s ok=%s", path, i, tostring(before), tostring(after), tostring(okSet)))
                    append(CAPACITY_TRACE_FILE, string.format("ADMISSION_ERROR_STRING_PATCH path=%s arg=%d before=%s after=%s ok=%s", path, i, tostring(before), tostring(after), tostring(okSet)))
                    if okSet then
                        log("Info", "Cleared admission error string containing Server full")
                        return ""
                    end
                end
            end
        end
    end

    return nil
end

local function patch_gamesession_instances(reason)
    if not config.EnableAdmissionGameSessionPatch then return 0 end

    local total = 0
    for _, className in ipairs({ "SN2GameSession", "GameSession" }) do
        local instances = safe(function() return FindAllOf(className) end, nil)
        local seen = 0
        if instances ~= nil then
            for _, obj in pairs(instances) do
                seen = seen + 1
                if seen > 8 then break end
                total = total + patch_admission_object(obj, reason .. " " .. className)
            end
        end
        append(ADMISSION_TRACE_FILE, string.format("ADMISSION_INSTANCE_SWEEP reason=%s class=%s seen=%d patchedTotal=%d", tostring(reason), className, seen, total))
    end
    return total
end

local function patch_admission_from_gamestate(gameState, reason)
    if not config.EnableAdmissionGameSessionPatch then return 0 end

    local gs = gameState
    if type(gameState) == "userdata" then
        gs = safe(function() return gameState:get() end, gameState)
    end
    local total = 0
    append(ADMISSION_TRACE_FILE, string.format("ADMISSION_GAMESTATE reason=%s gameState=%s", tostring(reason), safe_object_label(gs)))
    if gs ~= nil then
        local gm = safe(function() return gs.AuthorityGameMode end, nil)
        append(ADMISSION_TRACE_FILE, string.format("ADMISSION_AUTHORITY_GAMEMODE reason=%s gameMode=%s", tostring(reason), safe_object_label(gm)))
        if gm ~= nil then
            local session = safe(function() return gm.GameSession end, nil)
            append(ADMISSION_TRACE_FILE, string.format("ADMISSION_AUTHORITY_GAMESESSION reason=%s gameSession=%s", tostring(reason), safe_object_label(session)))
            total = total + patch_admission_object(session, reason .. " AuthorityGameMode.GameSession")
        end
    end
    total = total + patch_gamesession_instances(reason .. " instance-sweep")
    return total
end

local probedOnce = {}

local function dump_property_line(obj, prop, path, prefix)
    local pn = property_name(prop)
    if pn == nil then return end
    local ptype = property_type_name(prop)
    local value = read_property(obj, pn)
    local rendered = value_to_string(value, 1)
    append(path, string.format("%s%s %s %s = %s", prefix or "", property_offset(prop), ptype, pn, rendered))
    if type(value) == "number" and is_capacity_property_name(pn) then
        append(CAPACITY_TRACE_FILE, string.format("OBSERVED_NUMERIC_CAPACITY object=%s property=%s value=%s type=%s", object_name(obj), pn, tostring(value), ptype))
    end
end

local function probe_object_properties(obj, reason, opts)
    if obj == nil then return end
    opts = opts or {}
    local allowReflection = config.EnableFullPropertyProbe or opts.forceReflection == true
    if opts.full and not allowReflection then opts.full = false end
    local name = object_name(obj)
    local key = name .. "|" .. tostring(opts.key or reason)
    if opts.once and probedOnce[key] then return end
    if opts.once then probedOnce[key] = true end

    append(PROPERTY_FILE, "## " .. reason .. " :: " .. name .. " @" .. object_addr(obj))
    append(PROPERTY_FILE, "Class = " .. class_name(obj))
    append(PROPERTY_FILE, "Outer = " .. outer_chain(obj, 5))

    append(PROPERTY_FILE, "Direct property probes")
    for _, pn in ipairs(directProbeProperties) do
        local value = read_property(obj, pn)
        if value ~= nil then
            append(PROPERTY_FILE, string.format("  direct %s = %s", pn, value_to_string(value, 1)))
        end
    end

    if not allowReflection then
        append(PROPERTY_FILE, "Reflected property enumeration skipped; EnableFullPropertyProbe=false")
        return
    end

    local cls = safe(function() return obj:GetClass() end, nil)
    local visited = 0
    while cls ~= nil and visited < 12 do
        visited = visited + 1
        local clsName = object_name(cls)
        append(PROPERTY_FILE, "Class " .. clsName)
        local okProps = safe(function()
            cls:ForEachProperty(function(prop)
                local pn = property_name(prop)
                if pn ~= nil and should_dump_property(pn, opts.full) then
                    local okOne, errOne = pcall(function()
                        dump_property_line(obj, prop, PROPERTY_FILE, "  ")
                    end)
                    if not okOne then
                        append(PROPERTY_FILE, string.format("  %s %s = <read failed: %s>", property_offset(prop), pn, tostring(errOne)))
                    end
                end
            end)
            return true
        end, false)
        if not okProps then append(PROPERTY_FILE, "  <property enumeration failed for " .. clsName .. ">") end

        local nextCls = safe(function() return cls:GetSuperStruct() end, nil)
        if nextCls == nil or object_name(nextCls) == clsName then break end
        cls = nextCls
    end
end

local function unwrap(param)
    if param == nil then return nil end
    if type(param) == "userdata" then
        local val = safe(function() return param:get() end, nil)
        if val ~= nil then return val end
    end
    return param
end

local function set_param_if_four(param, reason)
    if param == nil or type(param) ~= "userdata" then return false end
    local val = safe(function() return param:get() end, nil)
    if type(val) == "number" and val == 4 then
        local okSet = safe(function()
            param:set(config.MaxPlayers)
            return true
        end, false)
        if okSet then
            append(CAPACITY_TRACE_FILE, string.format("PARAM_PATCH reason=%s before=4 after=%d", reason, config.MaxPlayers))
            log("Info", string.format("Changed numeric session/lobby parameter from 4 to %d at %s", config.MaxPlayers, reason))
            return true
        end
    end
    return false
end

local function trace_param(path, label, param)
    if not config.EnableUnsafeObjectReflection then
        local rawType = type(param)
        local remoteType = rawType
        local gotType = "<not-probed>"
        local rendered = "<not-probed>"
        if config.EnableSafeParamProbe and rawType == "userdata" then
            remoteType = safe(function() return param:type() end, rawType)
            local value = safe(function() return param:get() end, nil)
            gotType = type(value)
            if gotType == "number" or gotType == "boolean" or gotType == "string" then
                rendered = tostring(value)
                append(CAPACITY_TRACE_FILE, string.format("SAFE_PARAM_VALUE path=%s label=%s type=%s value=%s", path, label, gotType, rendered))
                if config.EnableSafeNumericParamPatch and gotType == "number" and value == 4 then
                    local okSet = safe(function()
                        param:set(config.MaxPlayers)
                        return true
                    end, false)
                    local after = safe(function() return param:get() end, nil)
                    append(CAPACITY_TRACE_FILE, string.format("SAFE_NUMERIC_PARAM_PATCH path=%s label=%s before=4 ok=%s after=%s", path, label, tostring(okSet), tostring(after)))
                end
            elseif gotType == "userdata" then
                rendered = "<userdata>"
            elseif value == nil then
                rendered = "nil"
            else
                rendered = "<" .. gotType .. ">"
            end
        end
        append(HOST_TRACE_FILE, string.format("%s %s rawType=%s remoteType=%s getType=%s value=%s reflection=disabled", path, label, rawType, tostring(remoteType), gotType, rendered))
        return
    end

    local rawType = type(param)
    local remoteType = rawType
    if rawType == "userdata" then remoteType = safe(function() return param:type() end, rawType) end
    local value = unwrap(param)
    local line = string.format("%s %s rawType=%s remoteType=%s valueType=%s raw=%s value=%s",
        path, label, rawType, tostring(remoteType), type(value), value_to_string(param, 1), value_to_string(value, 1))
    append(HOST_TRACE_FILE, line)

    set_param_if_four(param, path .. " " .. label)
    if type(value) == "userdata" then
        append(HOST_TRACE_FILE, string.format("%s %s object=%s class=%s outer=%s", path, label, object_name(value), class_name(value), outer_chain(value, 4)))
        patch_limit_properties(value, path .. " " .. label)
        probe_object_properties(value, path .. " " .. label, { full = false })
    elseif type(value) == "number" then
        append(CAPACITY_TRACE_FILE, string.format("OBSERVED_NUMERIC_ARG path=%s %s value=%s", path, label, tostring(value)))
    end
end

local function find_and_probe_instances(shortClassName, reason, opts)
    if not unsafe_reflection_enabled() then
        append(PROPERTY_FILE, string.format("FindAllOf(%s) skipped for %s; EnableUnsafeObjectReflection=false", shortClassName, reason))
        return 0
    end
    opts = opts or {}
    local maxCount = opts.maxCount or 16
    local instances = safe(function() return FindAllOf(shortClassName) end, nil)
    if instances == nil then
        append(PROPERTY_FILE, string.format("FindAllOf(%s) no instances for %s", shortClassName, reason))
        return 0
    end

    local count = 0
    for _, obj in pairs(instances) do
        count = count + 1
        if count > maxCount then break end
        append(CAPACITY_TRACE_FILE, string.format("INSTANCE_SWEEP reason=%s class=%s object=%s addr=%s", reason, shortClassName, object_name(obj), object_addr(obj)))
        patch_limit_properties(obj, "instance sweep " .. reason .. " " .. shortClassName)
        probe_object_properties(obj, "instance sweep " .. reason .. " " .. shortClassName, { full = opts.full == true, once = opts.once == true, key = reason .. shortClassName })
    end
    return count
end

local function sweep_session_objects(reason, full)
    local classes = {
        "UWEHostSessionRequest",
        "UWEClientSessionInfo",
        "UWESearchSessionResult",
        "UWEMultiplayerHostedSessionViewModel",
        "UWEOnlineSessionSubsystem",
        "UWELobbyGameState",
        "UWELobbyGameMode",
        "UWEServerLobbyComponent",
        "CommonSession_HostSessionRequest",
        "CommonSessionSubsystem",
        "SN2InGameFriendScreenViewModel",
        "SN2FriendScreenViewModel",
        "SN2GameSession",
        "GameSession"
    }
    append(CAPACITY_TRACE_FILE, "SESSION_SWEEP_START reason=" .. reason)
    for _, className in ipairs(classes) do
        find_and_probe_instances(className, reason, { full = full == true, maxCount = 12 })
    end
    append(CAPACITY_TRACE_FILE, "SESSION_SWEEP_END reason=" .. reason)
end

local function find_ufunction(path)
    local obj = safe(function() return StaticFindObject(path) end, nil)
    if obj ~= nil then return obj end

    local classPath, funcName = path:match("^(.*):([^:]+)$")
    if classPath == nil then return nil end
    if not unsafe_reflection_enabled() then return nil end
    local cls = safe(function() return StaticFindObject(classPath) end, nil)
    if cls == nil then return nil end
    local found = nil
    safe(function()
        cls:ForEachFunction(function(fn)
            local n = property_name(fn)
            if n == funcName then
                found = fn
                return true
            end
        end)
    end, nil)
    return found
end

local dumpedSignatures = {}

local function dump_ufunction_object_signature(fn, path)
    if fn == nil or dumpedSignatures[path] then return end
    dumpedSignatures[path] = true
    append(SIGNATURE_FILE, "## " .. path)
    if not unsafe_reflection_enabled() then
        append(SIGNATURE_FILE, "  <signature enumeration skipped; EnableUnsafeObjectReflection=false>")
        return
    end
    append(SIGNATURE_FILE, "  object=" .. object_name(fn) .. " @" .. object_addr(fn))
    local flags = safe(function() return fn:GetFunctionFlags() end, nil)
    if flags ~= nil then append(SIGNATURE_FILE, "  flags=" .. tostring(flags)) end
    safe(function()
        fn:ForEachProperty(function(prop)
            append(SIGNATURE_FILE, string.format("  %s %s %s", property_offset(prop), property_type_name(prop), tostring(property_name(prop))))
        end)
    end, nil)
end

local function dump_function_signature(path)
    if dumpedSignatures[path] then return end
    local fn = find_ufunction(path)
    if fn == nil then
        dumpedSignatures[path] = true
        append(SIGNATURE_FILE, "## " .. path)
        append(SIGNATURE_FILE, "  <function not found>")
        return
    end
    dump_ufunction_object_signature(fn, path)
end

local hookPaths = {
    { path = "/Script/Engine.GameSession:AtCapacity", kind = "join" },
    { path = "/Script/Engine.GameModeBase:PreLogin", kind = "join-log" },
    { path = "/Script/Engine.GameModeBase:PostLogin", kind = "join-log" },
    { path = "/Script/Engine.GameMode:PostLogin", kind = "join-log" },
    { path = "/Script/Engine.GameSession:RegisterPlayer", kind = "join-log" },
    { path = "/Script/Engine.GameSession:ApproveLogin", kind = "join" },
    { path = "/Script/OnlineSubsystemUtils.CreateSessionCallbackProxy:CreateSession", kind = "session" },
    { path = "/Script/CommonUser.CommonSessionSubsystem:HostSession", kind = "session" },
    { path = "/Script/CommonUser.CommonSessionSubsystem:CreateOnlineSessionInternal", kind = "session" },
    { path = "/Script/CommonUser.CommonSessionSubsystem:JoinSession", kind = "join-log" },
    { path = "/Script/UWESonar.UWEMultiplayerHostedSessionViewModel:TriggerHostGameRequest", kind = "host-viewmodel" },
    { path = "/Script/UWESonar.UWEOnlineSessionSubsystem:HostSessionAsync", kind = "uwe-host" },
    { path = "/Script/UWELobby.UWELobbyGameMode:StartNewServerGame", kind = "uwe-lobby" },
    { path = "/Script/UWELobby.UWEServerLobbyComponent:StartNewGame", kind = "uwe-lobby" },
    { path = "/Script/UWELobby.UWEServerLobbyComponent:LoadGame", kind = "uwe-lobby" },
    { path = "/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString", kind = "ui-playercount" },
    { path = "/Script/Subnautica2.SN2InGameFriendScreenViewModel:GetCurrentSessionName", kind = "ui-session-name" },
    { path = "/Script/Subnautica2.SN2FriendScreenViewModel:InitFriendCode", kind = "friend-code", optional = true },
    { path = "/Script/Subnautica2.SN2FriendScreenViewModel:RequestFriendCode", kind = "friend-code" },
    { path = "/Script/Subnautica2.SN2FriendScreenViewModel:OnFriendCodeReturned", kind = "friend-code", optional = true },
    { path = "/Game/Blueprints/UI/Friends/WBP_InGameFriends.WBP_InGameFriends_C:ShowFriendCodeFeedbackMessage", kind = "ui-session-name", optional = true },
    { path = "/Script/UMG.TextBlock:SetText", kind = "ui-text", uiTrace = true },
    { path = "/Script/UMG.TextBlock:GetText", kind = "ui-text", uiTrace = true },
    { path = "/Script/CommonUI.CommonTextBlock:SetText", kind = "ui-text", uiTrace = true },
    { path = "/Script/CommonUI.CommonTextBlock:GetText", kind = "ui-text", uiTrace = true }
}

local registered = {}
local unavailableHooks = {}

local hookProfiles = {
    None = {},
    UIOnly = {
        ["ui-text"] = true,
        ["ui-playercount"] = true,
    },
    UIFriendCount = {
        ["friend-code"] = true,
        ["ui-session-name"] = true,
        ["ui-playercount"] = true,
    },
    TriggerOnly = {
        ["host-viewmodel"] = true,
    },
    HostAsyncOnly = {
        ["uwe-host"] = true,
    },
    HostOnly = {
        ["host-viewmodel"] = true,
        ["uwe-host"] = true,
    },
    LobbyHost = {
        ["host-viewmodel"] = true,
        ["uwe-host"] = true,
        ["uwe-lobby"] = true,
        ["friend-code"] = true,
    },
    Session = {
        ["host-viewmodel"] = true,
        ["uwe-host"] = true,
        ["uwe-lobby"] = true,
        ["session"] = true,
        ["friend-code"] = true,
    },
    Production = {
        ["host-viewmodel"] = true,
        ["uwe-host"] = true,
        ["uwe-lobby"] = true,
        ["session"] = true,
        ["join"] = true,
        ["join-log"] = true,
        ["friend-code"] = true,
        ["ui-session-name"] = true,
        ["ui-playercount"] = true,
    },
    ProductionLean = {
        ["join"] = true,
        ["ui-playercount"] = true,
    },
    All = {
        ["host-viewmodel"] = true,
        ["uwe-host"] = true,
        ["uwe-lobby"] = true,
        ["session"] = true,
        ["join"] = true,
        ["join-log"] = true,
        ["friend-code"] = true,
        ["ui-session-name"] = true,
        ["ui-playercount"] = true,
        ["ui-text"] = true,
        ["dynamic"] = true,
    }
}

local function current_hook_profile()
    return hookProfiles[config.HookProfile] or hookProfiles.None
end

local function hook_allowed(entry)
    if not config.EnableHooks then return false end
    if entry.uiTrace == true and not config.EnableUITraceHooks and not config.EnableUIPatch then return false end
    local profile = current_hook_profile()
    return profile[entry.kind] == true
end

local function is_target_event_kind(kind)
    return kind == "host-viewmodel" or kind == "uwe-host" or kind == "uwe-lobby" or
        kind == "friend-code" or kind == "ui-session-name" or kind == "ui-playercount" or
        kind == "session" or kind == "dynamic"
end

local function trace_ui_text_event(path, phase, context, ...)
    local obj = unwrap(context)
    local args = {...}
    if phase == "pre" and string.find(path, ":SetText", 1, true) ~= nil and #args > 0 then
        patch_ui_text_param(path, phase, args[1])
    end

    local text = ""
    if #args > 0 then
        text = text_param_to_string(args[1]) or value_to_string(unwrap(args[1]), 1)
    end
    local objName = object_name(obj)
    local relevant = contains_any(objName, uiKeywords) or string.find(text, "/", 1, true) ~= nil or string.find(text, "4", 1, true) ~= nil
    if not relevant then return end
    append(UI_TRACE_FILE, string.format("%s %s object=%s class=%s text=%s outer=%s", path, phase, objName, class_name(obj), text, outer_chain(obj, 6)))
    if string.find(text, "/4", 1, true) ~= nil or string.find(text, "1/4", 1, true) ~= nil then
        append(CAPACITY_TRACE_FILE, string.format("UI_1_OF_4_SOURCE path=%s phase=%s object=%s text=%s outer=%s", path, phase, objName, text, outer_chain(obj, 8)))
        log("Warn", "Observed UI text still containing /4 at " .. objName)
        probe_object_properties(obj, "UI text /4 source " .. path, { full = true })
    end
end

local function trace_hook_event(entry, phase, context, ...)
    if entry.kind == "ui-text" then
        trace_ui_text_event(entry.path, phase, context, ...)
        return
    end

    local args = {...}
    patch_direct_session_hook_payload(entry, phase, context, args)
    local uiOverride = patch_playercount_return(entry.path, phase, args)
    local admissionOverride = patch_admission_return(entry.path, phase, args)
    if admissionOverride ~= nil then
        return admissionOverride
    end
    if config.EnableTargetedUIPatch and config.EnableTargetedUISweeps and
        (entry.kind == "friend-code" or entry.kind == "ui-session-name" or entry.kind == "ui-playercount") then
        schedule_targeted_ui_patch(entry.path .. " " .. phase)
    end

    if not config.EnableUnsafeObjectReflection then
        if should_trace_low_noise_event(entry, phase) then
            append(HOST_TRACE_FILE, string.format("## %s %s rawContextType=%s argCount=%d reflection=disabled", entry.path, phase, type(context), #args))
            log("Info", "Observed " .. phase .. " event without UObject reflection: " .. entry.path)
            for i = 1, #args do
                trace_param(entry.path, phase .. " arg" .. tostring(i), args[i])
            end
        end
        return uiOverride
    end

    local obj = unwrap(context)
    append(HOST_TRACE_FILE, string.format("## %s %s context=%s class=%s outer=%s", entry.path, phase, object_name(obj), class_name(obj), outer_chain(obj, 5)))
    log("Info", "Observed " .. phase .. " event: " .. entry.path)
    if obj ~= nil then
        patch_limit_properties(obj, entry.path .. " " .. phase .. " context")
        if is_target_event_kind(entry.kind) then
            probe_object_properties(obj, entry.path .. " " .. phase .. " context", { full = true })
        end
    end

    for i = 1, #args do
        trace_param(entry.path, phase .. " arg" .. tostring(i), args[i])
    end

    if config.EnableHostTriggeredSessionSweep and
        (entry.kind == "uwe-host" or entry.kind == "host-viewmodel" or entry.kind == "uwe-lobby" or entry.kind == "friend-code") then
        local sweepReason = entry.path .. " " .. phase
        schedule_game_thread_delay(100, sweepReason .. " +100ms", function()
            sweep_session_objects(sweepReason .. " +100ms", false)
        end)
        schedule_game_thread_delay(1000, sweepReason .. " +1000ms", function()
            sweep_session_objects(sweepReason .. " +1000ms", false)
        end)
        schedule_game_thread_delay(3000, sweepReason .. " +3000ms", function()
            sweep_session_objects(sweepReason .. " +3000ms", false)
        end)
    end

    if entry.kind == "join-log" then
        append(CAPACITY_TRACE_FILE, "JOIN_EVENT " .. entry.path .. " " .. phase)
    end
    return uiOverride
end

local function register_candidate_hook(entry)
    if registered[entry.path] then return end
    if unavailableHooks[entry.path] then return end
    if not hook_allowed(entry) then return end
    log("Debug", "Attempting hook " .. entry.path)
    local preCallback = retain_callback("hook pre " .. entry.path, function(context, ...)
        return trace_hook_event(entry, "pre", context, ...)
    end)
    local postCallback = retain_callback("hook post " .. entry.path, function(context, ...)
        return trace_hook_event(entry, "post", context, ...)
    end)
    local ok, preId, postId = pcall(function()
        return RegisterHook(entry.path, preCallback, postCallback)
    end)
    if ok then
        registered[entry.path] = true
        log("Info", string.format("Registered hook %s pre=%s post=%s", entry.path, tostring(preId), tostring(postId)))
    else
        if not config.RetryUnavailableHooks then
            unavailableHooks[entry.path] = true
        end
        log("Debug", "Hook unavailable now: " .. entry.path)
    end
end

local function register_hooks()
    if not config.EnableHooks then
        log("Info", "Runtime hook registration disabled by EnableHooks=false")
        return
    end
    for _, entry in ipairs(hookPaths) do
        register_candidate_hook(entry)
    end
    log("Info", "Hook registration pass complete profile=" .. tostring(config.HookProfile))
end

local function retry_join_hooks(reason)
    local retried = 0
    for _, entry in ipairs(hookPaths) do
        if entry.kind == "join" or entry.kind == "join-log" then
            unavailableHooks[entry.path] = nil
            register_candidate_hook(entry)
            retried = retried + 1
        end
    end
    append(CAPACITY_TRACE_FILE, string.format("JOIN_HOOK_RETRY reason=%s retried=%d", tostring(reason), retried))
end

local function short_class_path(classPath)
    return (classPath:match("%.([^%.]+)$") or classPath:match("/([^/]+)$") or classPath)
end

local dynamicHookCount = 0
local dynamicHookLimit = 80
local dynamicFunctionKeywords = {
    "host", "create", "update", "join", "lobby", "session", "full", "capacity",
    "member", "invite", "friendcode", "playercount", "maxplayer", "canjoin"
}

local function discover_and_hook_class_functions(classPath)
    if not unsafe_reflection_enabled() then
        append(SIGNATURE_FILE, "Function discovery skipped for " .. classPath .. "; EnableUnsafeObjectReflection=false")
        return
    end
    local cls = safe(function() return StaticFindObject(classPath) end, nil)
    if cls == nil then
        append(SIGNATURE_FILE, "Class not found for function discovery: " .. classPath)
        return
    end
    append(SIGNATURE_FILE, "## Function discovery for " .. classPath .. " object=" .. object_name(cls))
    local shortPath = classPath
    safe(function()
        cls:ForEachFunction(function(fn)
            local fnName = property_name(fn)
            if fnName ~= nil and contains_any(fnName, dynamicFunctionKeywords) then
                local hookPath = shortPath .. ":" .. fnName
                append(SIGNATURE_FILE, "  candidate " .. hookPath)
                dump_ufunction_object_signature(fn, hookPath)
                if config.EnableDynamicDiscoveryHooks and dynamicHookCount < dynamicHookLimit and not registered[hookPath] then
                    dynamicHookCount = dynamicHookCount + 1
                    register_candidate_hook({ path = hookPath, kind = "dynamic" })
                end
            end
        end)
    end, nil)
end

local function probe_cdo(classPath)
    if not unsafe_reflection_enabled() then
        append(PROPERTY_FILE, "CDO probe skipped for " .. classPath .. "; EnableUnsafeObjectReflection=false")
        return
    end
    local cls = safe(function() return StaticFindObject(classPath) end, nil)
    if cls == nil then return end
    local cdo = safe(function() return cls:GetCDO() end, nil)
    if cdo ~= nil then
        probe_object_properties(cdo, "CDO " .. classPath, { full = true, once = true, key = "CDO" })
        patch_limit_properties(cdo, "CDO " .. classPath)
    end
end

local function probe_ui_object(obj, reason)
    if obj == nil then return end
    local name = object_name(obj)
    if not contains_any(name, uiKeywords) then return end
    append(UI_TRACE_FILE, "## " .. reason .. " :: " .. name .. " class=" .. class_name(obj) .. " outer=" .. outer_chain(obj, 8))
    for _, pn in ipairs(directProbeProperties) do
        local value = read_property(obj, pn)
        if value ~= nil then
            local rendered = value_to_string(value, 1)
            append(UI_TRACE_FILE, string.format("  %s = %s", pn, rendered))
            if string.find(rendered, "/4", 1, true) ~= nil then
                append(CAPACITY_TRACE_FILE, string.format("UI_DIRECT_PROPERTY_1_OF_4 object=%s property=%s value=%s", name, pn, rendered))
                probe_object_properties(obj, "UI direct /4 " .. reason, { full = true })
            end
        end
    end
end

local function install_object_watchers()
    if not unsafe_reflection_enabled() then
        log("Warn", "Object construction watchers skipped; EnableUnsafeObjectReflection=false")
        return
    end

    pcall(function()
        NotifyOnNewObject("/Script/Engine.GameSession", retain_callback("NotifyOnNewObject Engine.GameSession", function(obj)
            log("Info", "GameSession constructed")
            patch_limit_properties(obj, "GameSession construction auxiliary")
            probe_object_properties(obj, "GameSession construction auxiliary", { full = false, once = true, key = "gamesession" })
        end))
    end)

    pcall(function()
        NotifyOnNewObject("/Script/Engine.GameModeBase", retain_callback("NotifyOnNewObject Engine.GameModeBase", function(obj)
            log("Info", "GameModeBase constructed")
            patch_limit_properties(obj, "GameModeBase construction auxiliary")
            pcall(function()
                if obj.GameSession ~= nil then patch_limit_properties(obj.GameSession, "GameModeBase.GameSession auxiliary") end
            end)
        end))
    end)

    pcall(function()
        NotifyOnNewObject("/Script/UMG.TextBlock", retain_callback("NotifyOnNewObject UMG.TextBlock", function(obj)
            probe_ui_object(obj, "new TextBlock")
        end))
    end)

    pcall(function()
        NotifyOnNewObject("/Script/CommonUI.CommonTextBlock", retain_callback("NotifyOnNewObject CommonUI.CommonTextBlock", function(obj)
            probe_ui_object(obj, "new CommonTextBlock")
        end))
    end)

    pcall(function()
        NotifyOnNewObject("/Script/UMG.UserWidget", retain_callback("NotifyOnNewObject UMG.UserWidget", function(obj)
            probe_ui_object(obj, "new UserWidget")
        end))
    end)

    for _, className in ipairs(targetClasses) do
        pcall(function()
            NotifyOnNewObject(className, retain_callback("NotifyOnNewObject " .. className, function(obj)
                log("Info", "Target object constructed: " .. className)
                append(CAPACITY_TRACE_FILE, "TARGET_OBJECT " .. className .. " object=" .. object_name(obj) .. " addr=" .. object_addr(obj))
                patch_limit_properties(obj, "target object " .. className)
                probe_object_properties(obj, "new object " .. className, { full = true })
            end))
        end)
    end
end

local function discover_loaded_objects(reason, maxMatches)
    if not config.EnableDiscoveryScan then return end
    if not unsafe_reflection_enabled() then
        append(DISCOVERY_FILE, "Discovery scan skipped reason=" .. reason .. "; EnableUnsafeObjectReflection=false")
        log("Warn", "Discovery scan skipped because EnableUnsafeObjectReflection=false")
        return
    end
    maxMatches = maxMatches or 3000
    append(DISCOVERY_FILE, "Discovery scan start reason=" .. reason)
    local matches = 0
    local sessionMatches = 0
    local uiMatches = 0
    local ok = pcall(function()
        ForEachUObject(function(obj)
            if matches >= maxMatches then return true end
            local name = object_name(obj)
            local isSession = contains_any(name, sessionObjectKeywords)
            local isUi = contains_any(name, uiKeywords)
            if isSession or isUi then
                matches = matches + 1
                append(DISCOVERY_FILE, string.format("%s session=%s ui=%s class=%s", name, bool_text(isSession), bool_text(isUi), class_name(obj)))
                if isSession then
                    sessionMatches = sessionMatches + 1
                    patch_limit_properties(obj, "discovery scan " .. reason)
                    probe_object_properties(obj, "discovery scan session " .. reason, { full = false, once = true, key = "scan-session" })
                end
                if isUi then
                    uiMatches = uiMatches + 1
                    probe_ui_object(obj, "discovery scan " .. reason)
                end
            end
        end)
    end)
    log(ok and "Info" or "Warn", string.format("Discovery scan %s finished matches=%d session=%d ui=%d", reason, matches, sessionMatches, uiMatches))
end

local function log_game_hash()
    local exe = ROOT .. "\\..\\..\\..\\Subnautica2-Win64-Shipping.exe"
    local escapedExe = string.gsub(exe, "'", "''")
    local cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command " .. string.char(34) ..
        "$p = '" .. escapedExe .. "'; (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash" ..
        string.char(34)
    local pipe = io.popen(cmd)
    local hash = nil
    if pipe then
        hash = pipe:read("*l")
        pipe:close()
    end
    if hash ~= nil and hash ~= "" then
        log("Info", "Shipping EXE SHA256=" .. tostring(hash))
        if config.KnownGameExeSha256 ~= "" and lower(hash) ~= lower(config.KnownGameExeSha256) then
            log("Warn", "KnownGameExeSha256 mismatch; Lua reflection diagnostics remain enabled, native patching must stay disabled")
        end
    else
        log("Warn", "Could not compute shipping EXE SHA256 from " .. exe)
    end
end

local function load_native_patch()
    if not config.EnableNativeEOSCapacityPatch then
        log("Info", "Native EOS capacity patch disabled by EnableNativeEOSCapacityPatch=false")
        return
    end

    local dllPath = ROOT .. "\\native\\MorePlayers8Native.dll"
    local loader, err = package.loadlib(dllPath, "MorePlayers8_InstallHooks")
    if loader == nil then
        log("Error", "Failed to load native EOS capacity patch DLL: " .. tostring(err))
        return
    end

    local ok, rc = pcall(loader, ROOT)
    if not ok then
        log("Error", "Native EOS capacity patch entry threw Lua error: " .. tostring(rc))
        return
    end
    log("Info", "Native EOS capacity patch entry called; see Logs\\native_eos_patch.log for install status")
end

    log("Info", string.format("Loaded version=%s MaxPlayers=%d lobby=%s session=%s join=%s",
    MOD_VERSION,
    config.MaxPlayers,
    tostring(config.EnableLobbyPatch),
    tostring(config.EnableSessionPatch),
    tostring(config.EnableJoinValidationPatch)))
log("Info", string.format("Hook controls: EnableHooks=%s HookProfile=%s EnableDelayedTasks=%s RetryUnavailableHooks=%s EnableUnsafeObjectReflection=%s EnableUIPatch=%s EnableSafeParamProbe=%s EnableSafeNumericParamPatch=%s EnableDynamicDiscoveryHooks=%s retainedCallbacks=%d",
    tostring(config.EnableHooks),
    tostring(config.HookProfile),
    tostring(config.EnableDelayedTasks),
    tostring(config.RetryUnavailableHooks),
    tostring(config.EnableUnsafeObjectReflection),
    tostring(config.EnableUIPatch),
    tostring(config.EnableSafeParamProbe),
    tostring(config.EnableSafeNumericParamPatch),
    tostring(config.EnableDynamicDiscoveryHooks),
    #retainedCallbacks))
log("Info", string.format("Admission patch controls: EnableAdmissionGameSessionPatch=%s AdmissionPatchIntervalMs=%d",
    tostring(config.EnableAdmissionGameSessionPatch),
    config.AdmissionPatchIntervalMs or 0))
log("Info", string.format("Direct session patch controls: EnableDirectSessionCapacityPatch=%s DirectSessionPatchIntervalMs=%d EnableAdmissionReturnPatch=%s",
    tostring(config.EnableDirectSessionCapacityPatch),
    config.DirectSessionPatchIntervalMs or 0,
    tostring(config.EnableAdmissionReturnPatch)))
log("Info", string.format("Targeted UI patch controls: EnableTargetedUIPatch=%s EnableTargetedUISweeps=%s EnableTargetedUIAllTextSweep=%s",
    tostring(config.EnableTargetedUIPatch),
    tostring(config.EnableTargetedUISweeps),
    tostring(config.EnableTargetedUIAllTextSweep)))

log_game_hash()
load_native_patch()
register_hooks()
schedule_game_thread_delay(15000, "join-hook-retry-15s", function()
    retry_join_hooks("startup+15s")
end)
schedule_game_thread_delay(45000, "join-hook-retry-45s", function()
    retry_join_hooks("startup+45s")
end)
schedule_game_thread_delay(90000, "join-hook-retry-90s", function()
    retry_join_hooks("startup+90s")
end)
if config.EnableTargetedUIPatch and config.EnableTargetedUISweeps then
    schedule_game_thread_delay(10000, "startup-10s targeted-ui", function()
        register_hooks()
        run_targeted_ui_patch("startup-10s")
    end)
    schedule_game_thread_delay(20000, "startup-20s targeted-ui", function()
        register_hooks()
        run_targeted_ui_patch("startup-20s")
    end)
    schedule_game_thread_delay(35000, "startup-35s targeted-ui", function()
        register_hooks()
        run_targeted_ui_patch("startup-35s")
    end)
    schedule_game_thread_delay(60000, "startup-60s targeted-ui", function()
        register_hooks()
        run_targeted_ui_patch("startup-60s")
    end)
elseif config.EnableTargetedUIPatch then
    log("Info", "Targeted UI sweeps disabled; using ViewModel return patch only")
end
if config.EnableObjectWatchers then
    log("Warn", "EnableObjectWatchers=true; StaticConstructObject callbacks may crash this UE4SS/game build")
    install_object_watchers()
else
    log("Info", "Object construction watchers disabled for stability; session objects will be swept from game-thread hooks")
end

if config.EnableInitGameStateTrace or config.EnableAdmissionGameSessionPatch then
    pcall(function()
        RegisterInitGameStatePostHook(retain_callback("InitGameStatePostHook", function(gameState)
            local gs = unwrap(gameState)
            log("Info", "InitGameState observed")
            patch_admission_from_gamestate(gs, "InitGameStatePostHook")
            if config.EnableInitGameStateTrace and gs ~= nil then
                probe_object_properties(gs, "InitGameState GameState", { full = false, once = true, key = "init-gs" })
                pcall(function()
                    local gm = gs.AuthorityGameMode
                    if gm ~= nil then
                        patch_limit_properties(gm, "InitGameState AuthorityGameMode auxiliary")
                        probe_object_properties(gm, "InitGameState AuthorityGameMode", { full = false, once = true, key = "init-gm" })
                        if gm.GameSession ~= nil then
                            patch_limit_properties(gm.GameSession, "InitGameState GameSession auxiliary")
                            probe_object_properties(gm.GameSession, "InitGameState GameSession", { full = false, once = true, key = "init-gamesession" })
                        end
                    end
                end)
            end
        end))
    end)
else
    log("Info", "InitGameState trace disabled for stability")
end

if config.EnableAdmissionGameSessionPatch then
    schedule_game_thread_delay(1000, "admission-patch-1s", function()
        patch_gamesession_instances("startup+1s")
    end)
    schedule_game_thread_delay(10000, "admission-patch-10s", function()
        patch_gamesession_instances("startup+10s")
    end)
    schedule_game_thread_delay(30000, "admission-patch-30s", function()
        patch_gamesession_instances("startup+30s")
    end)
    if type(LoopInGameThreadWithDelay) == "function" then
        local interval = config.AdmissionPatchIntervalMs or 5000
        if interval < 1000 then interval = 1000 end
        LoopInGameThreadWithDelay(interval, retain_callback("admission patch loop", function()
            patch_gamesession_instances("loop")
        end))
        log("Info", "Admission GameSession patch loop enabled")
    else
        log("Warn", "LoopInGameThreadWithDelay unavailable; admission GameSession patch will run only at scheduled startup points")
    end
else
    log("Info", "Admission GameSession patch disabled")
end

if config.EnableDirectSessionCapacityPatch then
    schedule_game_thread_delay(1500, "direct-session-patch-1.5s", function()
        patch_direct_session_instances("startup+1.5s")
    end)
    schedule_game_thread_delay(12000, "direct-session-patch-12s", function()
        patch_direct_session_instances("startup+12s")
    end)
    schedule_game_thread_delay(30000, "direct-session-patch-30s", function()
        patch_direct_session_instances("startup+30s")
    end)
    if type(LoopInGameThreadWithDelay) == "function" then
        local interval = config.DirectSessionPatchIntervalMs or 10000
        if interval < 2000 then interval = 2000 end
        LoopInGameThreadWithDelay(interval, retain_callback("direct session capacity patch loop", function()
            patch_direct_session_instances("loop")
        end))
        log("Info", "Direct session capacity patch loop enabled")
    else
        log("Warn", "LoopInGameThreadWithDelay unavailable; direct session patch will run only at scheduled startup points")
    end
else
    log("Info", "Direct session capacity patch disabled")
end

if config.EnableDelayedTasks then
    schedule_game_thread_delay(5000, "startup-5s", function()
        register_hooks()
        if config.EnableClassDiscovery then
            for _, className in ipairs(targetClasses) do
                probe_cdo(className)
                discover_and_hook_class_functions(className)
            end
        end
        discover_loaded_objects("startup-5s", 3000)
        if config.EnableObjectDumpOnStartup then
            log("Warn", "DumpAllObjects requested by config; this may create a large UE4SS_ObjectDump.txt file")
            pcall(function() DumpAllObjects() end)
        end
    end)

    schedule_game_thread_delay(20000, "delayed-20s", function()
        register_hooks()
        if config.EnableDelayedSessionSweep and config.EnableUISweep then
            sweep_session_objects("delayed-20s", false)
        end
        discover_loaded_objects("delayed-20s", 3000)
    end)

    schedule_game_thread_delay(45000, "delayed-45s", function()
        register_hooks()
        if config.EnableDelayedSessionSweep and config.EnableUISweep then
            sweep_session_objects("delayed-45s", false)
        end
        discover_loaded_objects("delayed-45s", 3000)
    end)
else
    log("Info", "Delayed diagnostic tasks disabled for stability baseline")
end
