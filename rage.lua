-- rage.lua: the Rage tab. Each feature is one file in rage/, given this page to add its group(s) to.
-- Add a feature: create rage/<name>.lua and put its name in this list.

local page = import("ui.menu").page("Rage")

for _, feature in ipairs({"test"}) do
    import("rage." .. feature)(page)
end
