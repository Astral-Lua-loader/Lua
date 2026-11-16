-- visuals/esp.lua: placeholder feature (controls only).

return function(page)
    local g = page:group("ESP")
    local boxes = g:checkbox("Boxes", true, true)
    local names = g:checkbox("Names", true)
    local style = g:combo("Box style", {"Full", "Corners", "Rounded"}, 2)

    callbacks.add("render", function()
        if not boxes:get() then return end
        -- feature code: names:get(), style:get()
    end)
end
