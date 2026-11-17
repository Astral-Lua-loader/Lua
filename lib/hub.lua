-- lib/hub.lua: astral.rip scripts through the loader. They live in the private repo Astral-Lua-loader/Scripts
-- (index.json + scripts/<id>.lua), read with a read-only token: the one sealed (scrambled) into loader.lua by
-- tools/seal_token.py, or astral_loader_token.txt next to the loader (overrides it). Never in this repo. Each script
-- runs in its own sandbox:
--   callbacks / events  -> its own owner in lib/callbacks (one real Astral callback per event for everyone)
--   ui                  -> the same Astral ui, but every element it creates is recorded
--   require("json"/"base64"/"msgpack") -> the libraries from the Scripts repo
-- Switching a script off unloads it the way Astral does (its shutdown callbacks run, its callbacks and events go) and
-- hides its menu elements; on again runs it fresh, getting its old elements back (Astral can't delete elements).
--
--   local hub = import("lib.hub")
--   hub.list()        -> the scripts (id, title, author, thread), nil + why when there is no token / no index
--   hub.set(id, on)   -> run it, or unload it

local cb = import("lib.callbacks")

local REPO = "Astral-Lua-loader/Scripts"
local TOKEN_FILE = "astral_loader_token.txt"
local LIBRARIES = {json = "json", base64 = "base64", msgpack = "msgpack"}

local M = {}
local token, index, why
local running = {}  -- id -> {env, elements, reuse, on, failed}
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

-- the sandbox's ui: Astral's, with every element a script adds (on a container or on ui itself) recorded. Astral can't
-- delete elements, so a re-run gets back the element it made last time (same container, kind, name) instead of a copy.
local function ui_for(state)
    local function track(key, make)
        local el = state.reuse[key]
        if el ~= nil then
            pcall(function() el:set_visibility(true) end)
        else
            el = make()
            if el == nil then return nil end
            state.reuse[key] = el
        end
        state.elements[#state.elements + 1] = el
        return el
    end
    local function container(real, ckey)
        return setmetatable({}, {__index = function(_, k)
            local v = real[k]
            if type(v) ~= "function" then return v end
            if tostring(k):find("^add_") then
                return function(_, ...)
                    local args = {...}
                    return track(ckey .. "|" .. k .. "|" .. tostring(args[1]), function() return v(real, (table.unpack or unpack)(args)) end)
                end
            end
            return function(_, ...) return v(real, ...) end
        end})
    end
    return setmetatable({
        find_container = function(...)
            local c = ui.find_container(...)
            local parts = {}
            for i, a in ipairs({...}) do parts[i] = tostring(a) end
            return c and container(c, table.concat(parts, "/")) or c
        end,
    }, {__index = function(_, k)
        local v = ui[k]
        if type(v) == "function" and tostring(k):find("^add_") then
            return function(...)
                local args = {...}
                return track("ui|" .. k .. "|" .. tostring(args[1]), function() return v((table.unpack or unpack)(args)) end)
            end
        end
        return v
    end})
end

local function show(elements, on)
    for _, el in ipairs(elements) do pcall(function() el:set_visibility(on) end) end
end

local function run(entry)
    local state = running[entry.id] or {reuse = {}}
    running[entry.id] = state
    state.elements, state.on, state.failed = {}, true, nil
    local src, err = fetch("scripts/" .. entry.id .. ".lua")
    if not src then
        state.failed, state.on = err, false
        return loader.log(("script %s: can't download (%s)"):format(entry.id, err))
    end
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.callbacks = cb.callbacks_for(entry.id)
    env.events = cb.events_for(entry.id)
    env.ui = ui_for(state)
    env.require = function(name)
        if LIBRARIES[name] then return library(name) end
        return require(name)
    end
    state.env = env
    local chunk, cerr = load(src, "=" .. entry.id .. ".lua", "t", env)
    if not chunk then
        state.failed, state.on = cerr, false
        return loader.log(("script %s: %s"):format(entry.id, cerr))
    end
    local ok, rerr = pcall(chunk)
    if not ok then
        state.failed, state.on = tostring(rerr), false
        cb.unload(entry.id)  -- whatever it set up before failing is undone
        show(state.elements, false)
        return loader.log(("script %s failed: %s"):format(entry.id, tostring(rerr)))
    end
    loader.log(("script %s loaded (%s, by %s)"):format(entry.id, entry.title, entry.author))
end

function M.list()
    if index then return index end
    if why then return nil, why end
    token = read_token() or loader.scripts_token  -- the file overrides the one sealed into the loader
    if not token then
        why = "no Scripts token (none sealed into the loader, no " .. TOKEN_FILE .. "): the Scripts page is empty"
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
    if state.on == on then return end
    if on then return run(entry) end  -- fresh, as when Astral loads it (a failed one gets another try)
    state.on = false
    cb.unload(id)  -- its shutdown callbacks undo what it changed, then its callbacks and events go
    show(state.elements, false)
end

function M.state(id)
    local s = running[id]
    return s and (s.failed and "failed" or s.on and "on" or "off") or "not loaded"
end

if type(rawget(_G, "LOADER_TEST")) == "table" then LOADER_TEST.hub = M end  -- the offline test's handle

return M
