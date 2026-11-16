-- visuals.lua: the Visuals tab. Each feature is one file in visuals/, given this page to add its group(s) to.
-- Add a feature: create visuals/<name>.lua and put its name in this list.

local page = import("ui.menu").page("Visuals")

for _, feature in ipairs({"esp"}) do
    import("visuals." .. feature)(page)
end
