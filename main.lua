-- Serviços necessários
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Importar a biblioteca OrionUI
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()

-- Variáveis principais
local isAiming = false
local selectedTarget = nil -- Jogador alvo selecionado manualmente
local teleportLocation = nil -- Localização de teleporte definida pelo jogador
local espEnabled = {
    Box = false,
    Lines = false,
    Name = false
}

-- Função para ajustar a câmera para o alvo
local function aimAtTarget(target)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local targetPosition = target.Character.HumanoidRootPart.Position
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    end
end

-- Função para teletransportar o jogador rapidamente com instabilidade
local function teleportPlayerThroughWalls(location, speed)
    if not location or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        warn("Invalid teleport location or player character not found.")
        return
    end

    local character = LocalPlayer.Character
    local humanoidRootPart = character.HumanoidRootPart

    -- Desabilitar a colisão para permitir atravessar paredes
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- Mover o jogador rapidamente para o local de destino
    local startPosition = humanoidRootPart.Position
    local distance = (location - startPosition).Magnitude

    -- Calcular a quantidade de tempo para o teletransporte com base na distância e na velocidade
    local duration = distance / speed
    local startTime = tick()

    -- Atualizar a posição do jogador até atingir o destino
    local success, err = pcall(function()
        while tick() - startTime < duration do
            local elapsedTime = tick() - startTime
            local alpha = elapsedTime / duration  -- Calcula a interpolação suave entre 0 e 1
            local newPosition = startPosition:Lerp(location, alpha)  -- Interpolação linear

            -- Atualiza a posição do jogador
            humanoidRootPart.CFrame = CFrame.new(newPosition)
            wait(0.01)  -- Reduz o tempo de espera para tornar o teleporte mais rápido e instável
        end

        -- Garantir que o jogador atinja exatamente o destino
        humanoidRootPart.CFrame = CFrame.new(location)
    end)

    if not success then
        warn("Error during teleport: " .. err)
    end

    -- Restaurar a colisão dos parts após o teleporte
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end







-- Função para reentrar no jogo
local function rejoinGame()
    local teleportService = game:GetService("TeleportService")
    teleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- Função para criar ESP proporcional ao jogador
local function createESP(player, type)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    if type == "Box" then
        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = Color3.new(1, 0, 0)
        box.Thickness = 1
        box.Filled = false
        RunService.RenderStepped:Connect(function()
            if espEnabled.Box and character and character:FindFirstChild("HumanoidRootPart") then
                local rootPart = character.HumanoidRootPart
                local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                if onScreen then
                    local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
                    local size = math.clamp(1000 / distance, 50, 300)
                    box.Size = Vector2.new(size, size * 2)
                    box.Position = Vector2.new(vector.X - size / 2, vector.Y - size)
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        end)
    elseif type == "Lines" then
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.new(0, 1, 0)
        line.Thickness = 1
        RunService.RenderStepped:Connect(function()
            if espEnabled.Lines and character and character:FindFirstChild("HumanoidRootPart") then
                local rootPart = character.HumanoidRootPart
                local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                if onScreen then
                    line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    line.To = Vector2.new(vector.X, vector.Y)
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end)
    elseif type == "Name" then
        local name = Drawing.new("Text")
        name.Visible = false
        name.Text = player.Name
        name.Color = Color3.new(1, 1, 1)
        name.Size = 16
        RunService.RenderStepped:Connect(function()
            if espEnabled.Name and character and character:FindFirstChild("HumanoidRootPart") then
                local rootPart = character.HumanoidRootPart
                local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                if onScreen then
                    name.Position = Vector2.new(vector.X, vector.Y - 50)
                    name.Visible = true
                else
                    name.Visible = false
                end
            else
                name.Visible = false
            end
        end)
    end
end

-- Criar janela OrionUI
local Window = OrionLib:MakeWindow({
    Name = "Byonix Hub",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "ByonixHubConfig"
})

-- Criar aba principal
local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Lista de jogadores disponíveis
local playerList = {}
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        table.insert(playerList, player.Name)
    end
end

-- Dropdown para selecionar o jogador alvo
MainTab:AddDropdown({
    Name = "Select Target",
    Default = "None",
    Options = playerList,
    Callback = function(selected)
        selectedTarget = Players:FindFirstChild(selected)
    end
})

-- Botão para ativar/desativar o AimBot
MainTab:AddToggle({
    Name = "Enable AimBot",
    Default = false,
    Callback = function(value)
        isAiming = value
    end
})

-- Campo de texto para definir a localização de teleporte
MainTab:AddTextbox({
    Name = "Set Teleport Location",
    Default = "",
    TextDisappear = true,
    Callback = function(value)
        local coordinates = string.split(value, ",")
        if #coordinates == 3 then
            local x, y, z = tonumber(coordinates[1]), tonumber(coordinates[2]), tonumber(coordinates[3])
            if x and y and z then
                teleportLocation = Vector3.new(x, y, z)
            end
        end
    end
})

-- Botão para definir a localização de teleporte atual
MainTab:AddButton({
    Name = "Set Current Location",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local currentPosition = LocalPlayer.Character.HumanoidRootPart.Position
            teleportLocation = currentPosition
        end
    end
})



-- Botão para teletransportar o jogador suavemente através das paredes
MainTab:AddButton({
    Name = "Teleport to Location (Through Walls)",
    Callback = function()
        teleportPlayerThroughWalls(teleportLocation, 100)  -- '100' é a velocidade, você pode ajustar conforme necessário
    end
})



-- Botão para reentrar no jogo
MainTab:AddButton({
    Name = "Rejoin Game",
    Callback = function()
        rejoinGame()
    end
})

-- Criar aba para ESP
local ESPTab = Window:MakeTab({
    Name = "ESP",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Toggles de ESP
ESPTab:AddToggle({
    Name = "ESP Box",
    Default = false,
    Callback = function(value)
        espEnabled.Box = value
    end
})

ESPTab:AddToggle({
    Name = "ESP Lines",
    Default = false,
    Callback = function(value)
        espEnabled.Lines = value
    end
})

ESPTab:AddToggle({
    Name = "ESP Name",
    Default = false,
    Callback = function(value)
        espEnabled.Name = value
    end
})

-- Atualizar a câmera continuamente enquanto o AimBot está ativo
RunService.RenderStepped:Connect(function()
    if isAiming and selectedTarget then
        aimAtTarget(selectedTarget)
    end
end)

-- Atualizar a lista de jogadores quando alguém entrar ou sair
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        table.insert(playerList, player.Name)
        OrionLib:UpdateDropdown({
            Name = "Select Target",
            Options = playerList
        })
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if table.find(playerList, player.Name) then
        table.remove(playerList, table.find(playerList, player.Name))
        OrionLib:UpdateDropdown({
            Name = "Select Target",
            Options = playerList
        })
    end
end)

-- Função para copiar a posição atual do jogador para o clipboard e mostrar uma notificação
local function copyPositionToClipboard()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local currentPosition = LocalPlayer.Character.HumanoidRootPart.Position
        local positionData = string.format("X: %.2f, Y: %.2f, Z: %.2f", currentPosition.X, currentPosition.Y, currentPosition.Z)
        
        -- Copiar as coordenadas para o clipboard
        setclipboard(positionData)
        
        -- Exibir a notificação usando OrionLib
        OrionLib:MakeNotification({
            Name = "Position Copied",
            Content = "The current position has been copied to your clipboard.",
            Image = "rbxassetid://4483345998",  -- Ícone da notificação
            Time = 5  -- A notificação ficará visível por 5 segundos
        })
    end
end

-- Adicionando o botão "Copy Current Position to Clipboard" no OrionUI
MainTab:AddButton({
    Name = "Copy Current Position to Clipboard",
    Callback = function()
        copyPositionToClipboard()  -- Copia a posição do jogador para o clipboard e exibe a notificação
    end
})



-- Adicionando a nova aba para o "Island Teleport"
local IslandTab = Window:MakeTab({
    Name = "Island Teleport",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Definindo as coordenadas das ilhas
local islandLocations = {
    ["Castelo do Mar"] = Vector3.new(-5015.22, 314.56, -3004.17),
    ["Mansão"] = Vector3.new(-12551.70, 337.21, -7476.58),
    ["Dragon Dojo"] = Vector3.new(5753.33, 1206.86, 920.11),
    ["XMAS Island"] = Vector3.new(-1091.49, 62.71, -14502.91)
}

-- Dropdown para o jogador escolher a ilha
IslandTab:AddDropdown({
    Name = "Select Island",
    Default = "None",
    Options = {"Castelo do Mar", "Mansão", "Dragon Dojo", "XMAS Island"},  -- As opções disponíveis
    Callback = function(selected)
        teleportLocation = islandLocations[selected]  -- Atualiza a posição de teleporte com a coordenada selecionada
    end
})

-- Botão para teleportar o jogador para a ilha selecionada
IslandTab:AddButton({
    Name = "Teleport to Island",
    Callback = function()
        if teleportLocation then
            teleportPlayerThroughWalls(teleportLocation, 100)  -- Teleporta suavemente para o local escolhido
        else
            OrionLib:MakeNotification({
                Name = "No Island Selected",
                Content = "Please select an island first!",
                Image = "rbxassetid://4483345998",  -- Ícone da notificação
                Time = 5  -- A notificação ficará visível por 5 segundos
            })
        end
    end
})

local CreditsTab = Window:MakeTab({
    Name = "Credits",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local CreditsText = "Made by lawzera.app (amaterasw_)"

CreditsTab:AddLabel({
    Text = "Made by lawzera.app (amaterasw_)"
})

-- Copiar link do perfil do Discord
local function copyDiscordProfile()
    setclipboard("https://discord.gg/DKrz9RxZ8J")
    OrionLib:MakeNotification({
        Name = "Discord Profile Copied",
        Content = "The Discord profile link has been copied to your clipboard.",
        Image = "rbxassetid://4483345998",
        Time = 5
    })
end

-- AutoFarm Blox Fruits Tab
local AutoFarmTab = Window:MakeTab({
    Name = "AutoFarm Blox Fruits",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Teleportar nos npcs mais proximos e matar
AutoFarmTab:AddToggle({
    Name = "AutoFarm",
    Default = false,
    Callback = function(value)
        if value then
            while wait() do
                for i,v in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
                    if v:FindFirstChild("HumanoidRootPart") then
                        local plr = game.Players.LocalPlayer.Character.HumanoidRootPart
                        local pos = v.HumanoidRootPart.Position
                        plr.CFrame = CFrame.new(pos + Vector3.new(0,0,0))
                        wait(0.1)
                        game:GetService("ReplicatedStorage").Remotes.Melee:FireServer(v)
                    end
                end
            end
        end
    end
})

-- Atacar os NPCs mais próximos
AutoFarmTab:AddButton({
    Name = "Attack NPCs",
    Callback = function()
        for i,v in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") then
                local plr = game.Players.LocalPlayer.Character.HumanoidRootPart
                local pos = v.HumanoidRootPart.Position
                plr.CFrame = CFrame.new(pos + Vector3.new(0,0,0))
                wait(0.1)
                game:GetService("ReplicatedStorage").Remotes.Melee:FireServer(v)
            end
        end
    end
})




-- a interface
OrionLib:Init()
