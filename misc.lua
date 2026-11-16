-- misc.lua: the Misc tab. Each feature is one file in misc/, given this page to add its group(s) to.
-- Add a feature: create misc/<name>.lua and put its name in this list.

local page = import("ui.menu").page("Misc")

for _, feature in ipairs({"movement"}) do
    import("misc." .. feature)(page)
end
