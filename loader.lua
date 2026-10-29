-- ═════════════════════════════════════════════════════════════
-- 🚀 HAMA UNIVERSAL LOADER V2.5
-- ═════════════════════════════════════════════════════════════

local CONFIG = {
    MainScriptURL = "https://raw.githubusercontent.com/dafaremixeruhy-ctr/hama-universal/main/main.lua",
    WhitelistURL  = "https://raw.githubusercontent.com/dafaremixeruhy-ctr/hama-universal/main/whitelist.txt",
    VersionURL    = "https://raw.githubusercontent.com/dafaremixeruhy-ctr/hama-universal/main/version.txt",
    BypassCache   = true,
}

local Player = game:GetService("Players").LocalPlayer

-- =============================================
-- CEK WHITELIST
-- =============================================
local function CheckWhitelist()
    local success, result = pcall(function()
        return game:HttpGet(CONFIG.WhitelistURL .. "?t=" .. tick(), CONFIG.BypassCache)
    end)
    if not success or not result or result == "" then
        warn("[HAMA] Gagal ambil whitelist dari GitHub!")
        return false
    end
    for line in result:gmatch("[^\r\n]+") do
        local name = line:gsub("%s+", "")
        if name ~= "" and name:lower() == Player.Name:lower() then
            return true
        end
    end
    return false
end

-- =============================================
-- CEK VERSI
-- =============================================
local function CheckVersion()
    local success, result = pcall(function()
        return game:HttpGet(CONFIG.VersionURL .. "?t=" .. tick(), CONFIG.BypassCache)
    end)
    if success and result then
        print("[HAMA] Versi terbaru di GitHub: " .. result:gsub("%s+", ""))
    end
end

-- =============================================
-- LOAD MAIN SCRIPT
-- =============================================
local function LoadMainScript()
    print("[HAMA] Downloading main script...")
    local success, result = pcall(function()
        return game:HttpGet(CONFIG.MainScriptURL .. "?t=" .. tick(), CONFIG.BypassCache)
    end)
    if not success or not result then
        warn("[HAMA] Gagal download script dari GitHub!")
        return false
    end
    print("[HAMA] Script downloaded (" .. #result .. " bytes)")
    
    local loadSuccess, loadErr = pcall(function()
        loadstring(result)()
    end)
    if not loadSuccess then
        warn("[HAMA] Gagal load script: " .. tostring(loadErr))
        return false
    end
    print("[HAMA] Script loaded successfully!")
    return true
end

-- =============================================
-- MAIN
-- =============================================
print("═══════════════════════════════════════")
print("  🚀 HAMA UNIVERSAL LOADER V2.5")
print("═══════════════════════════════════════")

CheckVersion()

if not CheckWhitelist() then
    warn("[HAMA] ❌ Kamu tidak ada di whitelist!")
    warn("[HAMA] Hubungi @dpnvhr untuk akses.")
    game:GetService("Players").LocalPlayer:Kick("❌ You are not whitelisted!\nContact: @dpnvhr")
    return
end

print("[HAMA] ✅ Whitelist verified!")
LoadMainScript()
