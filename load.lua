local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

-- Adjustable speed settings
local verticalSpeed = 10 
local horizontalSpeed = 5 
local reachThreshold = 2

-- Stats
local coinsCollected = 0
local lastServerHopCheck = 0
local serverHopCooldown = 60 -- seconds

local bodyPos, bodyGyro
local coinContainer = nil

-- Simple UI
local function createUI()
    if lp.PlayerGui:FindFirstChild("CoinFarmUI") then
        lp.PlayerGui.CoinFarmUI:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CoinFarmUI"
    screenGui.Parent = lp.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(0.01, 0, 0.01, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.3
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Text = "COIN FARMER"
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame

    local coinCounter = Instance.new("TextLabel")
    coinCounter.Text = "Coins: "..coinsCollected
    coinCounter.Size = UDim2.new(1, 0, 0, 20)
    coinCounter.Position = UDim2.new(0, 0, 0, 25)
    coinCounter.BackgroundTransparency = 1
    coinCounter.TextColor3 = Color3.fromRGB(255, 215, 0)
    coinCounter.Font = Enum.Font.GothamMedium
    coinCounter.TextSize = 14
    coinCounter.Parent = frame
end

local function updateUI()
    if lp.PlayerGui:FindFirstChild("CoinFarmUI") then
        lp.PlayerGui.CoinFarmUI.Frame.TextLabel.Text = "Coins: "..coinsCollected
    end
end

local function setupNoclip()
    RunService.Stepped:Connect(function()
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
end

local function isInventoryFull()
    local gui = lp.PlayerGui
    for _, screenGui in ipairs(gui:GetDescendants()) do
        if (screenGui:IsA("TextLabel") or screenGui:IsA("TextButton")) and screenGui.Visible then
            local text = string.upper(screenGui.Text)
            if string.find(text, "FULL") or string.find(text, "MAX") then
                return true
            end
        end
    end
    return false
end

local function resetCharacter()
    if lp.Character then
        lp.Character:BreakJoints()
    end
    char = lp.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    task.wait(1)
    setupCharacter()
end

local function setupCharacter()
    if bodyPos then bodyPos:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end

    bodyPos = Instance.new("BodyPosition")
    bodyPos.MaxForce = Vector3.new(40000, 40000, 40000)
    bodyPos.P = 10000
    bodyPos.D = 2000 
    bodyPos.Parent = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.P = 8000
    bodyGyro.D = 500
    bodyGyro.Parent = hrp

    hum.PlatformStand = true
    setupNoclip()
end

local function isValidCoin(c)
    if not c:IsA("BasePart") then return false end
    if c.Transparency >= 0.9 then return false end
    if c:GetAttribute("Collected") == true then return false end
    return true
end

local function getValidCoins()
    local coins = {}
    
    -- First check inside CoinContainer if it exists
    if coinContainer then
        for _, obj in ipairs(coinContainer:GetDescendants()) do
            if obj.Name == "Coin_Server" and isValidCoin(obj) then
                table.insert(coins, obj)
            end
        end
    end
    
    -- Then check the rest of the workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Coin_Server" and isValidCoin(obj) and (not coinContainer or not obj:IsDescendantOf(coinContainer)) then
            table.insert(coins, obj)
        end
    end
    
    return coins
end

local function getClosestCoin()
    local coins = getValidCoins()
    local closest, dist = nil, math.huge
    for _, c in ipairs(coins) do
        local d = (hrp.Position - c.Position).Magnitude
        if d < dist then
            closest = c
            dist = d
        end
    end
    return closest
end

local function moveToPosition(targetPos)
    if not char or not hrp or not bodyPos then return end
    
    local moveVector = (targetPos - hrp.Position)
    local verticalMove = Vector3.new(0, moveVector.Y, 0)
    local horizontalMove = Vector3.new(moveVector.X, 0, moveVector.Z)
    local adjustedMove = (horizontalMove * horizontalSpeed) + (verticalMove * verticalSpeed)
    
    bodyPos.Position = hrp.Position + adjustedMove
end

local function collectCoin(coin)
    if not coin then return true end
    
    -- Move below coin
    moveToPosition(Vector3.new(coin.Position.X, coin.Position.Y - 10, coin.Position.Z))
    task.wait(0.3)
    
    -- Move to coin
    moveToPosition(coin.Position)
    task.wait(0.3)
    
    coinsCollected = coinsCollected + 1
    updateUI()
    
    -- Move below again
    moveToPosition(Vector3.new(coin.Position.X, coin.Position.Y - 10, coin.Position.Z))
    task.wait(0.3)
    
    return false
end

local function shouldServerHop()
    if #Players:GetPlayers() <= 4 then
        if tick() - lastServerHopCheck > serverHopCooldown then
            lastServerHopCheck = tick()
            return true
        end
    end
    return false
end

local function serverHop()
    local PlaceId = game.PlaceId
    local JobId = game.JobId

    local servers = {}
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Desc&limit=100"))
    end)

    if success and result and result.data then
        for _, v in ipairs(result.data) do
            if v.id ~= JobId and v.playing < v.maxPlayers then
                table.insert(servers, v.id)
            end
        end
    end

    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)])
    end
end

local function findCoinContainer()
    while task.wait(5) do
        local container = Workspace:FindFirstChild("CoinContainer")
        if container then
            coinContainer = container
            -- Move to container position
            local containerPos = container:GetPivot().Position
            moveToPosition(Vector3.new(containerPos.X, containerPos.Y + 10, containerPos.Z))
        else
            coinContainer = nil
        end
    end
end

local function startFarming()
    task.spawn(findCoinContainer)
    
    while task.wait(0.1) do
        if not char or not hrp then
            char = lp.Character or lp.CharacterAdded:Wait()
            hrp = char:WaitForChild("HumanoidRootPart")
            hum = char:WaitForChild("Humanoid")
            setupCharacter()
        end

        if shouldServerHop() then
            serverHop()
            task.wait(5)
        end

        if isInventoryFull() then
            resetCharacter()
            task.wait(2)
        else
            local coin = getClosestCoin()
            if coin then
                if collectCoin(coin) then
                    task.wait(1)
                end
            elseif coinContainer then
                -- Stay near container if it exists
                local containerPos = coinContainer:GetPivot().Position
                moveToPosition(Vector3.new(containerPos.X, containerPos.Y + 10, containerPos.Z))
            end
        end
    end
end

-- Initialize
createUI()
setupCharacter()
task.wait(2)
startFarming()