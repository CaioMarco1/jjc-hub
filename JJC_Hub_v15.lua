    end
    local queueToggle = button("INICIAR FILA DE BOSSES",function()
        ctx.farm.toggle("bossQueue")
    end)
    heading("ARMA AUTOMATICA (INVENTARIO / SLOT 1)")
    button("ATIVAR TECLA 1 AGORA", function()
        ctx.equipment.pressSlot1()
    end)
    button("USAR INVERTED SPEAR OF HEAVEN", function()
        ctx.equipment.usePreferred()
    end)
    local weaponChoice = button("ARMA: SELECIONAR", function()
        ctx.equipment.chooseNext()
    end)
    local weaponEquip = button("EQUIPAR AGORA", function()
        if not ctx.state.weaponName then
            ctx.report("Selecione primeiro uma arma")
        elseif not ctx.equipment.ensure(true) then
            ctx.report("Nao foi possivel equipar a arma selecionada")
        end
    end)
    local weaponAuto = button("AUTOEQUIP: DESLIGADO", function()
        ctx.equipment.toggle()
    end)
    button("ATUALIZAR LISTA DE ARMAS", function()
        local names = ctx.equipment.list()
        if #names == 0 then
            ctx.report("Nenhuma Tool visivel no inventario")
        else
            ctx.report("Armas detectadas: " .. table.concat(names, ", "):sub(1,90))
        end
        ctx.refresh()
    end)
    heading("TREINO E CONTROLES")
    local endurance = button("AUTO ENDURANCE",function() ctx.stats.toggle("Endurance") end)
    local energy = button("AUTO CURSED ENERGY",function() ctx.stats.toggle("Cursed_Energy") end)
    button("VERIFICAR COMBAT EVENT",function()
        ctx.report(ctx.combat.available() and "CombatEvent encontrado" or "CombatEvent nao encontrado")
    end)
    button("DESLIGAR TUDO",function() ctx.stopAll() end)
    button("FECHAR GUI",function() ctx.close() end)

    local minimized = false
    track(min.MouseButton1Click:Connect(function()
        minimized = not minimized
        menu.Size = minimized and UDim2.fromOffset(332,42) or fullSize
        min.Text = minimized and "+" or "-"
        scroll.Visible = not minimized
        status.Visible = not minimized
    end))

    -- Arrasto via InputChanged global: mouse e toque no Delta Android.
    local userInput = game:GetService("UserInputService")
    local dragging, dragKind, touch, originX, originY, startPos = false,nil,nil,0,0,nil
    local function begin(input)
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
        -- Reservar canto do botao minimizar para nao arrastar acidentalmente.
        if input.Position.X >= header.AbsolutePosition.X + header.AbsoluteSize.X - 47 then return end
        dragging, dragKind = true, kind
        touch = kind == Enum.UserInputType.Touch and input or nil
        originX,originY = input.Position.X,input.Position.Y
        startPos = menu.Position
    end
    track(header.InputBegan:Connect(begin))
    track(title.InputBegan:Connect(begin))
    track(userInput.InputChanged:Connect(function(input)
        if not dragging or not menu.Parent or not startPos then return end
        if dragKind == Enum.UserInputType.MouseButton1 then
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        elseif input ~= touch then return end
        local dx,dy = input.Position.X-originX, input.Position.Y-originY
        menu.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+dx,
            startPos.Y.Scale,startPos.Y.Offset+dy)
    end))
    track(userInput.InputEnded:Connect(function(input)
        if (dragKind == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
            or (dragKind == Enum.UserInputType.Touch and input == touch) then
            dragging,dragKind,touch = false,nil,nil
        end
    end))

    ctx.refresh = function()
        if not gui.Parent then return end
        local s = ctx.state
        npc.Text = "NPC: "..s.npcs[s.npcIndex]
        npcToggle.Text = s.mode == "npc" and "PARAR AUTO FARM" or "LIGAR AUTO FARM"
        boss.Text = "BOSS: "..s.bosses[s.bossIndex]
        bossToggle.Text = s.mode == "boss" and "PARAR AUTO BOSS" or "LIGAR AUTO BOSS"
        local n=0
        for name, b in pairs(selectedButtons) do
            local chosen=s.selectedBosses[name]
            if chosen then n=n+1 end
            b.Text = (chosen and "[X] " or "[ ] ")..name
            b.BackgroundColor3 = chosen and Color3.fromRGB(34,128,90) or Color3.fromRGB(47,102,140)
        end
        queueToggle.Text = s.mode == "bossQueue" and
            ("PARAR FILA ["..s.queueIndex.."/"..#s.queue.."] "..tostring(s.queueName or "")) or
            ("INICIAR FILA DE BOSSES ("..n..")")
        local names = ctx.equipment.list()
        weaponChoice.Text = "ARMA: " .. tostring(s.weaponName or "SELECIONAR (" .. #names .. ")")
        weaponAuto.Text = s.autoEquip and "AUTOEQUIP: LIGADO" or "AUTOEQUIP: DESLIGADO"
        weaponAuto.BackgroundColor3 = s.autoEquip and Color3.fromRGB(34,128,90) or Color3.fromRGB(47,102,140)
        endurance.Text = s.train.Endurance and "PARAR ENDURANCE" or "LIGAR ENDURANCE"
        energy.Text = s.train.Cursed_Energy and "PARAR CURSED ENERGY" or "LIGAR CURSED ENERGY"
    end
    ctx.report = function(message)
        if not ctx.state.alive then return end
        local output=tostring(message):sub(1,105)
        ctx.state.lastMessage=output
        if status.Parent then status.Text=output end
        print("[JJC v1.5] "..output)
    end
    ctx.close = function()
        if not ctx.state.alive then return end
        ctx.stopAll()
        ctx.state.alive=false
        if ctx.equipment then ctx.equipment.shutdown() end
        for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        if gui.Parent then gui:Destroy() end
    end
    ctx.refresh()
    ctx.report("JJC v1.5 pronto | Inverted Spear no slot 1")
end

    end)()
    initialize(ctx)
end
