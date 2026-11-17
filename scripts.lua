-- scripts.lua: the Scripts page. A searchable list of the astral.rip scripts from the private Scripts repo (lib/hub.lua);
-- switching one on downloads and runs it the first time, off pauses it and hides its menu items, on again resumes.

local menu = import("ui.menu")
local hub = import("lib.hub")

local list, why = hub.list()
local page = menu.page("Scripts")
if not list then
    loader.log(why)
    page:group("Scripts"):checkbox("Couldn't load the scripts" .. (why:match("%((HTTP %d+)%)") and " (" .. why:match("%((HTTP %d+)%)") .. ")" or ""), false)
    return
end

local test = rawget(_G, "LOADER_TEST")
hub.preload(type(test) == "table" and test.no_preload or nil)  -- now: Astral only allows elements and fonts while we initialise

local items = {}
for i, e in ipairs(list) do items[i] = {hub.title(e), e.author} end
local scripts = page:group("Scripts", 0):list("Scripts", items, 380)
page:group("Script", 1):info(scripts)
loader.log(("%d astral.rip scripts in the Scripts page"):format(#list))

callbacks.add("render", function()
    for i, e in ipairs(list) do
        local st = scripts:state(i)
        if st ~= 2 then
            hub.set(e.id, st == 1)
            if st == 1 and hub.state(e.id) == "failed" then scripts:set_state(i, 2) end
        end
    end
end)
if type(rawget(_G, "LOADER_TEST")) == "table" then LOADER_TEST.scripts = {list = scripts, entries = list} end
