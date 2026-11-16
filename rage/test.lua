-- rage/test.lua: placeholder feature, shows the pattern: declare controls, read them in a callback.

return function(page)
    local g = page:group("Test")
    local enabled = g:checkbox("Enabled", false, true)
    local fov = g:slider("Field of view", 1, 180, 10, 1, "°")
    local target = g:combo("Target", {"Closest to crosshair", "Lowest health", "Distance"})

    callbacks.add("move", function(cmd)
        if not enabled:get() then return end
        -- feature code: fov:get(), target:get()
    end)
end
