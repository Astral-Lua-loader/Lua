-- lib/dll.lua: get a DLL from github.com/Astral-Lua-loader/dll and load it.
--   local dll = import("lib.dll")
--   local h = dll.load("example", "1")   -- dll repo file: example/1/example.dll
--   local fn = dll.proc(h, "start", "int(*)(void)")
--   dll.free(h)                          -- on shutdown
-- Each version is cached as astral\lua\astral_dlls\<name>-<version>.dll, so a loaded DLL
-- is never overwritten: bump the version to ship a new build.

local ffi = require("ffi")

local REPO = "https://raw.githubusercontent.com/Astral-Lua-loader/dll/main/"
local FOLDER = "astral_dlls"

local K = {}
for name, sig in pairs({
    LoadLibraryA = "void*(*)(const char*)",
    FreeLibrary = "int(*)(void*)",
    GetProcAddress = "void*(*)(void*, const char*)",
    GetModuleFileNameA = "unsigned long(*)(void*, char*, unsigned long)",
}) do
    local a = (rawget(_G, "memory") or utils).get_module_export("kernel32.dll", name)
    assert(a and a ~= 0, "kernel32 " .. name .. " not found")
    K[name] = ffi.cast(sig, a)
end

local download -- URLDownloadToFileA handles binary; http.get text may not
do
    local urlmon = K.LoadLibraryA("urlmon.dll")
    local a = urlmon ~= nil and K.GetProcAddress(urlmon, "URLDownloadToFileA")
    assert(a and a ~= nil, "urlmon URLDownloadToFileA not found")
    download = ffi.cast("long(*)(void*, const char*, const char*, unsigned long, void*)", a)
end

local lua_dir = rawget(_G, "ASTRAL_LUA_DIR")  -- (the offline test's folder)
if not lua_dir then
    local buffer = ffi.new("char[1024]")
    local n = tonumber(K.GetModuleFileNameA(nil, buffer, 1024))
    local root = ffi.string(buffer, n):match("^(.*)\\game\\bin\\win64\\[^\\]+$")
    assert(root, "can't find the game folder")
    lua_dir = root .. "\\astral\\lua\\"
end

local M = {}

function M.load(name, version)
    local file = ("%s\\%s-%s.dll"):format(FOLDER, name, version)
    if not utils.file_exists(file) then
        utils.create_folder(FOLDER)
        local url = ("%s%s/%s/%s.dll"):format(REPO, name, version, name)
        if download(nil, url, lua_dir .. file, 0, nil) ~= 0 or not utils.file_exists(file) then
            error("can't download " .. url, 0)
        end
        loader.log("downloaded " .. name .. " " .. version)
    end
    local h = K.LoadLibraryA(lua_dir .. file)
    if h == nil then error("can't load " .. file, 0) end
    return h
end

function M.proc(h, export, sig)
    local a = K.GetProcAddress(h, export)
    if a == nil then error("missing export " .. export, 0) end
    return ffi.cast(sig, a)
end

function M.free(h) K.FreeLibrary(h) end

return M
