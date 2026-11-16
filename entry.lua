-- entry.lua: first file the loader runs. Declare every page, then start the menu.
-- import("folder.file") loads folder/file.lua from this repo once and returns its value.

local menu = import("ui.menu")

import("rage")
import("visuals")
import("misc")

menu.start()
