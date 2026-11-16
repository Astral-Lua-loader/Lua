-- aim.lua: placeholder feature module. Shows the pattern: read menu, hook a callback.

local menu = import("modules.menu")

callbacks.add("move", function(cmd)
    if not menu.aim_enabled:get() then return end
    -- feature code goes here
end)
