-- JJC Hub v1.6 | Auto Farm, Auto Boss e Auto Stats | Sem key
-- Atualizacao: apos morte, usar hotbar customizada do jogo; sem Backpack.
-- Menu movel/minimizavel; combo M1 1-4 experimental; ataque 0.10s.
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then warn("[JJC] LocalPlayer nao encontrado") return end
local env = _G
if type(getgenv) == "function" then
    local ok, e = pcall(getgenv)
    if ok and type(e) == "table" then env = e end
end
if type(env.JJC_HUB_V16_CLOSE) == "function" then pcall(env.JJC_HUB_V16_CLOSE) end
if type(env.JJC_HUB_V15_CLOSE) == "function" then pcall(env.JJC_HUB_V15_CLOSE) end
if type(env.JJC_HUB_V14_CLOSE) == "function" then pcall(env.JJC_HUB_V14_CLOSE) end
if type(env.JJC_HUB_V13_CLOSE) == "function" then pcall(env.JJC_HUB_V13_CLOSE) end
if type(env.JJC_HUB_V12_CLOSE) == "function" then pcall(env.JJC_HUB_V12_CLOSE) end
if type(env.JJC_HUB_V11_CLOSE) == "function" then pcall(env.JJC_HUB_V11_CLOSE) end
if type(env.JJC_HUB_V10_CLOSE) == "function" then pcall(env.JJC_HUB_V10_CLOSE) end
local ctx = {player = LocalPlayer}

-- BEGIN 01_state.lua
do
    local initialize = (function()
-- Estado e configuracoes globais do JJC Hub v1.6
return function(ctx)
    local state = {
        alive = true,
        mode = "off",    -- off, npc, boss
        farmToken = 0,
        npcIndex = 1,
        bossIndex = 1,
        train = {Endurance = false, Cursed_Energy = false},
        trainToken = {Endurance = 0, Cursed_Energy = 0},
        npcs = {"Dummy", "FlyHead", "Froggy", "Sorcerer"},
        bosses = {
            "Choso", "Sukuna", "UltSukuna", "Meguna", "TheStrongest",
            "Mahoraga", "Kashimo", "Kechizu", "LoveSorcerer", "Dabura"
        },
        attackInterval = 0.10,
        comboMode = "sequence", -- "sequence" (1-4 experimental) ou "fixed" (1 testado)
        trainingInterval = 1.75,
        lastMessage = ""
    }
    ctx.state = state
    ctx.report = function(message)
        if not state.alive then return end
        state.lastMessage = tostring(message)
        print("[JJC v1.6] " .. state.lastMessage)
    end
    ctx.stopAll = function()
        state.mode = "off"
        state.farmToken = state.farmToken + 1
        for action in pairs(state.train) do
            state.train[action] = false
            state.trainToken[action] = state.trainToken[action] + 1
        end
        if ctx.combat and ctx.combat.resetCombo then ctx.combat.resetCombo() end
        if ctx.refresh then ctx.refresh() end
        ctx.report("Todas as automacoes foram interrompidas")
    end
end

    end)()
    initialize(ctx)
end
-- END 01_state.lua

-- BEGIN 02_player.lua
do
    local initialize = (function()
-- Consultas locais ao jogador (sem esperas bloqueantes)
return function(ctx)
    local api = {}
    function api.get()
        local char = ctx.player.Character
        if not char or not char.Parent then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not root then return nil end
        return char, hum, root
    end
    function api.stats()
        return ctx.player:FindFirstChild("UIStats")
    end
    ctx.character = api
end

    end)()
    initialize(ctx)
end
-- END 02_player.lua

-- BEGIN 03_targets.lua
do
    local initialize = (function()
-- Selecao de NPCs e chefes a partir dos nomes vistos no script de referencia.
return function(ctx)
    local Workspace = game:GetService("Workspace")
    local cache, nextScan = {}, 0
    local api = {}

    local function valid(model, name)
        if not model or not model:IsA("Model") or model.Name ~= name then return nil end
        if not model.Parent or model == ctx.player.Character then return nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if hum and hum.Health > 0 and root then return root end
        return nil
    end

    function api.find(name, playerRoot)
        if not playerRoot then return nil end
        local best, bestRoot, bestDistance
        local direct = Workspace:FindFirstChild(name)
        local root = valid(direct, name)
        if root then return direct, root end

        -- Evita percorrer todos os objetos do workspace a cada iteracao.
        if os.clock() >= nextScan then
            cache = Workspace:GetDescendants()
            nextScan = os.clock() + 2.5
        end
        for _, model in ipairs(cache) do
            if model.Name == name then
                local candidateRoot = valid(model, name)
                if candidateRoot then
                    local distance = (candidateRoot.Position - playerRoot.Position).Magnitude
                    if not bestDistance or distance < bestDistance then
                        best, bestRoot, bestDistance = model, candidateRoot, distance
                    end
                end
            end
        end
        return best, bestRoot
    end
    ctx.targets = api
end

    end)()
    initialize(ctx)
end
-- END 03_targets.lua

-- BEGIN 04_combat.lua
do
    local initialize = (function()
-- Uso experimental da API de combate identificada no modulo publico de referencia.
-- O servidor pode rejeitar a acao; nao significa dano ou treino confirmado.
return function(ctx)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local api = {}
    local lastAttack, lastTraining = -1000, {}
    local comboIndex, comboTarget = 0, nil

    function api.resetCombo()
        comboIndex = 0
        comboTarget = nil
    end
    local function remote()
        local events = ReplicatedStorage:FindFirstChild("Events")
        local event = events and events:FindFirstChild("CombatEvent")
        if event and event:IsA("RemoteEvent") then return event end
        return nil
    end

    function api.available()
        return remote() ~= nil
    end

    function api.attack(target)
        local char = ctx.character.get()
        if not char then return false, "Personagem indisponivel" end
        local event = remote()
        if not event then return false, "CombatEvent nao encontrado" end
        if not target or not target.Parent then return false, "Alvo indisponivel" end
        local now = os.clock()
        if now - lastAttack < ctx.state.attackInterval then return false, "Intervalo de ataque" end
        -- Tentativa de executar o combo natural M1 (1 -> 4), sem inventar um
        -- multiplicador de dano. O servidor continua decidindo o dano real.
        if target ~= comboTarget or now - lastAttack > 1.15 then
            api.resetCombo()
        end
        local step = ctx.state.comboMode == "sequence" and (comboIndex % 4 + 1) or 1
        lastAttack = now
        local ok, err = pcall(function()
            event:FireServer({
                Character = char,
                Action = "M1",
                Combo = step,
                Target = target,
                BehindPlayer = false
            })
        end)
        if ok then
            comboIndex = step
            comboTarget = target
        else
            api.resetCombo()
        end
        return ok, ok and ("M1 enviado (combo " .. step .. ")") or tostring(err)
    end

    function api.train(action)
        if action ~= "Endurance" and action ~= "Cursed_Energy" then
            return false, "Atributo desconhecido"
        end
        local char = ctx.character.get()
        local stats = ctx.character.stats()
        local event = remote()
        if not char then return false, "Personagem indisponivel" end
        if not stats then return false, "UIStats nao encontrado" end
        if not event then return false, "CombatEvent nao encontrado" end
        local now = os.clock()
        if now - (lastTraining[action] or -1000) < ctx.state.trainingInterval then
            return false, "Intervalo de treinamento"
        end
        lastTraining[action] = now
        local ok, err = pcall(function()
            event:FireServer({Character = char, Action = action, MiscData = stats})
        end)
        return ok, ok and "Treinamento enviado" or tostring(err)
    end
    ctx.combat = api
end

    end)()
    initialize(ctx)
end
-- END 04_combat.lua

-- BEGIN 05_farm.lua
do
    local initialize = (function()
-- Auto NPC e Auto Boss, exclusivos entre si e desligados por padrao.
return function(ctx)
    local api = {}
    local state = ctx.state
    local function chosen(mode)
        if mode == "npc" then return state.npcs[state.npcIndex] end
        return state.bosses[state.bossIndex]
    end

    function api.toggle(mode)
        if mode ~= "npc" and mode ~= "boss" then return end
        if ctx.combat and ctx.combat.resetCombo then ctx.combat.resetCombo() end
        if state.mode == mode then
            state.mode = "off"
            state.farmToken = state.farmToken + 1
            ctx.report("Auto " .. mode .. " desligado")
            if ctx.refresh then ctx.refresh() end
            return
        end
        state.mode = mode
        state.farmToken = state.farmToken + 1
        local token = state.farmToken
        ctx.report("Auto " .. mode .. " ligado: " .. chosen(mode))
        if ctx.refresh then ctx.refresh() end

        task.spawn(function()
            local lastNotice = 0
            while state.alive and state.mode == mode and state.farmToken == token do
                local ok, err = pcall(function()
                    local _, _, playerRoot = ctx.character.get()
                    if not playerRoot then return end
                    local name = chosen(mode)
                    local target, targetRoot = ctx.targets.find(name, playerRoot)
                    if not target or not targetRoot then
                        if os.clock() - lastNotice > 3 then
                            ctx.report("Procurando " .. name .. "...")
                            lastNotice = os.clock()
                        end
                        return
                    end
                    -- Movimento local experimental; o servidor pode reverter.
                    if (playerRoot.Position - targetRoot.Position).Magnitude > 8 then
                        playerRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
                    end
                    local success, reason = ctx.combat.attack(target)
                    if not success and os.clock() - lastNotice > 3 then
                        ctx.report(reason)
                        lastNotice = os.clock()
                    end
                end)
                if not ok and os.clock() - lastNotice > 3 then
                    ctx.report("Farm: " .. tostring(err):sub(1,65))
                    lastNotice = os.clock()
                end
                task.wait(state.attackInterval)
            end
        end)
    end
    ctx.farm = api
end

    end)()
    initialize(ctx)
end
-- END 05_farm.lua

-- BEGIN 06_stats.lua
do
    local initialize = (function()
-- Treino automatico experimental, sem ligacao automatica ao iniciar o Hub.
return function(ctx)
    local state = ctx.state
    local api = {}
    function api.toggle(action)
        if state.train[action] == nil then return end
        state.train[action] = not state.train[action]
        state.trainToken[action] = state.trainToken[action] + 1
        local token = state.trainToken[action]
        local enabled = state.train[action]
        if ctx.refresh then ctx.refresh() end
        ctx.report((enabled and "Treino ligado: " or "Treino desligado: ") .. action)
        if not enabled then return end

        task.spawn(function()
            local lastNotice = 0
            while state.alive and state.train[action] and state.trainToken[action] == token do
                local ok, success, message = pcall(ctx.combat.train, action)
                if (not ok or not success) and os.clock() - lastNotice > 3 then
                    ctx.report("Stats: " .. tostring(ok and message or success):sub(1,65))
                    lastNotice = os.clock()
                end
                task.wait(state.trainingInterval)
            end
        end)
    end
    ctx.stats = api
end

    end)()
    initialize(ctx)
end
-- END 06_stats.lua

-- BEGIN 07_respawn.lua
do
    local initialize = (function()
-- JJC Hub v1.6: hotbar CUSTOMIZADA de Jujutsu Chronicles.
-- So executa apos morte detectada + renascimento. Nao usa Backpack/EquipTool.
-- Nao inventa RemoteEvent de equipamento.
return function(ctx)
    local player, state = ctx.player, ctx.state
    local UIS = game:GetService("UserInputService")
    local api = {}
    local pending = false
    local generation = 0
    local diedConn, addedConn

    local function valid(character, humanoid, ticket)
        return state.alive and generation == ticket and player.Character == character
            and humanoid and humanoid.Parent == character and humanoid.Health > 0
    end

    local function vimService()
        local ok, obj = pcall(function() return game:GetService("VirtualInputManager") end)
        return ok and obj or nil
    end

    local function keyboardOne()
        local vim = vimService()
        if vim then
            local down = pcall(function()
                vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
            end)
            if down then
                task.wait(0.09)
                local up = pcall(function()
                    vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
                end)
                if up then return true, "Tecla virtual 1 enviada" end
            end
        end
        if type(keypress) == "function" and type(keyrelease) == "function" then
            local down = pcall(keypress, 0x31)
            if down then
                task.wait(0.09)
                if pcall(keyrelease, 0x31) then
                    return true, "Tecla 1 enviada pelo executor"
                end
            end
        end
        return false, "Executor nao disponibilizou envio de tecla"
    end

    local function visible(gui)
        local current = gui
        while current and current:IsA("GuiObject") do
            if not current.Visible then return false end
            current = current.Parent
        end
        return true
    end

    local function slotCandidate()
        local pg = player:FindFirstChildOfClass("PlayerGui")
        local camera = workspace.CurrentCamera
        if not pg or not camera then return nil end
        local screen = camera.ViewportSize
        local best, bestScore

        for _, item in ipairs(pg:GetDescendants()) do
            if item:IsA("GuiObject") and visible(item) then
                local name = item.Name:lower()
                local label = ""
                if item:IsA("TextLabel") or item:IsA("TextButton") then
                    label = item.Text:gsub("%s+", "")
                end
                local match = label == "1" or name == "1" or name == "slot1"
                    or name == "slot_1" or name == "hotbar1" or name == "item1"
                if match then
                    local pos, size = item.AbsolutePosition, item.AbsoluteSize
                    local cx, cy = pos.X + size.X / 2, pos.Y + size.Y / 2
                    -- Hotbar numerada mostrada na parte inferior das capturas.
                    if size.X > 0 and size.Y > 0 and cy >= screen.Y * 0.76
                        and cx >= 0 and cx <= screen.X * 0.65 then
                        local target = item
                        -- O texto "1" pode estar dentro de um Frame clicavel.
                        if not item:IsA("GuiButton") then
                            local parent = item.Parent
                            for _ = 1, 3 do
                                if not parent or not parent:IsA("GuiObject") then break end
                                if parent:IsA("GuiButton") then
                                    target = parent
                                    break
                                end
                                local ps = parent.AbsoluteSize
                                if ps.X >= 38 and ps.X <= screen.X * 0.25
                                    and ps.Y >= 35 and ps.Y <= screen.Y * 0.25 then
                                    target = parent
                                    break
                                end
                                parent = parent.Parent
                            end
                        end
                        local tp, ts = target.AbsolutePosition, target.AbsoluteSize
                        local tx, ty = tp.X + ts.X / 2, tp.Y + ts.Y / 2
                        if tx >= 0 and ty >= 0 and tx < screen.X and ty < screen.Y then
                            local score = (item:IsA("GuiButton") and 5 or 0)
                                + (target:IsA("GuiButton") and 10 or 0)
                                + (label == "1" and 4 or 0)
                                + (cy / screen.Y) * 5
                                - (cx / screen.X) * 4
                            if not bestScore or score > bestScore then
                                bestScore = score
                                best = {x = math.floor(tx), y = math.floor(ty), path = target:GetFullName()}
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function clickSlotOne(slot)
        local vim = vimService()
        if not vim then return false, "Toque virtual indisponivel" end
        local okDown = pcall(function()
            vim:SendMouseButtonEvent(slot.x, slot.y, 0, true, game, 0)
        end)
        if not okDown then return false, "Falha ao pressionar slot 1" end
        task.wait(0.08)
        local okUp = pcall(function()
            vim:SendMouseButtonEvent(slot.x, slot.y, 0, false, game, 0)
        end)
        if okUp then return true, "Toque enviado ao slot 1 da hotbar" end
        return false, "Falha ao soltar toque do slot 1"
    end

    -- Uma unica tentativa por renascimento: nao clica e tecla juntos, pois
    -- alguns jogos fazem equipar/desequipar ao receber o comando duas vezes.
    local function activateSlotOne()
        local slot = slotCandidate()
        if slot then
            local ok, msg = clickSlotOne(slot)
            if ok then return true, msg end
            local keyOK, keyMsg = keyboardOne()
            if keyOK then return true, keyMsg .. " (toque falhou)" end
            return false, msg .. "; " .. keyMsg
        end
        local ok, msg = keyboardOne()
        if ok then return true, msg .. " (botao 1 nao localizado)" end
        return false, "Slot 1 nao localizado na GUI; " .. msg
    end

    local function watchDeath(character)
        if diedConn then diedConn:Disconnect() diedConn = nil end
        local hum = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 8)
        if not state.alive or player.Character ~= character or not hum then return end
        if hum.Health <= 0 then pending = true end
        diedConn = hum.Died:Connect(function()
            if not state.alive then return end
            pending = true
            generation = generation + 1
            ctx.report("Morte detectada: slot 1 no proximo respawn")
        end)
    end

    local function onSpawn(character)
        local shouldActivate = pending
        pending = false
        generation = generation + 1
        local ticket = generation
        task.spawn(function() watchDeath(character) end)
        if not shouldActivate then return end
        task.spawn(function()
            local hum = character:FindFirstChildOfClass("Humanoid")
                or character:WaitForChild("Humanoid", 10)
            if not hum then return end
            task.wait(1.6)
            if not valid(character, hum, ticket) then return end
            local ok, message = activateSlotOne()
            if not valid(character, hum, ticket) then return end
            ctx.report((ok and "Slot 1: " or "Slot 1 falhou: ") .. message)
            -- 'Enviado' != o jogo ter equipado o item; diagnostico visual necessario.
        end)
    end

    addedConn = player.CharacterAdded:Connect(onSpawn)
    if player.Character then
        task.spawn(function() watchDeath(player.Character) end)
    end

    function api.inspect()
        local slot = slotCandidate()
        if slot then
            return "Hotbar 1 localizada na GUI (" .. slot.x .. "," .. slot.y .. ")"
        end
        return "Nao localizei botao 1 na GUI; sera usada a tecla 1"
    end
    function api.cleanup()
        generation = generation + 1
        pending = false
        if diedConn then diedConn:Disconnect() diedConn = nil end
        if addedConn then addedConn:Disconnect() addedConn = nil end
    end
    ctx.respawn = api
end

    end)()
    initialize(ctx)
end
-- END 07_respawn.lua

-- BEGIN 08_ui.lua
do
    local initialize = (function()
-- GUI movel/minimizavel + controle experimental de combo M1.
return function(ctx)
    local P = ctx.player
    local UIS = game:GetService("UserInputService")
    local roots = {}
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok and typeof(root) == "Instance" then table.insert(roots, root) end
    end
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and typeof(core) == "Instance" then table.insert(roots, core) end
    local pg = P:WaitForChild("PlayerGui", 8)
    if pg then table.insert(roots, pg) end

    local G = Instance.new("ScreenGui")
    G.Name = "JJC_Hub_v16"
    G.ResetOnSpawn = false
    G.DisplayOrder = 9999
    local mounted = false
    for _, root in ipairs(roots) do
        local ok = pcall(function()
            local old = root:FindFirstChild(G.Name)
            if old then old:Destroy() end
            G.Parent = root
        end)
        if ok and G.Parent == root then mounted = true break end
    end
    if not mounted then warn("[JJC v1.6] GUI sem parent acessivel") return end

    local function create(kind, parent, size, pos, bg, text)
        local o = Instance.new(kind)
        o.Size = size
        o.Position = pos
        o.BackgroundColor3 = bg
        o.BorderSizePixel = 0
        if o:IsA("TextLabel") or o:IsA("TextButton") then
            o.Text = text or ""
            o.TextColor3 = Color3.new(1, 1, 1)
            o.TextScaled = true
        end
        o.Parent = parent
        return o
    end

    local menu = create("Frame", G, UDim2.new(0, 330, .72, 0),
        UDim2.new(.5, -165, .21, 0), Color3.fromRGB(28, 35, 52))
    menu.Name = "MainWindow"
    menu.Active = true
    local fullSize = menu.Size
    local top = create("Frame", menu, UDim2.new(1, 0, 0, 44),
        UDim2.fromOffset(0, 0), Color3.fromRGB(35, 53, 77))
    top.Name = "DragBar"
    top.Active = true
    local title = create("TextLabel", top, UDim2.new(1, -50, 1, 0),
        UDim2.fromOffset(6, 0), Color3.fromRGB(35, 53, 77), "JJC HUB v1.6 | SEM KEY")
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Active = true
    local minimize = create("TextButton", top, UDim2.fromOffset(42, 36),
        UDim2.new(1, -44, 0, 4), Color3.fromRGB(47, 102, 140), "-")

    local status = create("TextLabel", menu, UDim2.new(1, -8, 0, 35),
        UDim2.new(0, 4, 1, -39), Color3.fromRGB(20, 95, 70), "JJC v1.6")
    status.TextWrapped = true
    local search = Instance.new("TextBox")
    search.Name = "SearchActions"
    search.Size = UDim2.new(1, -12, 0, 34)
    search.Position = UDim2.fromOffset(6, 46)
    search.BackgroundColor3 = Color3.fromRGB(40, 49, 67)
    search.BorderSizePixel = 0
    search.TextColor3 = Color3.fromRGB(255, 255, 255)
    search.PlaceholderText = "Pesquisar funcoes..."
    search.PlaceholderColor3 = Color3.fromRGB(180, 180, 190)
    search.ClearTextOnFocus = false
    search.Text = ""
    search.TextScaled = true
    search.Parent = menu
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Actions"
    scroll.Position = UDim2.fromOffset(4, 84)
    scroll.Size = UDim2.new(1, -8, 1, -126)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.CanvasSize = UDim2.fromOffset(0, 580)
    scroll.Parent = menu
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if scroll.Parent then
            scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
        end
    end)

    -- Arraste mouse/toque somente pela barra superior.
    local dragging, dragStart, windowStart, dragTouch = false, nil, nil, nil
    local dragConnections = {}
    local function startDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragStart = input.Position
        windowStart = menu.Position
        dragTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
        local endedConnection
        endedConnection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragTouch = nil
                endedConnection:Disconnect()
            end
        end)
        table.insert(dragConnections, endedConnection)
    end
    top.InputBegan:Connect(startDrag)
    title.InputBegan:Connect(startDrag)
    local moveConnection = UIS.InputChanged:Connect(function(input)
        if not dragging or not dragStart or not windowStart then return end
        if dragTouch then
            if input ~= dragTouch then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local delta = input.Position - dragStart
        menu.Position = UDim2.new(windowStart.X.Scale, windowStart.X.Offset + delta.X,
            windowStart.Y.Scale, windowStart.Y.Offset + delta.Y)
    end)

    local minimized = false
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        scroll.Visible = not minimized
        search.Visible = not minimized
        status.Visible = not minimized
        menu.Size = minimized and UDim2.fromOffset(330, 44) or fullSize
        minimize.Text = minimized and "+" or "-"
    end)

    local actionButtons = {}
    local function applySearch()
        local q = search.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
        for _, b in ipairs(actionButtons) do
            b.Visible = q == "" or b.Text:lower():find(q, 1, true) ~= nil
        end
    end
    search:GetPropertyChangedSignal("Text"):Connect(applySearch)
    local function button(name, callback)
        local b = create("TextButton", scroll, UDim2.new(1, -12, 0, 43),
            UDim2.fromOffset(3, 0), Color3.fromRGB(47, 102, 140), name)
        table.insert(actionButtons, b)
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(callback)
            if not ok then
                status.BackgroundColor3 = Color3.fromRGB(145, 40, 45)
                ctx.report("ERRO: " .. tostring(err):sub(1, 80))
            end
        end)
        return b
    end

    local npcChoice = button("NPC: " .. ctx.state.npcs[ctx.state.npcIndex], function()
        ctx.state.npcIndex = ctx.state.npcIndex % #ctx.state.npcs + 1
        ctx.refresh()
    end)
    local farmToggle = button("LIGAR AUTO FARM", function() ctx.farm.toggle("npc") end)
    local bossChoice = button("BOSS: " .. ctx.state.bosses[ctx.state.bossIndex], function()
        ctx.state.bossIndex = ctx.state.bossIndex % #ctx.state.bosses + 1
        ctx.refresh()
    end)
    local bossToggle = button("LIGAR AUTO BOSS", function() ctx.farm.toggle("boss") end)
    local comboToggle = button("COMBO M1: 1-4 (TESTE)", function()
        local state = ctx.state
        state.comboMode = state.comboMode == "sequence" and "fixed" or "sequence"
        if ctx.combat and ctx.combat.resetCombo then ctx.combat.resetCombo() end
        ctx.refresh()
        ctx.report(state.comboMode == "sequence" and "Combo 1-4 experimental ativo" or "Combo fixo 1 restaurado")
    end)
    local endurance = button("LIGAR AUTO STATS - ENDURANCE", function() ctx.stats.toggle("Endurance") end)
    local energy = button("LIGAR AUTO STATS - CURSED ENERGY", function() ctx.stats.toggle("Cursed_Energy") end)
    button("VERIFICAR SLOT 1 (SEM ATIVAR)", function()
        ctx.report(ctx.respawn.inspect())
    end)
    button("VERIFICAR COMBAT EVENT", function()
        ctx.report(ctx.combat.available() and "CombatEvent encontrado" or "CombatEvent nao encontrado")
    end)
    button("DESLIGAR TUDO", function() ctx.stopAll() end)
    button("FECHAR GUI", function() ctx.close() end)

    ctx.refresh = function()
        if not G.Parent then return end
        local state = ctx.state
        npcChoice.Text = "NPC: " .. state.npcs[state.npcIndex]
        bossChoice.Text = "BOSS: " .. state.bosses[state.bossIndex]
        farmToggle.Text = state.mode == "npc" and "PARAR AUTO FARM" or "LIGAR AUTO FARM"
        bossToggle.Text = state.mode == "boss" and "PARAR AUTO BOSS" or "LIGAR AUTO BOSS"
        comboToggle.Text = state.comboMode == "sequence" and "COMBO M1: 1-4 (TESTE)" or "COMBO M1: 1 FIXO"
        endurance.Text = state.train.Endurance and "PARAR STATS - ENDURANCE" or "LIGAR STATS - ENDURANCE"
        energy.Text = state.train.Cursed_Energy and "PARAR STATS - CURSED ENERGY" or "LIGAR STATS - CURSED ENERGY"
        applySearch()
    end
    ctx.report = function(message)
        if not ctx.state.alive then return end
        local text = tostring(message):sub(1, 95)
        ctx.state.lastMessage = text
        if status.Parent then
            status.Text = text
            status.BackgroundColor3 = Color3.fromRGB(20, 95, 70)
        end
        print("[JJC v1.6] " .. text)
    end
    ctx.close = function()
        if not ctx.state.alive then return end
        ctx.stopAll()
        ctx.state.alive = false
        if ctx.respawn and ctx.respawn.cleanup then ctx.respawn.cleanup() end
        if moveConnection then moveConnection:Disconnect() end
        for _, conn in ipairs(dragConnections) do pcall(function() conn:Disconnect() end) end
        if G.Parent then G:Destroy() end
    end
    ctx.refresh()
    ctx.report("JJC v1.6 pronto. Slot 1 usa a hotbar personalizada apos morte.")
end

    end)()
    initialize(ctx)
end
-- END 08_ui.lua

if type(ctx.close) == "function" then
    env.JJC_HUB_V16_CLOSE = ctx.close
end
