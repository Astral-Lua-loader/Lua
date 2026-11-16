-- menu.lua: every control lives here; other modules read them via import("modules.menu").

local group = ui.find_container("Scripting, Script elements")

return {
    aim_enabled = group:add_checkbox("Aim enabled"),
}
