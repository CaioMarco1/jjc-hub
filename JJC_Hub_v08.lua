-- JJC Hub Compacto v0.8 | Sem key e sem downloads externos
-- Verificacoes locais: interface, personagem e CombatEvent
local P=game:GetService("Players").LocalPlayer
if not P then return end
local roots={}
if type(gethui)=="function" then
    local ok,r=pcall(gethui)
    if ok and typeof(r)=="Instance" then table.insert(roots,r) end
end
local okCore,core=pcall(function() return game:GetService("CoreGui") end)
if okCore and typeof(core)=="Instance" then table.insert(roots,core) end
local pg=P:WaitForChild("PlayerGui",8)
if pg then table.insert(roots,pg) end
local G=Instance.new("ScreenGui")
G.Name="JJC_Hub_Compacto_v08"
G.ResetOnSpawn=false
G.DisplayOrder=9999
local mounted=false
for _,r in ipairs(roots) do
    local ok=pcall(function()
        local old=r:FindFirstChild(G.Name)
        if old then old:Destroy() end
        G.Parent=r
    end)
    if ok and G.Parent==r then mounted=true break end
end
if not mounted then warn("[JJC] GUI sem parent acessivel") return end
local function create(kind,parent,size,pos,bg,txt)
    local o=Instance.new(kind)
    o.Size=size
    o.Position=pos
    o.BackgroundColor3=bg
    o.BorderSizePixel=0
    if o:IsA("TextLabel") or o:IsA("TextButton") then
        o.Text=txt or ""
        o.TextColor3=Color3.new(1,1,1)
        o.TextScaled=true
    end
    o.Parent=parent
    return o
end
local status=create("TextLabel",G,UDim2.fromOffset(310,55),UDim2.new(.5,-155,.18,0),Color3.fromRGB(20,95,70),"JJC v0.8 - INICIADO")
local menu=create("Frame",G,UDim2.fromOffset(320,275),UDim2.new(.5,-160,.32,0),Color3.fromRGB(28,35,52))
create("TextLabel",menu,UDim2.new(1,0,0,42),UDim2.fromOffset(0,0),Color3.fromRGB(35,53,77),"JJC HUB v0.8 | SEM KEY")
local function button(txt,y,fn)
    local b=create("TextButton",menu,UDim2.new(.9,0,0,44),UDim2.new(.05,0,0,y),Color3.fromRGB(47,102,140),txt)
    b.MouseButton1Click:Connect(function()
        local ok,err=pcall(fn)
        if not ok then
            status.BackgroundColor3=Color3.fromRGB(145,40,45)
            status.Text="ERRO: "..tostring(err):sub(1,60)
        end
    end)
end
button("TESTAR BOTAO",49,function() status.Text="BOTAO OK: "..P.Name end)
button("VERIFICAR PERSONAGEM",105,function()
    local c=P.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    status.Text=h and ("VIDA: "..math.floor(h.Health).."/"..math.floor(h.MaxHealth)) or "Humanoid nao encontrado"
end)
button("VERIFICAR EVENTO",161,function()
    local ev=game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    local remote=ev and ev:FindFirstChild("CombatEvent")
    status.Text=remote and ("CombatEvent: "..remote.ClassName) or "CombatEvent nao encontrado"
end)
button("FECHAR",217,function() G:Destroy() end)
status.Text="JJC v0.8 - MENU PRONTO"
