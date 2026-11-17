-- lib/hub.lua: astral.rip scripts through the loader. They live in the private repo Astral-Lua-loader/Scripts
-- (index.json + scripts/<id>.lua), read with a read-only token kept next to the loader in astral_loader_token.txt
-- (never in this public repo). Each script runs in its own sandbox:
--   callbacks / events  -> its own owner in lib/callbacks (one real Astral callback per event for everyone)
--   ui                  -> the same Astral ui, but every element it creates is recorded
--   require("json"/"base64"/"msgpack") -> the libraries from the Scripts repo
-- Switching a script off pauses its callbacks and hides its menu elements; on again resumes and shows them (Astral
-- can't delete elements, so a script runs once per load and is never re-run: no duplicate elements).
--
--   local hub = import("lib.hub")
--   hub.list()        -> the scripts (id, title, author, thread), nil + why when there is no token / no index
--   hub.set(id, on)   -> load (first time) or pause / resume one

local cb = import("lib.callbacks")

local REPO = "Astral-Lua-loader/Scripts"
local TOKEN_FILE = "astral_loader_token.txt"
local LIBRARIES = {json = "json", base64 = "base64", msgpack = "msgpack"}

local M = {}
local token, index, why
local running = {}  -- id -> {env, elements, on, failed}
local libs = {}

local function read_token()
    local ok, text = pcall(utils.read_file, TOKEN_FILE)
    if not ok or type(text) ~= "string" then return nil end
    text = text:match("^%s*(%S+)%s*$")
    return text and #text > 10 and text or nil
end

-- a file of the Scripts repo (raw), or nil + why
local function fetch(path)
    local ok, r = pcall(http.get, "https://api.github.com/repos/" .. REPO .. "/contents/" .. path .. "?ref=main", {
        ["Authorization"] = "Bearer " .. token,
        ["Accept"] = "application/vnd.github.raw",
        ["User-Agent"] = "astral-lua-loader",
        ["X-GitHub-Api-Version"] = "2022-11-28",
    })
    if not ok or not r then return nil, tostring(r) end
    if r.code ~= 200 then return nil, "HTTP " .. tostring(r.code) end
    return r.text
end

local function library(name)
    if libs[name] ~= nil then return libs[name] end
    local src, err = fetch("scripts/" .. LIBRARIES[name] .. ".lua")
    if not src then error(("library %s: %s"):format(name, err), 2) end
    local chunk, cerr = load(src, "=" .. name .. ".lua", "t", setmetatable({}, {__index = _G}))
    if not chunk then error(cerr, 2) end
    libs[name] = chunk()
    return libs[name]
end

-- the sandbox's ui: Astral's, with every element a script adds (on a container or on ui itself) recorded
local function ui_for(elements)
    local function track(el)
        if el ~= nil then elements[#elements + 1] = el end
        return el
    end
    local function container(real)
        return setmetatable({}, {__index = function(_, k)
            local v = real[k]
            if type(v) ~= "function" then return v end
            if tostring(k):find("^add_") then return function(_, ...) return track(v(real, ...)) end end
            return function(_, ...) return v(real, ...) end
        end})
    end
    return setmetatable({
        find_container = function(...)
            local c = ui.find_container(...)
            return c and container(c) or c
        end,
    }, {__index = function(_, k)
        local v = ui[k]
        if type(v) == "function" and tostring(k):find("^add_") then return function(...) return track(v(...)) end end
        return v
    end})
end

local function show(elements, on)
    for _, el in ipairs(elements) do pcall(function() el:set_visibility(on) end) end
end

local function run(entry)
    local state = {elements = {}, on = true}
    running[entry.id] = state
    local src, err = fetch("scripts/" .. entry.id .. ".lua")
    if not src then
        state.failed = err
        return loader.log(("script %s: can't download (%s)"):format(entry.id, err))
    end
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.callbacks = cb.callbacks_for(entry.id)
    env.events = cb.events_for(entry.id)
    env.ui = ui_for(state.elements)
    env.require = function(name)
        if LIBRARIES[name] then return library(name) end
        return require(name)
    end
    state.env = env
    local chunk, cerr = load(src, "=" .. entry.id .. ".lua", "t", env)
    if not chunk then
        state.failed = cerr
        return loader.log(("script %s: %s"):format(entry.id, cerr))
    end
    local ok, rerr = pcall(chunk)
    if not ok then
        state.failed = tostring(rerr)
        cb.pause(entry.id, true)  -- whatever it registered before failing stays off
        show(state.elements, false)
        return loader.log(("script %s failed: %s"):format(entry.id, tostring(rerr)))
    end
    loader.log(("script %s loaded (%s, by %s)"):format(entry.id, entry.title, entry.author))
end

function M.list()
    if index then return index end
    if why then return nil, why end
    token = read_token()
    if not token then
        why = "no " .. TOKEN_FILE .. " next to the loader: the Scripts page is empty"
        return nil, why
    end
    local text, err = fetch("index.json")
    if not text then
        why = "can't read the script list (" .. tostring(err) .. "): is the token right?"
        return nil, why
    end
    local ok, list = pcall(function() return library("json").decode(text) end)
    if not ok or type(list) ~= "table" then
        why = "the script list didn't parse: " .. tostring(list)
        return nil, why
    end
    index = {}
    for _, e in ipairs(list) do
        if e.kind ~= "library" and type(e.id) == "string" then index[#index + 1] = e end
    end
    return index
end

function M.set(id, on)
    local entry
    for _, e in ipairs(index or {}) do if e.id == id then entry = e end end
    if not entry then return end
    local state = running[id]
    if not state then
        if on then run(entry) end
        return
    end
    if state.failed or state.on == on then return end
    state.on = on
    cb.pause(id, not on)
    show(state.elements, on)
end

function M.state(id)
    local s = running[id]
    return s and (s.failed and "failed" or s.on and "on" or "off") or "not loaded"
end

if type(rawget(_G, "LOADER_TEST")) == "table" then LOADER_TEST.hub = M end  -- the offline test's handle

return M
