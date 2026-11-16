-- lib/callbacks.lua: Astral allows one callback per event per script; every module here shares one script. This
-- replaces `callbacks` for all modules with one that registers a single Astral callback per event and calls every
-- function added to it, so features keep writing callbacks.add("move", fn) as usual. entry.lua imports it first.

local real = callbacks
local lists = {}

callbacks = setmetatable({
    add = function(name, fn)
        local list = lists[name]
        if not list then
            list = {}
            lists[name] = list
            real.add(name, function(...)
                for i = 1, #list do
                    local ok, err = pcall(list[i], ...)
                    if not ok then loader.log(name .. " callback: " .. tostring(err)) end
                end
            end)
        end
        list[#list + 1] = fn
    end,
}, {__index = real})
