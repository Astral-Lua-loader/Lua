# Lua

The script code, fetched live by the [Loader](https://github.com/Astral-Lua-loader/Loader).

    entry.lua          runs first: imports the pages, then menu.start()
    ui/menu.lua        the menu API (drawn by menu.dll from the dll repo)
    lib/dll.lua        downloads + loads DLLs from the dll repo
    rage.lua           a tab; its features live in rage/
    rage/test.lua      a feature: return function(page) ... end
    visuals.lua, visuals/esp.lua
    misc.lua, misc/movement.lua

`import("rage.test")` loads `rage/test.lua` once and returns its value (like `require`).

## Adding a feature

1. Create `visuals/chams.lua`:

       return function(page)
           local g = page:group("Chams")
           local on = g:checkbox("Enabled", false, true)   -- default, bindable
           local alpha = g:slider("Opacity", 0, 100, 80, 1, "%")
           local mat = g:combo("Material", {"Flat", "Glow"})
           callbacks.add("render", function()
               if not on:get() then return end
               -- alpha:get(), mat:get() (option name), mat:index()
           end)
       end

2. Add `"chams"` to the list in `visuals.lua`.

A new tab: copy `misc.lua` as `<tab>.lua`, make the `<tab>/` folder, add `import("<tab>")` to `entry.lua`.
In game: the menu opens with Astral's menu, right-click a toggle to bind a key, drag the top bar to move it.
