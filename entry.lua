-- entry.lua: first file the loader runs. Pull in the modules in order here.
-- import("folder.file") loads folder/file.lua from this repo once and returns its value.

local menu = import("modules.menu")
import("modules.aim")

loader.log("loaded, menu: " .. tostring(menu ~= nil))
