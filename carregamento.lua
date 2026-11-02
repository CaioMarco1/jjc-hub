-- JJC Hub v1.5 | arquivo integrado | sem key
-- O arquivo nao acessa redes nem baixa outras bibliotecas.
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then warn("[JJC v1.5] LocalPlayer nao encontrado") return end
local env = _G
if type(getgenv) == "function" then
    local ok, external = pcall(getgenv)
    if ok and type(external) == "table" then env = external end
end
for _, k in ipairs({"JJC_HUB_V15_CLOSE","JJC_HUB_V14_CLOSE","JJC_HUB_V13_CLOSE","JJC_HUB_V12_CLOSE","JJC_HUB_V11_CLOSE","JJC_HUB_V10_CLOSE"}) do
    if type(env[k]) == "function" then pcall(env[k]) end
end
local ctx = {player = LocalPlayer}

-- BEGIN 01_state.lua
do
    local initialize = (function()
-- Estado compartilhado JJC Hub v1.5.
return function(ctx)
    local s = {
        alive = true, mode = "off", farmToken = 0,
        npcIndex = 1, bossIndex = 1,
        npcs = {"Dummy", "FlyHead", "Froggy", "Sorcerer"},
        bosses = {"Choso", "Sukuna", "UltSukuna", "Meguna", "TheStrongest",
                  "Mahoraga", "Kashimo", "Kechizu", "LoveSorcerer", "Dabura"},
        selectedBosses = {}, queue = {}, queueIndex = 1, queueName = nil,
        queueTarget = nil, queueWaitStart = 0, missingBossWait = 6,
        attackInterval = 0.10, trainingInterval = 1.75,
        weaponName = "Inverted Spear of Heaven", autoEquip = true,
        train = {Endurance = false, Cursed_Energy = false},
        trainToken = {Endurance = 0, Cursed_Energy = 0}, lastMessage = ""
    }
    ctx.state = s
    ctx.report = function(msg)
        if not s.alive then return end
        s.lastMessage = tostring(msg)
        print("[JJC v1.5] " .. s.lastMessage)
    end
    ctx.stopAll = function()
        s.mode = "off"
        s.farmToken = s.farmToken + 1
        s.queueTarget, s.queueName = nil, nil
        for action in pairs(s.train) do
            s.train[action] = false
            s.trainToken[action] = s.trainToken[action] + 1
        end
        s.autoEquip = false
        if ctx.refresh then ctx.refresh() end
        ctx.report("Automacoes interrompidas (incluindo autoequip)")
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
-- Intervalo de M1 de 0.10s; o servidor pode limitar a cadencia.
-- O servidor pode rejeitar a acao; nao significa dano ou treino confirmado.
return function(ctx)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local api = {}
    local lastAttack, lastTraining = -1000, {}
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
        lastAttack = now
        local ok, err = pcall(function()
            event:FireServer({
                Character = char,
                Action = "M1",
                Combo = 1,
                Target = target,
                BehindPlayer = false
            })
        end)
        return ok, ok and "Ataque enviado" or tostring(err)
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
-- Farm simples e fila sequencial de bosses (apenas UM alvo em foco).
return function(ctx)
    local s = ctx.state
    local api = {}

    function api.selectedList()
        local list = {}
        for _, name in ipairs(s.bosses) do
            if s.selectedBosses[name] then table.insert(list, name) end
        end
        return list
    end

    function api.selectBoss(name)
        if s.mode == "bossQueue" then
            ctx.report("Pare a FILA para alterar a selecao")
            return
        end
        s.selectedBosses[name] = not s.selectedBosses[name]
        if ctx.refresh then ctx.refresh() end
        ctx.report(name .. (s.selectedBosses[name] and " selecionado" or " removido"))
    end

    local function stepAttack(target, targetRoot, playerRoot)
        if not targetRoot or not targetRoot.Parent or not playerRoot then return end
        -- Deslocamento local; o servidor pode desfazer o movimento.
        if (playerRoot.Position - targetRoot.Position).Magnitude > 8 then
            playerRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
        end
        if ctx.equipment and ctx.state.autoEquip then ctx.equipment.ensure(false) end
        ctx.combat.attack(target)
    end

    local function nextInQueue(reason)
        local q = s.queue
        if #q == 0 then return end
        local old = s.queueName or q[s.queueIndex]
        s.queueIndex = (s.queueIndex % #q) + 1
        s.queueName, s.queueTarget = nil, nil
        s.queueWaitStart = os.clock()
        ctx.report(reason .. " " .. tostring(old) .. " > proximo: " .. q[s.queueIndex])
        if ctx.refresh then ctx.refresh() end
    end

    local function stepQueue(playerRoot)
        local q = s.queue
        if #q == 0 then return end
        local name = q[s.queueIndex]
        if s.queueName ~= name then
            s.queueName = name
            s.queueTarget = nil
            s.queueWaitStart = os.clock()
            ctx.report("Fila " .. s.queueIndex .. "/" .. #q .. ": " .. name)
            if ctx.refresh then ctx.refresh() end
        end

        -- Se ja travamos um boss, nao trocamos de alvo enquanto estiver vivo.
        local current = s.queueTarget
        if current then
            local hum = current:FindFirstChildOfClass("Humanoid")
            if not current.Parent or not hum or hum.Health <= 0 then
                nextInQueue("Derrotado/removido:")
                return
            end
            local targetRoot = current:FindFirstChild("HumanoidRootPart")
            if targetRoot then stepAttack(current, targetRoot, playerRoot) end
            return
        end

        -- Busca um unico modelo do boss atual. Nao ataca outro boss em paralelo.
        local target, targetRoot = ctx.targets.find(name, playerRoot)
        if target then
            s.queueTarget = target
            ctx.report("Foco exclusivo: " .. name .. " (" .. s.queueIndex .. "/" .. #q .. ")")
            stepAttack(target, targetRoot, playerRoot)
        elseif os.clock() - s.queueWaitStart >= s.missingBossWait then
            -- Caso nao tenha spawnado, pula para nao bloquear a fila inteira.
            nextInQueue("Nao encontrado:")
        end
    end

    function api.toggle(mode)
        if mode ~= "npc" and mode ~= "boss" and mode ~= "bossQueue" then return end
        if s.mode == mode then
            s.mode = "off"
            s.farmToken = s.farmToken + 1
            s.queueTarget, s.queueName = nil, nil
            ctx.report("Farm desligado: " .. mode)
            if ctx.refresh then ctx.refresh() end
            return
        end
        local queue = nil
        if mode == "bossQueue" then
            queue = api.selectedList()
            if #queue == 0 then
                ctx.report("Selecione pelo menos um boss para a FILA")
                return
            end
        end
        s.mode = mode
        s.farmToken = s.farmToken + 1
        s.queueTarget, s.queueName = nil, nil
        if queue then
            s.queue = queue
            s.queueIndex = 1
            s.queueWaitStart = os.clock()
        end
        local token = s.farmToken
        if ctx.equipment and s.autoEquip then ctx.equipment.ensure(true) end
        ctx.report("Ligado: " .. mode)
        if ctx.refresh then ctx.refresh() end

        task.spawn(function()
            local lastNotice = 0
            while s.alive and s.mode == mode and s.farmToken == token do
                local ok, err = pcall(function()
                    local _, _, root = ctx.character.get()
                    if not root then return end
                    if mode == "bossQueue" then
                        stepQueue(root)
                    else
                        local name = mode == "npc" and s.npcs[s.npcIndex] or s.bosses[s.bossIndex]
                        local target, targetRoot = ctx.targets.find(name, root)
                        if target and targetRoot then
                            stepAttack(target, targetRoot, root)
                        elseif os.clock() - lastNotice > 4 then
                            ctx.report("Procurando " .. name .. "...")
                            lastNotice = os.clock()
                        end
                    end
                end)
                if not ok and os.clock() - lastNotice > 3 then
                    ctx.report("Farm: " .. tostring(err):sub(1, 75))
                    lastNotice = os.clock()
                end
                task.wait(s.attackInterval)
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

-- BEGIN 07_equipment.lua
do
    local initialize = (function()
-- Equipa somente Tools presentes na Backpack ou no Character locais.
-- Nao forja itens nem executa requisicoes remotas.
return function(ctx)
    local player, state = ctx.player, ctx.state
    local api, connections = {}, {}
    local lastCheck, lastNotice = -100, -100
    local function backpack()
        return player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
    end
    local function findTool(name)
        if not name then return nil end
        local ch, bp = player.Character, backpack()
        for _, container in ipairs({ch, bp}) do
            if container then
                local obj = container:FindFirstChild(name)
                if obj and obj:IsA("Tool") then return obj end
            end
        end
        -- Fallback limitado: ignora apenas maiusculas/minusculas.
        for _, container in ipairs({ch, bp}) do
            if container then
                for _, obj in ipairs(container:GetChildren()) do
                    if obj:IsA("Tool") and obj.Name:lower() == name:lower() then
                        return obj
                    end
                end
            end
        end
        return nil
    end
    -- Ativa a tecla 1 uma vez por personagem. Em algumas versoes do Delta
    -- o envio de teclas nao esta disponivel; nesse caso usamos EquipTool.
    local keyUsedFor = nil
    local slotReadyAt = os.clock() + 0.9
    local function pressOne()
        -- Primeiro tente a API de input; execucao protegida para compatibilidade.
        local ok, sent = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            if not vim then return false end
            vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
            task.wait(0.06)
            vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            return true
        end)
        if ok and sent then return true end

        -- Alternativa disponivel em alguns executores, nao em todos.
        local scope = _G
        if type(getgenv) == "function" then
            local okEnv, env = pcall(getgenv)
            if okEnv and type(env) == "table" then scope = env end
        end
        local press = scope.keypress or keypress
        local release = scope.keyrelease or keyrelease
        if type(press) == "function" then
            local pressed = pcall(press, 0x31) -- VK_1
            if pressed then
                if type(release) == "function" then
                    task.wait(0.06)
                    pcall(release, 0x31)
                end
                return true
            end
        end
        return false
    end
    local function trySlotOnce(ch, force)
        if state.weaponName ~= "Inverted Spear of Heaven" then return false end
        if not force and (keyUsedFor == ch or os.clock() < slotReadyAt) then
            return keyUsedFor == ch
        end
        local ok = pressOne()
        if ok then
            keyUsedFor = ch
            ctx.report("Atalho 1 enviado (Inverted Spear of Heaven)")
            return true
        end
        if os.clock() - lastNotice > 8 then
            lastNotice = os.clock()
            ctx.report("Delta sem tecla 1 virtual; tentando equipar Tool")
        end
        return false
    end
    function api.list()
        local names, list = {}, {}
        local function scan(container)
            if not container then return end
            for _, object in ipairs(container:GetChildren()) do
                if object:IsA("Tool") and not names[object.Name] then
                    names[object.Name] = true
                    table.insert(list, object.Name)
                end
            end
        end
        scan(backpack())
        scan(player.Character)
        table.sort(list)
        return list
    end
    function api.chooseNext()
        local list = api.list()
        if #list == 0 then
            ctx.report("Nenhuma arma Tool na mochila/personagem")
            return
        end
        local pos = 0
        for i, name in ipairs(list) do
            if state.weaponName == name then pos = i break end
        end
        state.weaponName = list[pos % #list + 1]
        if ctx.refresh then ctx.refresh() end
        ctx.report("Arma selecionada: " .. state.weaponName)
        if state.autoEquip then api.ensure(true) end
    end
    function api.ensure(force)
        if not state.alive then return false end
        if not force and not state.autoEquip then return false end
        local now = os.clock()
        if not force and now - lastCheck < 1.5 then return false end
        lastCheck = now
        local name = state.weaponName
        if not name or name == "" then return false end
        local ch = player.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local tool = findTool(name)
        -- Nao pressionar 1 se ja estiver equipada: em alguns jogos isso desequipa.
        if tool and tool.Parent == ch then return true end
        -- Deixe o slot 1 reconstruir depois do spawn antes de equipar.
        if name == "Inverted Spear of Heaven" and force ~= "slot" and now < slotReadyAt then
            return false
        end

        -- Para a arma favorita, a tecla 1 e a acao de equipamento do jogo.
        -- Uma tentativa por personagem; a proxima so ocorre depois de renascer
        -- ou quando o usuario solicita manualmente.
        local slotSent = trySlotOnce(ch, force == "slot")
        if tool and tool.Parent == ch then return true end

        -- Fallback para a Backpack padrao do Roblox.
        if tool and tool.Parent ~= ch then
            local ok, err = pcall(function() hum:EquipTool(tool) end)
            if ok and tool.Parent == ch then
                ctx.report("Arma equipada: " .. name)
                return true
            end
            if now - lastNotice > 8 then
                lastNotice = now
                ctx.report("EquipTool nao confirmou: " .. tostring(err):sub(1, 60))
            end
        end
        if slotSent or (name == "Inverted Spear of Heaven" and keyUsedFor == ch) then
            return true -- tecla enviada, nao ha confirmacao de equipamento no servidor
        end
        if now - lastNotice > 8 then
            lastNotice = now
            ctx.report("Aguardando arma/slot 1 no inventario: " .. name)
        end
        return false
    end
    function api.pressSlot1()
        local ch = player.Character
        if not ch then return false end
        -- Forcar a tecla 1 apenas por solicitacao direta do usuario.
        if state.weaponName ~= "Inverted Spear of Heaven" then
            state.weaponName = "Inverted Spear of Heaven"
        end
        if ctx.refresh then ctx.refresh() end
        local tool = findTool(state.weaponName)
        if tool and tool.Parent == ch then
            ctx.report("Inverted Spear ja esta equipada")
            return true
        end
        return api.ensure("slot")
    end
    function api.usePreferred()
        state.weaponName = "Inverted Spear of Heaven"
        state.autoEquip = true
        if ctx.refresh then ctx.refresh() end
        ctx.report("Preferencia ativa: Inverted Spear of Heaven")
        keyUsedFor = nil
        return api.ensure(true)
    end
    function api.toggle()
        if not state.autoEquip and not state.weaponName then
            ctx.report("Selecione uma arma antes de ativar")
            return
        end
        state.autoEquip = not state.autoEquip
        if ctx.refresh then ctx.refresh() end
        ctx.report(state.autoEquip and "Autoequip ligado" or "Autoequip desligado")
        if state.autoEquip then
            keyUsedFor = nil
            api.ensure(true)
        end
    end
    local function connect(signal, callback)
        table.insert(connections, signal:Connect(callback))
    end
    local function delayedEnsure()
        if not state.autoEquip then return end
        task.defer(function()
            if state.alive then api.ensure(true) end
        end)
    end
    local function watchCharacter(character)
        connect(character.ChildAdded, function(child)
            if child:IsA("Tool") then delayedEnsure() end
        end)
    end
    connect(player.CharacterAdded, function(character)
        keyUsedFor = nil
        slotReadyAt = os.clock() + 1.0
        watchCharacter(character)
        -- Aguarda o inventario e a barra rapida serem refeitos pelo jogo.
        task.spawn(function()
            task.wait(1.2)
            if state.alive and state.autoEquip and player.Character == character then
                api.ensure(true)
            end
        end)
    end)
    if player.Character then watchCharacter(player.Character) end
    local bp = backpack()
    if bp then
        connect(bp.ChildAdded, function(child)
            if child:IsA("Tool") then delayedEnsure() end
        end)
    end
    -- Backup periodico para casos em que a mochila reaparece depois do respawn.
    task.spawn(function()
        while state.alive do
            if state.autoEquip then pcall(api.ensure, false) end
            task.wait(1.5)
        end
    end)
    function api.shutdown()
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
    end
    ctx.equipment = api
    -- Faz a primeira tentativa sem aguardar o ciclo de 1,5s.
    if state.autoEquip then
        task.spawn(function()
            task.wait(1.0)
            if state.alive then api.ensure(true) end
        end)
    end
end

    end)()
    initialize(ctx)
end
-- END 07_equipment.lua

-- BEGIN 08_ui.lua
do
    local initialize = (function()
-- GUI baseada na v0.8/v1.0: arrastavel (mouse/toque), minimizavel.
return function(ctx)
    local p = ctx.player
    local roots = {}
    if type(gethui) == "function" then
        local ok, g = pcall(gethui)
        if ok and typeof(g) == "Instance" then table.insert(roots, g) end
    end
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and typeof(core) == "Instance" then table.insert(roots, core) end
    local pg = p:WaitForChild("PlayerGui", 8)
    if pg then table.insert(roots, pg) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "JJC_Hub_v15"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 9999
    local mounted = false
    for _, root in ipairs(roots) do
        local ok = pcall(function()
            local old = root:FindFirstChild(gui.Name)
            if old then old:Destroy() end
            gui.Parent = root
        end)
        if ok and gui.Parent == root then mounted = true break end
    end
    if not mounted then warn("[JJC v1.5] Sem raiz de GUI") return end

    local function create(kind, parent, size, pos, bg, value)
        local obj = Instance.new(kind)
        obj.Size = size
        obj.Position = pos
        obj.BackgroundColor3 = bg
        obj.BorderSizePixel = 0
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            obj.Text = value or ""
            obj.TextColor3 = Color3.new(1,1,1)
            obj.TextScaled = true
        end
        obj.Parent = parent
        return obj
    end

    local conns = {}
    local function track(c) table.insert(conns,c) return c end
    local fullSize = UDim2.new(0, 332, .72, 0)
    local menu = create("Frame", gui, fullSize,
        UDim2.new(.5,-166,.19,0), Color3.fromRGB(28,35,52))
    menu.Name = "Menu"
    menu.Active = true
    menu.ClipsDescendants = true
    local header = create("Frame",menu,UDim2.new(1,0,0,42),
        UDim2.fromOffset(0,0), Color3.fromRGB(35,53,77))
    header.Active = true
    local title = create("TextLabel",header,UDim2.new(1,-49,1,0),
        UDim2.fromOffset(7,0),Color3.fromRGB(35,53,77), "JJC HUB v1.5 | SEM KEY")
    title.BackgroundTransparency = 1
    title.Active = true
    local min = create("TextButton",header,UDim2.fromOffset(35,33),
        UDim2.new(1,-40,0,4),Color3.fromRGB(66,98,130),"-")

    local status = create("TextLabel",menu,UDim2.new(1,-12,0,48),
        UDim2.fromOffset(6,46),Color3.fromRGB(20,95,70),"INICIANDO...")
    status.TextWrapped = true
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Actions"
    scroll.Position = UDim2.fromOffset(4,99)
    scroll.Size = UDim2.new(1,-8,1,-103)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.fromOffset(0,900)
    scroll.Parent = menu
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+15)
    end))
    local function button(label,fn)
        local b = create("TextButton",scroll,UDim2.new(1,-12,0,40),
            UDim2.fromOffset(3,0),Color3.fromRGB(47,102,140),label)
        track(b.MouseButton1Click:Connect(function()
            local ok,err = pcall(fn)
            if not ok then ctx.report("ERRO: "..tostring(err):sub(1,80)) end
        end))
        return b
    end
    local function heading(text)
        local h = create("TextLabel",scroll,UDim2.new(1,-12,0,28),
            UDim2.fromOffset(3,0),Color3.fromRGB(43,58,81),text)
        return h
    end

    heading("AUTO FARM / NPC")
    local npc = button("NPC",function()
        ctx.state.npcIndex = ctx.state.npcIndex % #ctx.state.npcs + 1
        ctx.refresh()
    end)
    local npcToggle = button("LIGAR AUTO FARM",function() ctx.farm.toggle("npc") end)
    heading("BOSS UNICO")
    local boss = button("BOSS",function()
        ctx.state.bossIndex = ctx.state.bossIndex % #ctx.state.bosses + 1
        ctx.refresh()
    end)
    local bossToggle = button("LIGAR AUTO BOSS",function() ctx.farm.toggle("boss") end)

    heading("FILA MULTI-BOSS (SELECIONE ABAIXO)")
    local selectedButtons = {}
    for _,bossName in ipairs(ctx.state.bosses) do
        local name = bossName
        selectedButtons[name] = button("[ ] " .. name,function()
            ctx.farm.selectBoss(name)
        end)
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
-- END 08_ui.lua

if type(ctx.close) == "function" then env.JJC_HUB_V15_CLOSE = ctx.close end
