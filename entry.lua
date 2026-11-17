-- entry.lua: first file the loader runs. Declare every page, then start the menu.
-- import("folder.file") loads folder/file.lua from this repo once and returns its value.

import("lib.callbacks")  -- first: lets every module add its own move/render/... callbacks
local menu = import("ui.menu")

import("scripts")  -- astral.rip scripts from the private Scripts repo (needs astral_loader_token.txt)

menu.start()
