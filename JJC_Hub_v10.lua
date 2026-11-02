-- JJC Hub v1.0 | Build integrado de modulos locais (sem key)
-- Este arquivo nao carrega bibliotecas ou modulos remotos.
-- Auto Farm, Auto Boss e Auto Stats sao experimentais e ficam desligados por padrao.
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then warn("[JJC] LocalPlayer nao encontrado") return end
local env = _G
if type(getgenv) == "function" then
    local ok, e = pcall(getgenv)
    if ok and type(e) == "table" then env = e end
end
if type(env.JJC_HUB_V10_CLOSE) == "function" then pcall(env.JJC_HUB_V10_CLOSE) end
local ctx = {player = LocalPlayer}

-- BEGIN 01_state.lua
do
    local initialize = (function()
-- Estado e configuracoes globais do JJC Hub v1.0
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
        attackInterval = 0.85,
        trainingInterval = 1.75,
        lastMessage = ""
    }
    ctx.state = state
    ctx.report = function(message)
        if not state.alive then return end
        state.lastMessage = tostring(message)
        print("[JJC v1.0] " .. state.lastMessage)
    end
    ctx.stopAll = function()
        state.mode = "off"
        state.farmToken = state.farmToken + 1
        for action in pairs(state.train) do
            state.train[action] = false
            state.trainToken[action] = state.trainToken[action] + 1
        end
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

-- BEGIN 07_ui.lua
do
    local initialize = (function()
-- Interface v1.0: preserva o mesmo mecanismo de criacao e montagem da v0.8.
return function(ctx)
    local P = ctx.player
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
    G.Name = "JJC_Hub_v10"
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
    if not mounted then warn("[JJC v1.0] GUI sem parent acessivel") return end

    -- Mesma funcao create que funcionou na v0.8.
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

    local status = create("TextLabel", G, UDim2.fromOffset(330, 50),
        UDim2.new(.5, -165, .14, 0), Color3.fromRGB(20, 95, 70), "JJC v1.0 - INICIADO")
    status.TextWrapped = true
    local menu = create("Frame", G, UDim2.new(0, 330, .72, 0),
        UDim2.new(.5, -165, .25, 0), Color3.fromRGB(28, 35, 52))
    create("TextLabel", menu, UDim2.new(1, 0, 0, 42),
        UDim2.fromOffset(0, 0), Color3.fromRGB(35, 53, 77), "JJC HUB v1.0 | SEM KEY")

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Actions"
    scroll.Position = UDim2.fromOffset(4, 46)
    scroll.Size = UDim2.new(1, -8, 1, -50)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.CanvasSize = UDim2.fromOffset(0, 600)
    scroll.Parent = menu
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
    end)

    local function button(name, callback)
        local b = create("TextButton", scroll, UDim2.new(1, -12, 0, 43),
            UDim2.fromOffset(3, 0), Color3.fromRGB(47, 102, 140), name)
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
    local endurance = button("LIGAR AUTO STATS - ENDURANCE", function() ctx.stats.toggle("Endurance") end)
    local energy = button("LIGAR AUTO STATS - CURSED ENERGY", function() ctx.stats.toggle("Cursed_Energy") end)
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
        endurance.Text = state.train.Endurance and "PARAR STATS - ENDURANCE" or "LIGAR STATS - ENDURANCE"
        energy.Text = state.train.Cursed_Energy and "PARAR STATS - CURSED ENERGY" or "LIGAR STATS - CURSED ENERGY"
    end
    ctx.report = function(message)
        if not ctx.state.alive then return end
        local text = tostring(message):sub(1, 95)
        ctx.state.lastMessage = text
        if status.Parent then
            status.Text = text
            status.BackgroundColor3 = Color3.fromRGB(20, 95, 70)
        end
        print("[JJC v1.0] " .. text)
    end
    ctx.close = function()
        if not ctx.state.alive then return end
        ctx.stopAll()
        ctx.state.alive = false
        if G.Parent then G:Destroy() end
    end
    ctx.refresh()
    ctx.report("JJC v1.0 pronto. As automacoes iniciam desligadas.")
end

    end)()
    initialize(ctx)
end
-- END 07_ui.lua

if type(ctx.close) == "function" then
    env.JJC_HUB_V10_CLOSE = ctx.close
end
