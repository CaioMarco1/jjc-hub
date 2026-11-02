-- JJC: teste simples de exibição em diferentes raízes de interface
-- Sem rede, sem farm, sem modificações no jogo.
print("[JJC TESTE] Script comecou a executar")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
assert(player, "LocalPlayer nao encontrado")
local containers = {}
if type(gethui) == "function" then
    local ok, guiParent = pcall(gethui)
    if ok and typeof(guiParent) == "Instance" then
        table.insert(containers, {name = "gethui", ref = guiParent})
    end
end
local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
if okCore and typeof(coreGui) == "Instance" then
    table.insert(containers, {name = "CoreGui", ref = coreGui})
end
local playerGui = player:WaitForChild("PlayerGui", 10)
if playerGui then table.insert(containers, {name = "PlayerGui", ref = playerGui}) end

local screen = Instance.new("ScreenGui")
screen.Name = "JJC_Teste_GUI_v03"
screen.ResetOnSpawn = false
screen.DisplayOrder = 9999
local display = Instance.new("TextLabel")
display.Size = UDim2.fromOffset(330, 85)
display.Position = UDim2.new(0.5, -165, 0.2, 0)
display.BackgroundColor3 = Color3.fromRGB(20, 90, 65)
display.TextColor3 = Color3.new(1,1,1)
display.TextScaled = true
display.Text = "JJC - Interface v0.3 OK"
display.Parent = screen

local chosen = nil
for _, candidate in ipairs(containers) do
    local ok, err = pcall(function()
        local old = candidate.ref:FindFirstChild(screen.Name)
        if old then old:Destroy() end
        screen.Parent = candidate.ref
    end)
    if ok and screen.Parent == candidate.ref then
        chosen = candidate.name
        break
    end
    warn("[JJC TESTE] Falha em " .. candidate.name .. ": " .. tostring(err))
end
assert(chosen, "Nenhuma raiz de interface aceitou o ScreenGui")
print("[JJC TESTE] Interface criada em " .. chosen)

-- JJC v0.7: conserva o codigo de interface que funcionou na v0.6.
-- NOVO: verificar informacoes locais do personagem e existencia de eventos.
-- NAO envia ataques, nao muda posicao e nao faz requisicoes HTTP.
display.Text = "JJC v0.7 - BASE FUNCIONOU"
local success, failure = pcall(function()
    local panel = Instance.new("Frame")
    panel.Name = "JJC_Menu_v07"
    panel.Size = UDim2.fromOffset(320, 286)
    panel.Position = UDim2.new(0.5, -160, 0.36, 0)
    panel.BackgroundColor3 = Color3.fromRGB(28, 35, 52)
    panel.Parent = screen

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Text = "JJC HUB v0.7 - SEM KEY"
    title.Parent = panel

    local function addButton(label, y, callback, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.90, 0, 0, 44)
        b.Position = UDim2.new(0.05, 0, 0, y)
        b.BackgroundColor3 = color or Color3.fromRGB(50, 105, 140)
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextScaled = true
        b.Text = label
        b.Parent = panel
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(callback)
            if not ok then
                display.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
                display.Text = "ERRO: " .. tostring(err):sub(1, 80)
            end
        end)
        return b
    end

    addButton("TESTAR BOTAO", 45, function()
        display.Text = "BOTAO OK: " .. player.Name
    end)

    addButton("VERIFICAR PERSONAGEM", 101, function()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            display.Text = "PERSONAGEM: Humanoid nao encontrado"
            return
        end
        display.Text = "VIDA: " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
    end)

    addButton("VERIFICAR EVENTO", 157, function()
        local replicated = game:GetService("ReplicatedStorage")
        local events = replicated:FindFirstChild("Events")
        local remote = events and events:FindFirstChild("CombatEvent")
        if remote then
            display.Text = "CombatEvent encontrado (" .. remote.ClassName .. ")"
        else
            display.Text = "CombatEvent nao encontrado no cliente"
        end
    end)

    addButton("FECHAR", 213, function()
        screen:Destroy()
    end, Color3.fromRGB(107, 52, 65))
end)

if success then
    display.Text = "JJC v0.7 - MENU CRIADO"
else
    display.Text = "JJC v0.7 - ERRO: " .. tostring(failure):sub(1, 90)
    display.BackgroundColor3 = Color3.fromRGB(145, 36, 36)
end
