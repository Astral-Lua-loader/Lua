-- ui/menu.lua: the menu. The DLL (dll repo: menu/<MENU_VERSION>/menu.dll) draws it with ImGui whenever Astral's menu
-- is open and keeps the values, keybinds and menu.cfg; this file only declares controls and reads them.
--
--   local menu = import("ui.menu")
--   local page = menu.page("Rage")                      -- a tab (rage.lua)
--   local g = page:group("Test")                        -- a box on that tab (rage/test.lua); col 0/1 auto, or :group(name, 1)
--   local on  = g:checkbox("Enabled", false, true)      -- default, bindable (right-click it in the menu to set a key)
--   local fov = g:slider("Field of view", 1, 180, 10, 1, "°")   -- min, max, default, step, suffix
--   local tgt = g:combo("Target", {"Closest", "Lowest health"}, 1)  -- options, default (1-based)
--   on:get() -> bool   fov:get() -> number   tgt:get() -> option name, tgt:index() -> 1-based
--   menu.start()                                        -- entry.lua, after every page is declared

local ffi = require("ffi")
local dll = import("lib.dll")

local MENU_VERSION = "10"

local M = {pages = {}}
local next_slot, D, started = 0, nil, false

local function clean(s) return (tostring(s):gsub("[\t\r\n|%^]", " ")) end

local function control(kind, def)
    local c = {slot = next_slot, default = def}
    next_slot = next_slot + 1
    local raw = function() return started and D.get(c.slot) or nil end
    if kind == "check" then
        c.get = function() local v = raw(); if v == nil then return c.default end return v ~= 0 end
    elseif kind == "slider" then
        c.get = function() return raw() or c.default end
    else
        c.index = function() local v = raw(); return v and math.floor(v + 0.5) + 1 or c.default end
        c.get = function() return c.options[c.index()] end
    end
    return c
end

local Group = {}
Group.__index = Group

function Group:add(kind, c, fields)
    c.line = table.concat({kind, c.slot, clean(c.name), (table.unpack or unpack)(fields)}, "\t")
    self.rows[#self.rows + 1] = c
    return c
end

function Group:checkbox(name, default, bindable)
    local c = control("check", default == true)
    c.name = name
    return self:add("check", c, {default and 1 or 0, bindable and 1 or 0})
end

function Group:slider(name, min, max, default, step, suffix)
    default = default or min
    local c = control("slider", default)
    c.name = name
    return self:add("slider", c, {default, min, max, step or 1, clean(suffix or "")})
end

function Group:combo(name, options, default)
    default = default or 1
    local c = control("combo", default)
    c.name, c.options = name, options
    local opts = {}
    for i, o in ipairs(options) do opts[i] = clean(o) end
    return self:add("combo", c, {default - 1, table.concat(opts, "|")})
end

-- a searchable list (Astral's script list): items {{title, author}, ...}; each item is on/off by its circle
--   l:selected() -> 1-based or nil   l:state(i) -> 0 off, 1 on, 2 failed   l:set_state(i, v)
function Group:list(name, items, height)
    local c = control("list", nil)
    c.name, c.items = name, items
    next_slot = next_slot + #items
    c.selected = function() local v = started and D.get(c.slot); return v and v >= 0 and math.floor(v + 0.5) + 1 or nil end
    c.state = function(_, i) return started and math.floor(D.get(c.slot + i) + 0.5) or 0 end
    c.set_state = function(_, i, v) if started then D.set(c.slot + i, v) end end
    local parts = {}
    for i, it in ipairs(items) do parts[i] = clean(it[1]) .. "^" .. clean(it[2] or "") end
    return self:add("list", c, {height or 380, table.concat(parts, "|")})
end

-- the selected item of a list, with a button to switch it
function Group:info(list)
    local c = control("info", 0)
    c.name = "Info"
    return self:add("info", c, {list.slot})
end

local Page = {}
Page.__index = Page

local function height(g)
    local h = 42
    for _, c in ipairs(g.rows) do
        local kind = c.line:match("^(%a+)")
        h = h + (kind == "slider" and 42 or kind == "combo" and 32 or 28)
    end
    return h
end

function Page:group(name, col)
    local g = setmetatable({name = name, col = col, rows = {}}, Group)
    self.groups[#self.groups + 1] = g
    return g
end

function M.page(name)
    local p = setmetatable({name = name, groups = {}}, Page)
    M.pages[#M.pages + 1] = p
    return p
end

local function schema()
    local out = {}
    for _, p in ipairs(M.pages) do
        out[#out + 1] = "page\t" .. clean(p.name)
        local cols = {0, 0}
        for _, g in ipairs(p.groups) do
            local col = g.col or (cols[2] < cols[1] and 1 or 0)  -- the shorter column
            cols[col + 1] = cols[col + 1] + height(g)
            out[#out + 1] = "group\t" .. clean(g.name) .. "\t" .. col
            for _, c in ipairs(g.rows) do out[#out + 1] = c.line end
        end
    end
    return table.concat(out, "\n")
end

local function accent()
    local ok, c = pcall(function() return theme:get_accent() end)
    if not ok or not c then ok, c = pcall(function() return theme.get_accent() end) end
    if not ok or not c then return -1, -1, -1 end
    local ok2, r, g, b = pcall(function() return c.r, c.g, c.b end)
    if not ok2 or type(r) ~= "number" then return -1, -1, -1 end
    if r <= 1 and g <= 1 and b <= 1 then r, g, b = r * 255, g * 255, b * 255 end
    return math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)
end

function M.start()
    local h = dll.load("menu", MENU_VERSION)
    D = {
        init = dll.proc(h, "alm_init", "int(*)(void)"),
        schema = dll.proc(h, "alm_schema", "void(*)(const char*)"),
        get = dll.proc(h, "alm_get", "double(*)(int)"),
        set = dll.proc(h, "alm_set", "void(*)(int, double)"),
        state = dll.proc(h, "alm_state", "void(*)(int, int, int, int)"),
        shutdown = dll.proc(h, "alm_shutdown", "void(*)(void)"),
    }
    if D.init() == 0 then
        dll.free(h)
        error("menu.dll couldn't hook the game's renderer", 0)
    end
    D.schema(schema())
    started = true

    local r, g, b, at = -1, -1, -1, -1
    callbacks.add("render", function()
        local t = globals.get_real_time()
        if t - at > 0.25 then r, g, b = accent(); at = t end
        local ok, open = pcall(ui.is_menu_open)
        D.state((ok and open) and 1 or 0, r, g, b)
    end)
    callbacks.add("shutdown", function()
        started = false
        D.shutdown()
        dll.free(h)
    end)
    loader.log("menu up: it opens with Astral's menu")
end

return M
