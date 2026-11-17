-- scripts.lua: the Scripts page. One checkbox per astral.rip script from the private Scripts repo (lib/hub.lua);
-- ticking one downloads and runs it the first time, unticking pauses it and hides its menu items, ticking again resumes.

local menu = import("ui.menu")
local hub = import("lib.hub")

local list, why = hub.list()
local page = menu.page("Scripts")
if not list then
    loader.log(why)
    page:group("Scripts"):checkbox("Couldn't load the scripts" .. (why:match("%((HTTP %d+)%)") and " (" .. why:match("%((HTTP %d+)%)") .. ")" or ""), false)
    return
end

-- two columns, in index order (sorted by title)
local half = math.ceil(#list / 2)
local left, right = page:group("Scripts", 0), page:group("More scripts", 1)
local boxes = {}
for i, e in ipairs(list) do
    local label = (e.title:gsub("%s+", " ")):sub(1, 34) .. " - " .. e.author
    boxes[#boxes + 1] = {id = e.id, box = (i <= half and left or right):checkbox(label, false)}
end
loader.log(("%d astral.rip scripts in the Scripts page"):format(#list))

callbacks.add("render", function()
    for _, b in ipairs(boxes) do hub.set(b.id, b.box:get()) end
end)
