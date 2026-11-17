-- lib/callbacks.lua: Astral allows one callback per event per script, and everything here (the loader's modules and
-- the hosted astral.rip scripts) runs inside one script. This keeps ONE Astral callback per event and calls every
-- function added to it, each tagged with an owner ("loader" for the modules, a script's id for a hosted script), so a
-- hosted script's callbacks can be paused (switched off in the Scripts page) without touching anyone else's.
-- The same goes for `events` (game events). entry.lua imports this first; modules keep writing callbacks.add(...).
--
--   local cb = import("lib.callbacks")
--   cb.callbacks_for(owner), cb.events_for(owner)  -- a callbacks / events table for one owner (add, remove)
--   cb.pause(owner, true|false)                     -- skip / call that owner's functions again

local M = {}
local paused = {}

-- a fan-out over one real registrar (callbacks.add or events.add): one real registration per name
local function fanout(real_add, what)
    local lists = {}
    local function add(owner, name, fn)
        if type(fn) ~= "function" then return end
        local list = lists[name]
        if not list then
            list = {}
            lists[name] = list
            real_add(name, function(...)
                local result
                for i = 1, #list do
                    local e = list[i]
                    if e and not paused[e.owner] then
                        local ok, r = pcall(e.fn, ...)
                        if not ok then loader.log(("%s %s (%s): %s"):format(what, name, e.owner, tostring(r)))
                        elseif r ~= nil then result = r end
                    end
                end
                return result
            end)
        end
        list[#list + 1] = {fn = fn, owner = owner}
    end
    local function fire(owner, name, ...)  -- that owner's functions for name, now (paused or not)
        for _, e in ipairs(lists[name] or {}) do
            if e.owner == owner then
                local ok, r = pcall(e.fn, ...)
                if not ok then loader.log(("%s %s (%s): %s"):format(what, name, owner, tostring(r))) end
            end
        end
    end
    local function clear(owner)  -- every function of that owner, under every name
        for _, list in pairs(lists) do
            for i = #list, 1, -1 do if list[i].owner == owner then table.remove(list, i) end end
        end
    end
    local function remove(owner, name, fn)
        local list = lists[name]
        if not list then return end
        for i = #list, 1, -1 do
            if list[i].owner == owner and (fn == nil or list[i].fn == fn) then table.remove(list, i) end
        end
    end
    return add, remove, fire, clear
end

local real_callbacks = callbacks
local cb_add, cb_remove, cb_fire, cb_clear = fanout(function(n, f) real_callbacks.add(n, f) end, "callback")
local real_events = rawget(_G, "events")
local ev_add, ev_remove, ev_clear
if type(real_events) == "table" or type(real_events) == "userdata" then
    ev_add, ev_remove, _, ev_clear = fanout(function(n, f) real_events.add(n, f) end, "event")
end

local function scoped(real, add, remove, owner)
    return setmetatable({
        add = function(name, fn) add(owner, name, fn) end,
        remove = function(name, fn) remove(owner, name, fn) end,
    }, {__index = real})
end

function M.callbacks_for(owner) return scoped(real_callbacks, cb_add, cb_remove, owner) end
function M.events_for(owner)
    if not ev_add then return real_events end
    return scoped(real_events, ev_add, ev_remove, owner)
end
function M.pause(owner, on) paused[owner] = on or nil end
-- unload: that owner's shutdown callbacks (scripts undo their cvars / hooks there), then all its callbacks and events go
function M.unload(owner)
    cb_fire(owner, "shutdown")
    cb_clear(owner)
    if ev_clear then ev_clear(owner) end
    paused[owner] = nil
end

-- the loader's own modules: the global callbacks / events become the "loader" owner's
callbacks = M.callbacks_for("loader")
if ev_add then events = M.events_for("loader") end

return M
