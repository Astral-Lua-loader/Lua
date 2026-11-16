# Lua

The script code, fetched live by the [Loader](https://github.com/Astral-Lua-loader/Loader).

- `entry.lua` runs first and imports the rest.
- `import("modules.menu")` loads `modules/menu.lua` once and returns its value (like `require`).
- `modules/` features (`menu.lua`, `aim.lua`, ...), `lib/` shared helpers.
- `lib/dll.lua` downloads and loads DLLs from the [dll](https://github.com/Astral-Lua-loader/dll) repo:
  `import("lib.dll").load("name", "1")`.
