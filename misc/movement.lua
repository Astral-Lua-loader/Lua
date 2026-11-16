-- misc/movement.lua: placeholder feature (controls only).

return function(page)
    local g = page:group("Movement")
    local bhop = g:checkbox("Bunny hop", false, true)
    local strafe = g:checkbox("Auto strafe", false, true)

    callbacks.add("move", function(cmd)
        if not bhop:get() then return end
        -- feature code: strafe:get()
    end)
end
