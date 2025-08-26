local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ChatService = game:GetService("Chat")
local TextChatService = game:GetService("TextChatService")
local localPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

-- Configuration
local FOLLOW_OFFSET = Vector3.new(0, 3, 5)
local MOVEMENT_SMOOTHNESS = 0.1
local PROTECTION_RADIUS = 15
local SUS_ANIMATION_R6 = "72042024"
local SUS_ANIMATION_R15 = "698251653"
local STAND_ANIMATION_ID = "128381158301762"

local config = {
    Prefix = ".",
    AllowedPrefixes = {".", "/", "?", "!", "'", ":", ";", "@", "*", "&", "+", "_", "-", "=", "[", "{", "|", "~", "`"}
}

-- State variables
local owners = {}
local heartbeatConnection = nil
local protectionConnection = nil
local standHumanoid = nil
local standPlatform = nil
local standAnimTrack = nil
local protectionActive = false
local flinging = false
local yeetForce = nil
local hidden = false
local hidePlatform = nil
local lastResponseTime = 0
local susTarget = nil
local susConnection = nil
local lastCommandTime = 0
local commandDelay = 0.1
local commandAbuseCount = {}
local afkPlayers = {}
local lastCommandsTime = 0
local commandsDelay = 30
local disabledCommands = {}
local commandCooldowns = {}
local commandAbuseWarnings = {}
local lastMovementCheck = {}
local suspendedPlayers = {}
local rudePlayers = {}
local rudePhrases = {"pmo", "sybau", "syfm", "stfu", "kysss", "idc", "suck","shut","die","shush"}
local randomTargets = {}
local activeCommand = nil
local susBlock = nil
local followBlock = nil
local autoFarmActive = false
local autoFarmConnection = nil
local quietModeUsers = {}
local whisperMonitorEnabled = true
local blacklistedPlayers = {}
local shootingTarget = nil
local shootingConnection = nil
local gunEquipped = false
local playRoundActive = false
local playRoundConnection = nil
local lastChatTime = 0
local chatCooldown = 10
local spyEnabled = false
local spyConnection = nil

-- Enhanced PvP Mode variables
local PVP_MODE = {
    Enabled = false,
    Target = nil,
    Location = nil,
    Countdown = 0,
    Connection = nil,
    LastShotTime = 0,
    ShotCooldown = 0.5,
    LastKnifeTime = 0,
    KnifeCooldown = 1.5,
    CombatDistance = 25,
    WalkSpeed = 16,
    Path = nil,
    LastMovementChange = 0,
    MovementDuration = 1,
    CurrentMovement = nil,
    MovementPatterns = {
        "StrafeLeft", "StrafeRight", "Jump", "Backpedal", 
        "CircleLeft", "CircleRight", "RandomZigzag", "Advance",
        "Retreat", "FeintLeft", "FeintRight", "QuickAdvance"
    },
    ResponseTimer = 0,
    WaitingForResponse = false,
    CombatStyle = nil,
    LastPosition = nil,
    StuckTimer = 0,
    LastHealthCheck = 0,
    Aggressiveness = 0.7,
    Defensiveness = 0.7,
    Accuracy = 0.85,
    ReactionTime = 0.2,
    MovementVariance = 0.3
}

-- PlayRound AI variables
local PLAY_ROUND = {
    Enabled = false,
    Connection = nil,
    CurrentRole = "Innocent",
    CurrentTarget = nil,
    Path = nil,
    LastRoleCheck = 0,
    LastChatTime = 0,
    ChatCooldown = 10,
    LastMovementChange = 0,
    MovementDuration = 3,
    CurrentMovement = "Wander",
    MovementPatterns = {
        "Wander", "CircleLeft", "CircleRight", "Pause", "RandomJumps", "ZigZag", "Jump"
    },
    LastPosition = nil,
    StuckTimer = 0,
    ChatMessages = {
        Murderer = {
            "You're not getting out of here.",
            "Let's see how fast you can run.",
            "Found you.",
            "You're done for.",
            "This won't end well for you."
        },
        Sheriff = {
            "Stay behind me, I've got this.",
            "Let's catch the killer.",
            "I won't let anyone else get hurt.",
            "Time to bring justice.",
            "Alright, where are they hiding?"
        },
        Innocent = {
            "Please don't be the murderer...",
            "Where's the sheriff when you need them?",
            "I'm just trying to stay alive here.",
            "I swear it's not me!",
            "Can we all just chill for a sec?"
        }
    },
    MovementHistory = {},
    MaxMovementHistory = 5,
    LastGunCheck = 0,
    GunCheckInterval = 0.1
}

-- Utility functions
local function isOwner(player)
    for _, ownerName in ipairs(getgenv().Owners) do
        if player.Name == ownerName or (player.DisplayName and player.DisplayName == ownerName) then
            return true
        end
    end
    return false
end

local function isHeadAdmin(player)
    for _, name in ipairs(getgenv().HeadAdmins) do
        if player.Name == name or (player.DisplayName and player.DisplayName == name) then
            return true
        end
    end
    return false
end

local function isAdmin(player)
    for _, name in ipairs(getgenv().Admins) do
        if player.Name == name or (player.DisplayName and player.DisplayName == name) then
            return true
        end
    end
    return false
end

local function isFreeTrial(player)
    for _, name in ipairs(getgenv().FreeTrial) do
        if player.Name == name or (player.DisplayName and player.DisplayName == name) then
            return true
        end
    end
    return false
end

local function hasAdminPermissions(player)
    return isOwner(player) or isHeadAdmin(player) or isAdmin(player) or isFreeTrial(player)
end

local function checkAdminLeft()
    local anyAdmin = false
    for _, player in ipairs(Players:GetPlayers()) do
        if hasAdminPermissions(player) then
            anyAdmin = true
            break
        end
    end
    if not anyAdmin then
        game:GetService("Players").LocalPlayer:Kick("No admins left in game")
    end
end

local function processFreeTrial(player)
    if isFreeTrial(player) then
        makeStandSpeak("Thanks for redeeming! You have 5 minutes to use commands.")
        showCommandsForRank(player)
        task.wait(300)
        for i = #getgenv().FreeTrial, 1, -1 do
            if getgenv().FreeTrial[i] == player.Name then
                table.remove(getgenv().FreeTrial, i)
                makeStandSpeak("Your trial has expired!")
                showPricing(player)
                break
            end
        end
    end
end

local function makeStandSpeak(message)
    if not localPlayer.Character then return end
    local head = localPlayer.Character:FindFirstChild("Head")
    if head then
        if #message > 200 then
            local chunks = {}
            for i = 1, #message, 200 do
                table.insert(chunks, message:sub(i, i + 199))
            end
            for _, chunk in ipairs(chunks) do
                ChatService:Chat(head, chunk, Enum.ChatColor.White)
                task.wait(1)
            end
        else
            ChatService:Chat(head, message, Enum.ChatColor.White)
        end
    end
    if TextChatService and TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral then
        if #message > 200 then
            local chunks = {}
            for i = 1, #message, 200 do
                table.insert(chunks, message:sub(i, i + 199))
            end
            for _, chunk in ipairs(chunks) do
                TextChatService.TextChannels.RBXGeneral:SendAsync(chunk)
                task.wait(1)
            end
        else
            TextChatService.TextChannels.RBXGeneral:SendAsync(message)
        end
    end
end

local function showPricing(speaker)
    local availableAdmins = {}
    local availableOwners = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if isOwner(player) then
            table.insert(availableOwners, player.Name)
        elseif isHeadAdmin(player) then
            table.insert(availableAdmins, player.Name)
        end
    end

    local messages = {
        "Admin costs 100 Robux or 1 godly (Basic commands)",
        "Head Admin costs 500 Robux or 5 godly (Can sell admin)"
    }

    if #availableOwners > 0 then
        table.insert(messages, "Available owners to pay: "..table.concat(availableOwners, ", "))
    end

    if #availableAdmins > 0 then
        table.insert(messages, "Available head admins to pay: "..table.concat(availableAdmins, ", "))
    end

    table.insert(messages, "Type !freetrial to test commands for 5 minutes")

    for _, msg in ipairs(messages) do
        makeStandSpeak(msg)
        task.wait(1)
    end
end

local function showCommandsForRank(speaker)
    local rank = ""
    if isOwner(speaker) then
        rank = "owner"
    elseif isHeadAdmin(speaker) then
        rank = "headadmin"
    elseif isAdmin(speaker) then
        rank = "admin"
    elseif isFreeTrial(speaker) then
        rank = "freetrial"
    else
        makeStandSpeak("You don't have permission to use commands. Try !freetrial or !pricing.")
        return
    end

    local commands = {
        owner = {
            {cmd = config.Prefix.."follow (user/murder/sheriff/random)", desc = "Follow a player"},
            {cmd = config.Prefix.."protect (on/off)", desc = "Protect owners from others"},
            {cmd = config.Prefix.."say (message)", desc = "Make the stand speak"},
            {cmd = config.Prefix.."reset", desc = "Reset the stand"},
            {cmd = config.Prefix.."hide", desc = "Hide the stand"},
            {cmd = config.Prefix.."dismiss", desc = "Dismiss the stand"},
            {cmd = config.Prefix.."summon", desc = "Summon the stand"},
            {cmd = config.Prefix.."fling (all/sheriff/murder/user/random)", desc = "Fling players"},
            {cmd = config.Prefix.."bringgun", desc = "Get the gun"},
            {cmd = config.Prefix.."whitelist (user)", desc = "Whitelist a player"},
            {cmd = config.Prefix.."addowner (user)", desc = "Add an owner"},
            {cmd = config.Prefix.."addadmin (user)", desc = "Add an admin"},
            {cmd = config.Prefix.."removeadmin (user)", desc = "Remove an admin"},
            {cmd = config.Prefix.."sus (user/murder/sheriff/random) (speed)", desc = "Sus on a player"},
            {cmd = config.Prefix.."stopsus", desc = "Stop sus behavior"},
            {cmd = config.Prefix.."eliminate (random)", desc = "Eliminate players"},
            {cmd = config.Prefix.."win (user)", desc = "Make a player win"},
            {cmd = config.Prefix.."commands", desc = "Show commands"},
            {cmd = config.Prefix.."disable (cmd)", desc = "Disable a command"},
            {cmd = config.Prefix.."enable (cmd)", desc = "Enable a command"},
            {cmd = config.Prefix.."stopcmds", desc = "Stop all active commands"},
            {cmd = config.Prefix.."rejoin", desc = "Rejoin the game"},
            {cmd = config.Prefix.."quit", desc = "Terminate the session"},
            {cmd = config.Prefix.."describe (user/murd/sheriff)", desc = "Describe a player"},
            {cmd = config.Prefix.."headadmin (user)", desc = "Add head admin"},
            {cmd = config.Prefix.."pricing", desc = "Show pricing info"},
            {cmd = config.Prefix.."freetrial", desc = "Get free trial"},
            {cmd = config.Prefix.."trade (user)", desc = "Trade with player"},
            {cmd = config.Prefix.."eliminateall", desc = "Eliminate all players"},
            {cmd = config.Prefix.."shoot (user/murd)", desc = "Shoot a player"},
            {cmd = config.Prefix.."spy (on/off)", desc = "Spy on player messages"},
            {cmd = config.Prefix.."prefix (new prefix)", desc = "Change command prefix"},
            {cmd = config.Prefix.."blacklist (user)", desc = "Blacklist a player"},
            {cmd = config.Prefix.."pvp (on/off)", desc = "Toggle 1v1 mode"},
            {cmd = config.Prefix.."playround (on/off)", desc = "Toggle AI play mode"}
        },
        headadmin = {
            {cmd = config.Prefix.."follow (user/murder/sheriff/random)", desc = "Follow a player"},
            {cmd = config.Prefix.."protect (on/off)", desc = "Protect owners from others"},
            {cmd = config.Prefix.."say (message)", desc = "Make the stand speak"},
            {cmd = config.Prefix.."reset", desc = "Reset the stand"},
            {cmd = config.Prefix.."hide", desc = "Hide the stand"},
            {cmd = config.Prefix.."dismiss", desc = "Dismiss the stand"},
            {cmd = config.Prefix.."summon", desc = "Summon the stand"},
            {cmd = config.Prefix.."fling (all/sheriff/murder/user/random)", desc = "Fling players"},
            {cmd = config.Prefix.."bringgun", desc = "Get the gun"},
            {cmd = config.Prefix.."whitelist (user)", desc = "Whitelist a player"},
            {cmd = config.Prefix.."addadmin (user)", desc = "Add an admin"},
            {cmd = config.Prefix.."sus (user/murder/sheriff/random) (speed)", desc = "Sus on a player"},
            {cmd = config.Prefix.."stopsus", desc = "Stop sus behavior"},
            {cmd = config.Prefix.."eliminate (random)", desc = "Eliminate players"},
            {cmd = config.Prefix.."win (user)", desc = "Make a player win"},
            {cmd = config.Prefix.."commands", desc = "Show commands"},
            {cmd = config.Prefix.."stopcmds", desc = "Stop all active commands"},
            {cmd = config.Prefix.."rejoin", desc = "Rejoin the game"},
            {cmd = config.Prefix.."describe (user/murd/sheriff)", desc = "Describe a player"},
            {cmd = config.Prefix.."pricing", desc = "Show pricing info"},
            {cmd = config.Prefix.."freetrial", desc = "Get free trial"},
            {cmd = config.Prefix.."trade (user)", desc = "Trade with player"},
            {cmd = config.Prefix.."shoot (user/murd)", desc = "Shoot a player"},
            {cmd = config.Prefix.."spy (on/off)", desc = "Spy on player messages"},
            {cmd = config.Prefix.."blacklist (user)", desc = "Blacklist a player"},
            {cmd = config.Prefix.."pvp (on/off)", desc = "Toggle 1v1 mode"},
            {cmd = config.Prefix.."playround (on/off)", desc = "Toggle AI play mode"}
        },
        admin = {
            {cmd = config.Prefix.."follow (user/murder/sheriff/random)", desc = "Follow a player"},
            {cmd = config.Prefix.."protect (on/off)", desc = "Protect owners from others"},
            {cmd = config.Prefix.."say (message)", desc = "Make the stand speak"},
            {cmd = config.Prefix.."reset", desc = "Reset the stand"},
            {cmd = config.Prefix.."hide", desc = "Hide the stand"},
            {cmd = config.Prefix.."dismiss", desc = "Dismiss the stand"},
            {cmd = config.Prefix.."summon", desc = "Summon the stand"},
            {cmd = config.Prefix.."fling (all/sheriff/murder/user/random)", desc = "Fling players"},
            {cmd = config.Prefix.."bringgun", desc = "Get the gun"},
            {cmd = config.Prefix.."sus (user/murder/sheriff/random) (speed)", desc = "Sus on a player"},
            {cmd = config.Prefix.."stopsus", desc = "Stop sus behavior"},
            {cmd = config.Prefix.."eliminate (random)", desc = "Eliminate players"},
            {cmd = config.Prefix.."win (user)", desc = "Make a player win"},
            {cmd = config.Prefix.."commands", desc = "Show commands"},
            {cmd = config.Prefix.."stopcmds", desc = "Stop all active commands"},
            {cmd = config.Prefix.."describe (user/murd/sheriff)", desc = "Describe a player"},
            {cmd = config.Prefix.."pricing", desc = "Show pricing info"},
            {cmd = config.Prefix.."freetrial", desc = "Get free trial"},
            {cmd = config.Prefix.."shoot (user/murd)", desc = "Shoot a player"},
            {cmd = config.Prefix.."spy (on/off)", desc = "Spy on player messages"},
            {cmd = config.Prefix.."pvp (on/off)", desc = "Toggle 1v1 mode"},
            {cmd = config.Prefix.."playround (on/off)", desc = "Toggle AI play mode"}
        },
        freetrial = {
            {cmd = config.Prefix.."follow (user/murder/sheriff/random)", desc = "Follow a player"},
            {cmd = config.Prefix.."protect (on/off)", desc = "Protect owners from others"},
            {cmd = config.Prefix.."say (message)", desc = "Make the stand speak"},
            {cmd = config.Prefix.."reset", desc = "Reset the stand"},
            {cmd = config.Prefix.."hide", desc = "Hide the stand"},
            {cmd = config.Prefix.."dismiss", desc = "Dismiss the stand"},
            {cmd = config.Prefix.."summon", desc = "Summon the stand"},
            {cmd = config.Prefix.."fling (all/sheriff/murder/user/random)", desc = "Fling players"},
            {cmd = config.Prefix.."bringgun", desc = "Get the gun"},
            {cmd = config.Prefix.."sus (user/murder/sheriff/random) (speed)", desc = "Sus on a player"},
            {cmd = config.Prefix.."stopsus", desc = "Stop sus behavior"},
            {cmd = config.Prefix.."eliminate (random)", desc = "Eliminate players"},
            {cmd = config.Prefix.."win (user)", desc = "Make a player win"},
            {cmd = config.Prefix.."commands", desc = "Show commands"},
            {cmd = config.Prefix.."stopcmds", desc = "Stop all active commands"},
            {cmd = config.Prefix.."describe (user/murd/sheriff)", desc = "Describe a player"},
            {cmd = config.Prefix.."pricing", desc = "Show pricing info"},
            {cmd = config.Prefix.."shoot (user/murd)", desc = "Shoot a player"},
            {cmd = config.Prefix.."spy (on/off)", desc = "Spy on player messages"},
            {cmd = config.Prefix.."pvp (on/off)", desc = "Toggle 1v1 mode"},
            {cmd = config.Prefix.."playround (on/off)", desc = "Toggle AI play mode"}
        }
    }

    local cmdList = commands[rank]
    makeStandSpeak("Commands for "..rank..":")

    for i = 1, #cmdList, 5 do
        local chunk = {}
        for j = i, math.min(i + 4, #cmdList) do
            table.insert(chunk, cmdList[j].cmd .. " - " .. cmdList[j].desc)
        end
        makeStandSpeak(table.concat(chunk, "\n"))
        task.wait(1)
    end
end

local function checkCommandPermissions(speaker, cmd)
    if isOwner(speaker) then return true end
    if isHeadAdmin(speaker) then
        if cmd == config.Prefix.."addowner" or cmd == config.Prefix.."removeadmin" or cmd == config.Prefix.."disable" or cmd == config.Prefix.."enable" or cmd == config.Prefix.."quit" then
            return false
        end
        return true
    end
    if isAdmin(speaker) then
        if cmd == config.Prefix.."addowner" or cmd == config.Prefix.."addadmin" or cmd == config.Prefix.."removeadmin" or cmd == config.Prefix.."whitelist" or 
            cmd == config.Prefix.."disable" or cmd == config.Prefix.."enable" or cmd == config.Prefix.."quit" or cmd == config.Prefix.."headadmin" then
            return false
        end
        return true
    end
    if isFreeTrial(speaker) then
        if cmd == config.Prefix.."addowner" or cmd == config.Prefix.."addadmin" or cmd == config.Prefix.."removeadmin" or cmd == config.Prefix.."whitelist" or 
            cmd == config.Prefix.."disable" or cmd == config.Prefix.."enable" or cmd == config.Prefix.."quit" or cmd == config.Prefix.."headadmin" or cmd == config.Prefix.."trade" or cmd == config.Prefix.."eliminateall" or cmd == config.Prefix.."blacklist" then
            return false
        end
        return true
    end
    return false
end

local function warnCommandAbuse(speaker)
    if isOwner(speaker) then return end
    commandAbuseWarnings[speaker.Name] = (commandAbuseWarnings[speaker.Name] or 0) + 1
    if commandAbuseWarnings[speaker.Name] >= 3 then
        suspendedPlayers[speaker.Name] = os.time() + 300
        makeStandSpeak(speaker.Name.." has been suspended for 5 minutes due to command spam")
    else
        makeStandSpeak(speaker.Name..", please don't spam commands (Warning "..commandAbuseWarnings[speaker.Name].."/3)")
    end
end

local function getMainOwner()
    for _, ownerName in ipairs(getgenv().Owners) do
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Name == ownerName or (player.DisplayName and player.DisplayName == ownerName) then
                return player
            end
        end
    end
    return nil
end

local function isMainOwner(speaker)
    local mainOwner = getMainOwner()
    return mainOwner and speaker.Name == mainOwner.Name
end

local function stopActiveCommand()
    if activeCommand == "fling" and yeetForce then
        yeetForce:Destroy()
        yeetForce = nil
    elseif activeCommand == "sus" and susConnection then
        susConnection:Disconnect()
        susConnection = nil
    elseif activeCommand == "eliminate" then
        if localPlayer.Character then
            local knife = localPlayer.Character:FindFirstChild("Knife")
            if knife then knife.Parent = localPlayer.Backpack end
        end
    elseif activeCommand == "autofarm" and autoFarmConnection then
        autoFarmConnection:Disconnect()
        autoFarmConnection = nil
    elseif activeCommand == "shoot" and shootingConnection then
        shootingConnection:Disconnect()
        shootingConnection = nil
        shootingTarget = nil
        if localPlayer.Character then
            local gun = localPlayer.Character:FindFirstChild("Gun")
            if gun then gun.Parent = localPlayer.Backpack end
        end
        gunEquipped = false
    elseif activeCommand == "pvp" and PVP_MODE.Connection then
        PVP_MODE.Enabled = false
        PVP_MODE.Connection:Disconnect()
        PVP_MODE.Connection = nil
        PVP_MODE.Target = nil
        PVP_MODE.Location = nil
        if PVP_MODE.Path then
            PVP_MODE.Path:Destroy()
            PVP_MODE.Path = nil
        end
    elseif activeCommand == "playround" and PLAY_ROUND.Connection then
        PLAY_ROUND.Enabled = false
        PLAY_ROUND.Connection:Disconnect()
        PLAY_ROUND.Connection = nil
        PLAY_ROUND.CurrentTarget = nil
        if PLAY_ROUND.Path then
            PLAY_ROUND.Path:Destroy()
            PLAY_ROUND.Path = nil
        end
    elseif activeCommand == "spy" and spyConnection then
        spyEnabled = false
        spyConnection:Disconnect()
        spyConnection = nil
    end
    flinging = false
    autoFarmActive = false
    activeCommand = nil
end

local function isR15(player)
    return player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.RigType == Enum.HumanoidRigType.R15
end

local function isWhitelisted(player)
    if isOwner(player) or isHeadAdmin(player) or isAdmin(player) or isFreeTrial(player) then return true end
    local whitelist = getgenv().Configuration.whitelist or {}
    for _, name in ipairs(whitelist) do
        if player.Name == name or (player.DisplayName and player.DisplayName == name) then
            return true
        end
    end
    return false
end

local function createStandPlatform()
    if standPlatform then standPlatform:Destroy() end
    standPlatform = Instance.new("Part")
    standPlatform.Name = "StandPlatform"
    standPlatform.Anchored = true
    standPlatform.CanCollide = true
    standPlatform.Transparency = 1
    standPlatform.Size = Vector3.new(4, 1, 4)
    standPlatform.Parent = workspace
    return standPlatform
end

local function createSusBlock()
    if susBlock then susBlock:Destroy() end
    susBlock = Instance.new("Part")
    susBlock.Name = "SusBlock"
    susBlock.Anchored = true
    susBlock.CanCollide = true
    susBlock.Transparency = 0.5
    susBlock.Color = Color3.fromRGB(255, 0, 0)
    susBlock.Size = Vector3.new(4, 1, 4)
    susBlock.Parent = workspace
    return susBlock
end

local function createFollowBlock()
    if followBlock then followBlock:Destroy() end
    followBlock = Instance.new("Part")
    followBlock.Name = "FollowBlock"
    followBlock.Anchored = true
    followBlock.CanCollide = true
    followBlock.Transparency = 0.5
    followBlock.Color = Color3.fromRGB(0, 255, 0)
    followBlock.Size = Vector3.new(4, 1, 4)
    followBlock.Parent = workspace
    return followBlock
end

local function createHidePlatform()
    if hidePlatform then hidePlatform:Destroy() end
    hidePlatform = Instance.new("Part")
    hidePlatform.Name = "HidePlatform"
    hidePlatform.Anchored = true
    hidePlatform.CanCollide = true
    hidePlatform.Transparency = 0.5
    hidePlatform.Color = Color3.fromRGB(50, 50, 50)
    hidePlatform.Size = Vector3.new(10, 1, 10)
    hidePlatform.Parent = workspace
    return hidePlatform
end

local function disablePlayerMovement()
    if not localPlayer then return end
    pcall(function()
        localPlayer.DevEnableMouseLock = true
    end)
    if localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = false
            standHumanoid = humanoid
        end
    end
end

local function playStandAnimation()
    if not localPlayer.Character then return end
    local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if standAnimTrack then
        standAnimTrack:Stop()
        standAnimTrack = nil
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://"..STAND_ANIMATION_ID
    standAnimTrack = humanoid:LoadAnimation(anim)
    standAnimTrack.Priority = Enum.AnimationPriority.Action
    standAnimTrack:Play()
end

local function findOwners()
    local foundOwners = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isOwner(player) and player ~= localPlayer then
            table.insert(foundOwners, player)
        end
    end
    return foundOwners
end

local function findTarget(targetName)
    targetName = targetName:lower()
    local foundPlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        if player.Name:lower():sub(1, #targetName) == targetName then
            table.insert(foundPlayers, player)
        elseif player.DisplayName and player.DisplayName:lower():sub(1, #targetName) == targetName then
            table.insert(foundPlayers, player)
        end
    end
    if #foundPlayers == 1 then
        return foundPlayers[1]
    elseif #foundPlayers > 1 then
        makeStandSpeak("Multiple matches found!")
        return nil
    end
    return nil
end

local function getRandomPlayer()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and not blacklistedPlayers[player.Name] then
            table.insert(players, player)
        end
    end
    if #players > 0 then
        return players[math.random(1, #players)]
    end
    return nil
end

local function getRoot(character)
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function flingPlayer(target)
    stopActiveCommand()
    activeCommand = "fling"
    if not target or target == localPlayer then return end
    if yeetForce then yeetForce:Destroy() end
    local startTime = tick()
    local flingDuration = 10
    local function continuousFling()
        while activeCommand == "fling" and target and target.Parent do
            if not target.Character or not target.Character.Parent then
                break
            end
            local targetRoot = getRoot(target.Character)
            local myRoot = getRoot(localPlayer.Character)
            if not targetRoot or not myRoot then
                break
            end
            if not yeetForce then
                yeetForce = Instance.new('BodyThrust', myRoot)
                yeetForce.Force = Vector3.new(9999,9999,9999)
                yeetForce.Name = "YeetForce"
                flinging = true
            end
            local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                break
            end
            myRoot.CFrame = targetRoot.CFrame
            yeetForce.Location = targetRoot.Position
            if tick() - startTime > flingDuration then
                break
            end
            RunService.Heartbeat:Wait()
        end
        if yeetForce then
            yeetForce:Destroy()
            yeetForce = nil
        end
        flinging = false
    end
    spawn(continuousFling)
end

local function findPlayerWithTool(toolName)
    toolName = toolName:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer or blacklistedPlayers[player.Name] then continue end
        if player.Character then
            for _, item in ipairs(player.Character:GetDescendants()) do
                if item:IsA("Tool") and item.Name:lower():find(toolName) then
                    return player
                end
            end
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") and item.Name:lower():find(toolName) then
                        return player
                    end
                end
            end
        end
    end
    return nil
end

local function findPlayersWithTool(toolName)
    local foundPlayers = {}
    toolName = toolName:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer or blacklistedPlayers[player.Name] then continue end
        if player.Character then
            for _, item in ipairs(player.Character:GetDescendants()) do
                if item:IsA("Tool") and item.Name:lower():find(toolName) then
                    table.insert(foundPlayers, player)
                    break
                end
            end
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") and item.Name:lower():find(toolName) then
                        table.insert(foundPlayers, player)
                        break
                    end
                end
            end
        end
    end
    return foundPlayers
end

local function startProtection()
    if protectionConnection then
        protectionConnection:Disconnect()
    end
    protectionActive = true
    makeStandSpeak("Protection activated!")
    protectionConnection = RunService.Heartbeat:Connect(function()
        if not localPlayer.Character or #owners == 0 then return end
        local myRoot = getRoot(localPlayer.Character)
        if not myRoot then return end
        for _, owner in ipairs(owners) do
            if owner.Character then
                local ownerRoot = getRoot(owner.Character)
                if ownerRoot then
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= localPlayer and player.Character and not blacklistedPlayers[player.Name] then
                            local targetRoot = getRoot(player.Character)
                            if targetRoot and (targetRoot.Position - ownerRoot.Position).Magnitude < PROTECTION_RADIUS then
                                flingPlayer(player)
                                break
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function stopProtection()
    protectionActive = false
    if protectionConnection then
        protectionConnection:Disconnect()
        protectionConnection = nil
    end
    makeStandSpeak("Protection deactivated!")
end

local function followOwners()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
    createStandPlatform()
    createFollowBlock()
    disablePlayerMovement()
    playStandAnimation()
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if #owners == 0 or not localPlayer.Character then return end
        local myRoot = getRoot(localPlayer.Character)
        if not myRoot then return end
        for _, owner in ipairs(owners) do
            if owner.Character then
                local ownerRoot = getRoot(owner.Character)
                if ownerRoot then
                    local targetCF = ownerRoot.CFrame * CFrame.new(FOLLOW_OFFSET)
                    myRoot.CFrame = myRoot.CFrame:Lerp(targetCF, MOVEMENT_SMOOTHNESS)
                    if standPlatform then
                        standPlatform.CFrame = CFrame.new(myRoot.Position - Vector3.new(0, 3, 0))
                    end
                    if followBlock then
                        followBlock.CFrame = CFrame.new(ownerRoot.Position - Vector3.new(0, 3, 0))
                    end
                    break
                end
            end
        end
    end)
end

local function summonStand(speaker)
    if hidden then
        if hidePlatform then
            hidePlatform:Destroy()
            hidePlatform = nil
        end
        hidden = false
    end
    if not localPlayer.Character then return end
    local myHrp = getRoot(localPlayer.Character)
    if not myHrp then return end
    if speaker and speaker.Character then
        local speakerHrp = getRoot(speaker.Character)
        if speakerHrp then
            myHrp.CFrame = speakerHrp.CFrame * CFrame.new(0, 0, FOLLOW_OFFSET.Z)
            disablePlayerMovement()
            playStandAnimation()
            makeStandSpeak("Summoned by "..speaker.Name)
            return
        end
    end
    if #owners > 0 then
        for _, owner in ipairs(owners) do
            if owner.Character then
                local ownerHrp = getRoot(owner.Character)
                if ownerHrp then
                    myHrp.CFrame = ownerHrp.CFrame * CFrame.new(0, 0, FOLLOW_OFFSET.Z)
                    disablePlayerMovement()
                    playStandAnimation()
                    break
                end
            end
        end
    end
end

local function dismissStand()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    stopProtection()
    if standPlatform then
        standPlatform:Destroy()
        standPlatform = nil
    end
    if susBlock then
        susBlock:Destroy()
        susBlock = nil
    end
    if followBlock then
        followBlock:Destroy()
        followBlock = nil
    end
    if standAnimTrack then
        standAnimTrack:Stop()
        standAnimTrack = nil
    end
    if standHumanoid then
        standHumanoid.AutoRotate = true
    end
    if yeetForce then
        yeetForce:Destroy()
        yeetForce = nil
    end
    flinging = false
    for playerName, _ in pairs(rudePlayers) do
        rudePlayers[playerName] = nil
    end
    makeStandSpeak("Resting for now...")
end

local function resetStand()
    if standPlatform then standPlatform:Destroy() end
    if susBlock then susBlock:Destroy() end
    if followBlock then followBlock:Destroy() end
    if yeetForce then yeetForce:Destroy() end
    flinging = false
    if localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
        localPlayer.CharacterAdded:Wait()
        if #owners > 0 then
            disablePlayerMovement()
            summonStand()
            makeStandSpeak("Reborn anew!")
        end
    else
        summonStand()
        makeStandSpeak("Reborn anew!")
    end
end

local function hideStand()
    if not localPlayer.Character then return end
    hidden = true
    local root = getRoot(localPlayer.Character)
    if not root then return end
    createHidePlatform()
    root.CFrame = CFrame.new(0, -500, 0)
    if hidePlatform then
        hidePlatform.CFrame = CFrame.new(0, -502, 0)
    end
    makeStandSpeak("Vanishing...")
end

local function stopSus()
    if susConnection then
        susConnection:Disconnect()
        susConnection = nil
    end
    if standAnimTrack then
        standAnimTrack:Stop()
        standAnimTrack = nil
    end
    susTarget = nil
    if susBlock then
        susBlock:Destroy()
        susBlock = nil
    end
    if workspace.CurrentCamera then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        if localPlayer.Character then
            workspace.CurrentCamera.CameraSubject = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        end
    end
    makeStandSpeak("Stopped sus behavior!")
end

local function startSus(targetPlayer, speed)
    stopActiveCommand()
    activeCommand = "sus"
    if susTarget == targetPlayer then
        makeStandSpeak("Already sus-ing "..targetPlayer.Name.."!")
        return
    end
    susTarget = targetPlayer
    makeStandSpeak("ULTRA SPEED sus on "..targetPlayer.Name..(speed and " at speed "..speed or "").."!")
    if not localPlayer.Character then return end
    local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
        track:Stop()
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://"..(isR15(localPlayer) and SUS_ANIMATION_R15 or SUS_ANIMATION_R6)
    standAnimTrack = humanoid:LoadAnimation(anim)
    standAnimTrack.Priority = Enum.AnimationPriority.Action4
    standAnimTrack.Looped = true
    standAnimTrack:AdjustSpeed(speed or (isR15(localPlayer) and 0.7 or 0.65))
    if standAnimTrack then
        standAnimTrack:Play()
    end
    humanoid.AutoRotate = false
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Scriptable
    end
    createSusBlock()
    susConnection = RunService.RenderStepped:Connect(function()
        if activeCommand ~= "sus" or not susTarget or not susTarget.Character or not localPlayer.Character then
            stopSus()
            return
        end
        local targetRoot = getRoot(susTarget.Character)
        local myRoot = getRoot(localPlayer.Character)
        if not targetRoot or not myRoot then return end
        local lookVector = targetRoot.CFrame.LookVector
        local targetPos = targetRoot.Position - (lookVector * 2)
        myRoot.CFrame = CFrame.new(targetPos, targetRoot.Position)
        if susBlock then
            susBlock.CFrame = CFrame.new(targetRoot.Position - Vector3.new(0, 3, 0))
        end
        if camera and camera.CameraType == Enum.CameraType.Scriptable then
            camera.CFrame = CFrame.new(myRoot.Position + Vector3.new(0, 3, -5), myRoot.Position)
        end
        if standAnimTrack then
            standAnimTrack.TimePosition = 0.6
            task.wait(0.1)
            while standAnimTrack and standAnimTrack.TimePosition < (isR15(localPlayer) and 0.7 or 0.65) do 
                task.wait(0.1) 
            end
            if standAnimTrack then
                standAnimTrack:Stop()
                standAnimTrack = nil
            end
        end
    end)
    localPlayer.CharacterRemoving:Connect(stopSus)
end

local function equipKnife()
    if not localPlayer.Character then return false end
    local knife = localPlayer.Backpack:FindFirstChild("Knife") or localPlayer.Character:FindFirstChild("Knife")
    if knife then
        knife.Parent = localPlayer.Character
        return true
    end
    return false
end

local function simulateClick()
    local knife = localPlayer.Character:FindFirstChild("Knife")
    if knife and knife:FindFirstChild("Handle") then
        local remote = knife:FindFirstChildOfClass("RemoteEvent") or knife:FindFirstChildOfClass("RemoteFunction")
        if remote then
            remote:FireServer(knife.Handle.CFrame)
        end
    end
end

local function eliminatePlayers()
    stopActiveCommand()
    activeCommand = "eliminate"
    if not equipKnife() then return end
    while activeCommand == "eliminate" do
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer and player.Character and not blacklistedPlayers[player.Name] then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local root = getRoot(player.Character)
                    local myRoot = getRoot(localPlayer.Character)
                    if root and myRoot then
                        myRoot.CFrame = root.CFrame * CFrame.new(0, 0, -2)
                        for i = 1, 20 do
                            simulateClick()
                            task.wait(0.01)
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
    if localPlayer.Character then
        local knife = localPlayer.Character:FindFirstChild("Knife")
        if knife then knife.Parent = localPlayer.Backpack end
    end
end

local function eliminateAllPlayers()
    stopActiveCommand()
    activeCommand = "eliminateall"
    if not equipKnife() then return end

    local myRoot = getRoot(localPlayer.Character)
    if not myRoot then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and not blacklistedPlayers[player.Name] then
            local targetRoot = getRoot(player.Character)
            if targetRoot then
                targetRoot.Anchored = true
                targetRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -1)
            end
        end
    end

    makeStandSpeak("Executing all players...")

    local endTime = os.time() + 20
    while os.time() < endTime and activeCommand == "eliminateall" do
        simulateClick()
        task.wait(0.05)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local targetRoot = getRoot(player.Character)
            if targetRoot then
                targetRoot.Anchored = false
            end
        end
    end

    if localPlayer.Character then
        local knife = localPlayer.Character:FindFirstChild("Knife")
        if knife then knife.Parent = localPlayer.Backpack end
    end
end

local function winGame(targetPlayer)
    stopActiveCommand()
    if not targetPlayer or targetPlayer == localPlayer then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player ~= targetPlayer and not blacklistedPlayers[player.Name] then
            flingPlayer(player)
        end
    end
end

local function findGunDrop()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" then
            return obj
        end
    end
    return nil
end

local function stealGun(speaker)
    if not localPlayer.Character then return end
    local gun = localPlayer.Backpack:FindFirstChild("Gun") or localPlayer.Character:FindFirstChild("Gun")
    if gun then
        if speaker and speaker.Character then
            local speakerRoot = getRoot(speaker.Character)
            if speakerRoot then
                local myRoot = getRoot(localPlayer.Character)
                if myRoot then
                    myRoot.CFrame = speakerRoot.CFrame * CFrame.new(0, 0, -2)
                end
            end
        end
        resetStand()
        return
    end
    local gunDrop = findGunDrop()
    if not gunDrop then return end
    local myRoot = getRoot(localPlayer.Character)
    if not myRoot then return end
    myRoot.CFrame = gunDrop.CFrame * CFrame.new(0, 3, 0)
    task.wait(0.5)
    if speaker and speaker.Character then
        local speakerRoot = getRoot(speaker.Character)
        if speakerRoot then
            myRoot.CFrame = speakerRoot.CFrame * CFrame.new(0, 0, -2)
            task.wait(0.5)
            resetStand()
        end
    end
end

local function shootPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or blacklistedPlayers[targetPlayer.Name] then return end

    if not gunEquipped then
        local gun = localPlayer.Backpack:FindFirstChild("Gun") or localPlayer.Character:FindFirstChild("Gun")
        if not gun then
            local gunDrop = findGunDrop()
            if gunDrop then
                local myRoot = getRoot(localPlayer.Character)
                if myRoot then
                    myRoot.CFrame = gunDrop.CFrame * CFrame.new(0, 3, 0)
                    task.wait(0.5)
                    gun = localPlayer.Backpack:FindFirstChild("Gun") or localPlayer.Character:FindFirstChild("Gun")
                end
            end
        end

        if not gun then return end

        gun.Parent = localPlayer.Character
        gunEquipped = true
    end

    local targetRoot = getRoot(targetPlayer.Character)
    local myRoot = getRoot(localPlayer.Character)
    if not targetRoot or not myRoot then return end

    local shootPosition = targetRoot.Position - (targetRoot.CFrame.LookVector * 10)
    shootPosition = Vector3.new(shootPosition.X, targetRoot.Position.Y, shootPosition.Z)
    myRoot.CFrame = CFrame.new(shootPosition, targetRoot.Position)
    task.wait(0.2)

    while activeCommand == "shoot" and targetPlayer and targetPlayer.Parent and targetPlayer.Character do
        local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then break end

        local targetRoot = getRoot(targetPlayer.Character)
        if not targetRoot then break end

        shootPosition = targetRoot.Position - (targetRoot.CFrame.LookVector * 10)
        shootPosition = Vector3.new(shootPosition.X, targetRoot.Position.Y, shootPosition.Z)
        myRoot.CFrame = CFrame.new(shootPosition, targetRoot.Position)

        local gun = localPlayer.Character:FindFirstChild("Gun")
        if gun then
            local args = {
                1,
                targetRoot.Position,
                "AH2"
            }
            local remote = gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
            if remote then
                remote:InvokeServer(unpack(args))
            end
        end

        task.wait(0.1)
    end
end

local function startShooting(targetPlayer)
    stopActiveCommand()
    activeCommand = "shoot"
    shootingTarget = targetPlayer
    gunEquipped = false

    shootingConnection = RunService.Heartbeat:Connect(function()
        if activeCommand ~= "shoot" or not shootingTarget or not shootingTarget.Parent then
            stopActiveCommand()
            return
        end

        shootPlayer(shootingTarget)
    end)
end

local function autoFarm()
    stopActiveCommand()
    autoFarmActive = true

    autoFarmConnection = RunService.Heartbeat:Connect(function()
        if not autoFarmActive then return end

        local gun = localPlayer.Backpack:FindFirstChild("Gun") or localPlayer.Character:FindFirstChild("Gun")
        if not gun then
            local gunDrop = findGunDrop()
            if gunDrop then
                local myRoot = getRoot(localPlayer.Character)
                if myRoot then
                    myRoot.CFrame = gunDrop.CFrame * CFrame.new(0, 3, 0)
                    task.wait(0.5)
                end
            end
        else
            gun.Parent = localPlayer.Character
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer and player.Character and not isWhitelisted(player) and not blacklistedPlayers[player.Name] then
                local knife = player.Character:FindFirstChild("Knife") or 
                    (player.Backpack and player.Backpack:FindFirstChild("Knife"))
                if knife then
                    shootPlayer(player)
                    break
                end
            end
        end

        if equipKnife() then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer and player.Character and not isWhitelisted(player) and not blacklistedPlayers[player.Name] then
                    local targetRoot = getRoot(player.Character)
                    local myRoot = getRoot(localPlayer.Character)
                    if targetRoot and myRoot then
                        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -2)
                        for i = 1, 5 do
                            simulateClick()
                            task.wait(0.01)
                        end
                        break
                    end
                end
            end
        end
    end)
end

local function stopAutoFarm()
    autoFarmActive = false
    if autoFarmConnection then
        autoFarmConnection:Disconnect()
        autoFarmConnection = nil
    end
end

local function tradePlayer(targetPlayer)
    if not targetPlayer or blacklistedPlayers[targetPlayer.Name] then return end
    local args = {
        targetPlayer
    }
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"):InvokeServer(unpack(args))
    end)
end

local function whitelistPlayer(playerName)
    table.insert(getgenv().Configuration.whitelist, playerName)
    makeStandSpeak("Added "..playerName.." to whitelist!")
end

local function blacklistPlayer(playerName)
    blacklistedPlayers[playerName] = true
    makeStandSpeak("Added "..playerName.." to blacklist!")
    local player = Players:FindFirstChild(playerName)
    if player and player.Character then
        flingPlayer(player)
    end
end

local function addOwner(playerName)
    table.insert(getgenv().Owners, playerName)
    owners = findOwners()
    if #owners > 0 then
        followOwners()
    end
    makeStandSpeak("Added "..playerName.." as owner!")
    showCommandsForRank(Players:FindFirstChild(playerName))
end

local function addHeadAdmin(playerName)
    table.insert(getgenv().HeadAdmins, playerName)
    makeStandSpeak("Added "..playerName.." as head admin!")
    showCommandsForRank(Players:FindFirstChild(playerName))
end

local function addAdmin(playerName)
    table.insert(getgenv().Admins, playerName)
    makeStandSpeak("Added "..playerName.." as admin!")
    showCommandsForRank(Players:FindFirstChild(playerName))
end

local function removeOwner(playerName)
    for i, name in ipairs(getgenv().Owners) do
        if name == playerName then
            table.remove(getgenv().Owners, i)
            break
        end
    end
    owners = findOwners()
    makeStandSpeak("Removed "..playerName.." from owners!")
end

local function removeAdmin(playerName)
    for i, name in ipairs(getgenv().Admins) do
        if name == playerName then
            table.remove(getgenv().Admins, i)
            break
        end
    end
    makeStandSpeak("Removed "..playerName.." from admins!")
end

local function disableCommand(cmd)
    disabledCommands[cmd:lower()] = true
    makeStandSpeak("Command "..cmd.." has been disabled!")
end

local function enableCommand(cmd)
    disabledCommands[cmd:lower()] = nil
    makeStandSpeak("Command "..cmd.." has been enabled!")
end

local function isCommandDisabled(cmd)
    return disabledCommands[cmd:lower()] == true
end

local function suspendPlayer(playerName, duration)
    local mainOwner = getMainOwner()
    if mainOwner and playerName == mainOwner.Name then return end
    suspendedPlayers[playerName] = os.time() + duration
    makeStandSpeak(playerName.." has been suspended for "..duration.." seconds!")
end

local function isPlayerSuspended(playerName)
    local mainOwner = getMainOwner()
    if mainOwner and playerName == mainOwner.Name then return false end
    if suspendedPlayers[playerName] then
        if os.time() < suspendedPlayers[playerName] then
            return true
        else
            suspendedPlayers[playerName] = nil
            return false
        end
    end
    return false
end

local function stringContainsAny(str, patterns)
    str = str:lower()
    for _, pattern in ipairs(patterns) do
        if str:find(pattern) then
            return true
        end
    end
    return false
end

local function getSkinTone(humanoid)
    if not humanoid or not humanoid:FindFirstChild("BodyColors") then
        return "Unknown"
    end
    local skinColor = humanoid.BodyColors.HeadColor3
    
    -- Convert Color3 to BrickColor
    local brickColor = BrickColor.new(skinColor)
    local colorName = brickColor.Name
    
    -- Map BrickColor names to more descriptive skin tones
    local colorMap = {
        ["White"] = "Pale White",
        ["Light orange"] = "Fair",
        ["Light yellow"] = "Fair",
        ["Yellow"] = "Light",
        ["Light green"] = "Light",
        ["Green"] = "Medium Light",
        ["Dark green"] = "Medium",
        ["Light blue"] = "Medium",
        ["Blue"] = "Tan",
        ["Dark blue"] = "Tan",
        ["Light red"] = "Light",
        ["Red"] = "Medium",
        ["Dark red"] = "Brown",
        ["Brown"] = "Brown",
        ["Dark brown"] = "Dark Brown",
        ["Black"] = "Very Dark",
        ["Dark grey"] = "Dark",
        ["Grey"] = "Medium",
        ["Light grey"] = "Light",
        ["Institutional white"] = "Pale White",
        ["Mid gray"] = "Medium",
        ["Dark gray"] = "Dark"
    }
    
    return colorMap[colorName] or "Custom Color ("..colorName..")"
end
local function describePlayer(targetName)
    local target = nil
    if targetName:lower() == "murd" then
        target = findPlayerWithTool("Knife")
        if not target then return {"No murderer found!"} end
    elseif targetName:lower() == "sheriff" then
        target = findPlayerWithTool("Gun")
        if not target then return {"No sheriff found!"} end
    else
        target = findTarget(targetName)
        if not target then return {"Player not found!"} end
    end

    local messages = {}
    local skinTone = "Unknown"
    local accessories = {}

    if target.Character then
        local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            skinTone = getSkinTone(humanoid)
        end
        for _, item in ipairs(target.Character:GetChildren()) do
            if item:IsA("Accessory") then
                table.insert(accessories, item.Name)
            end
        end
    end

    table.insert(messages, target.Name.."'s skin tone: "..skinTone)
    if #accessories > 0 then
        table.insert(messages, "Accessories: "..table.concat(accessories, ", "))
    else
        table.insert(messages, "No accessories found")
    end
    return messages
end

local function checkCommandAbuse(speaker)
    if isOwner(speaker) then return false end
    local mainOwner = getMainOwner()
    if mainOwner and speaker.Name == mainOwner.Name then return false end
    if isPlayerSuspended(speaker.Name) then
        local remaining = suspendedPlayers[speaker.Name] - os.time()
        makeStandSpeak(speaker.Name.." is suspended for "..math.floor(remaining).." more seconds")
        return true
    end
    local currentTime = os.time()
    commandAbuseCount[speaker.Name] = commandAbuseCount[speaker.Name] or {count = 0, lastTime = 0, warnings = 0}
    local abuseData = commandAbuseCount[speaker.Name]
    if currentTime - abuseData.lastTime < 10 then
        abuseData.count = abuseData.count + 1
        if abuseData.count >= 2 then
            abuseData.warnings = abuseData.warnings + 1
            if abuseData.warnings >= 2 then
                suspendPlayer(speaker.Name, 600)
                commandAbuseCount[speaker.Name] = nil
                return true
            else
                makeStandSpeak("Warning "..speaker.Name..": Don't abuse commands! Next warning will result in 10 minute suspension.")
                return true
            end
        end
    else
        abuseData.count = 0
        abuseData.warnings = 0
    end
    abuseData.lastTime = currentTime
    return false
end

local function getInnocentPlayers()
    local murderers = findPlayersWithTool("Knife")
    local sheriffs = findPlayersWithTool("Gun")
    local murdererNames = {}
    local sheriffNames = {}
    for _, player in ipairs(murderers) do
        table.insert(murdererNames, isWhitelisted(player) and player.Name:sub(1,3) or player.Name:sub(1,3))
    end
    for _, player in ipairs(sheriffs) do
        table.insert(sheriffNames, isWhitelisted(player) and player.Name:sub(1,3) or player.Name:sub(1,3))
    end
    if #murdererNames > 0 or #sheriffNames > 0 then
        return "ALL Players but "..(#murdererNames > 0 and ("(Murderer: "..table.concat(murdererNames, ", ")..") ") or "")..(#sheriffNames > 0 and ("(Sheriff: "..table.concat(sheriffNames, ", ")..")") or "")
    else
        return "ALL Players are innocent!"
    end
end

local function showCommands(speaker)
    local currentTime = os.time()
    if currentTime - lastCommandsTime < commandsDelay then
        makeStandSpeak("Please wait "..math.floor(commandsDelay - (currentTime - lastCommandsTime)).." seconds before using this command again!")
        return
    end
    lastCommandsTime = currentTime
    showCommandsForRank(speaker)
end

local function checkRudeMessage(speaker, message)
    local mainOwner = getMainOwner()
    if mainOwner and speaker.Name == mainOwner.Name then return false end
    local msg = message:lower()
    for _, phrase in ipairs(rudePhrases) do
        if msg:find(phrase) then
            rudePlayers[speaker.Name] = true
            makeStandSpeak("Hey "..speaker.Name..", that's not cool! Don't say those things!")
            flingPlayer(speaker)
            return true
        end
    end
    return false
end

local function checkApology(speaker, message)
    if not rudePlayers[speaker.Name] then return false end
    local msg = message:lower()
    if msg:find("sorry") or msg:find("apologize") or msg:find("my bad") then
        rudePlayers[speaker.Name] = nil
        makeStandSpeak("Apology accepted "..speaker.Name.."!")
        if yeetForce then
            yeetForce:Destroy()
            yeetForce = nil
        end
        flinging = false
        return true
    end
    return false
end

local function startSpyMode()
    spyEnabled = true
    makeStandSpeak("Spy mode activated! Monitoring all non-admin messages.")
    
    if spyConnection then
        spyConnection:Disconnect()
    end
    
    spyConnection = TextChatService.MessageReceived:Connect(function(message)
        if message.TextSource then
            local speaker = Players:GetPlayerByUserId(message.TextSource.UserId)
            if speaker and not hasAdminPermissions(speaker) then
                local msgType = "Public"
                if message.Metadata and message.Metadata["PrivateMessage"] then
                    msgType = "Whisper"
                    local recipient = Players:GetPlayerByUserId(message.Metadata["PrivateMessage"].RecipientId)
                    if recipient then
                        makeStandSpeak("[SPY] "..speaker.Name.." whispered to "..recipient.Name..": "..message.Text)
                    end
                else
                    makeStandSpeak("[SPY] "..speaker.Name..": "..message.Text)
                end
            end
        end
    end)
end

local function stopSpyMode()
    spyEnabled = false
    if spyConnection then
        spyConnection:Disconnect()
        spyConnection = nil
    end
    makeStandSpeak("Spy mode deactivated!")
end

local function respondToChat(speaker, message)
    if speaker == localPlayer then return end
    if tick() - lastResponseTime < 5 then return end
    if checkRudeMessage(speaker, message) then return end
    if checkApology(speaker, message) then return end
    
    -- Respond to mentions of the bot's name
    local botName = localPlayer.Name:lower()
    local msg = message:lower()
    if msg:find(botName:sub(1, 3)) or msg:find(botName:sub(1, 5)) or msg:find(botName:sub(1, 10)) then
        makeStandSpeak("That's me! "..localPlayer.Name.." at your service!")
        lastResponseTime = tick()
        return
    end
    
    if msg:find("i am afk") or msg:find("im afk") or msg:find("i'm afk") or msg:find("afk") then
        afkPlayers[speaker.Name] = true
        makeStandSpeak(speaker.Name.." is now AFK")
        lastResponseTime = tick()
        return
    elseif msg:find("back") and afkPlayers[speaker.Name] then
        afkPlayers[speaker.Name] = nil
        makeStandSpeak(speaker.Name.." is back from AFK!")
        lastResponseTime = tick()
        return
    end
    if msg:find("who is innocent") or msg:find("innocent") then
        makeStandSpeak(getInnocentPlayers())
        lastResponseTime = tick()
        return
    end
    if msg:find("good boy") then
        makeStandSpeak("Yes I'm a good boy!")
        lastResponseTime = tick()
        return
    end
    if msg:find("roqate") or msg:find("who made you") or msg:find("who created you") or msg:find("who owns you") then
        makeStandSpeak("My king Roqate!")
        lastResponseTime = tick()
        return
    end
    local responsePatterns = {
        {
            patterns = {"whats that", "what is that", "what is this", "what are you"},
            responses = {
                "I am The World!",
                "A manifestation of power!",
                "My king's will made manifest!"
            }
        },
        {
            patterns = {"exploit", "hack", "cheat", "exp"},
            responses = {
                "How dare you accuse my king! I don't exploit!",
                "This is pure stand power! I dont cheat!",
                "Such disrespect! I'm not a cheater!"
            }
        },
        {
            patterns = {"unfair", "not fair", "broken"},
            responses = {
                "Life isn't fair!",
                "My king plays by his own rules!",
                "Complain to the cosmos!"
            }
        },
        {
            patterns = {"how you do", "how did you", "how does this"},
            responses = {
                "Through the power of The World!",
                "Mysterious ways!",
                "Stand magic!"
            }
        },
        {
            patterns = {"script", "code", "made this"},
            responses = {
                "My existence is by royal decree!",
                "Only the worthy command such power!",
                "My king's will sustains me!"
            }
        },
        {
            patterns = {"roqate", "roq", "king"},
            responses = {
                "You speak of my glorious liege!",
                "All praise Roqate!",
                "My king's power knows no bounds!"
            }
        },
        {
            patterns = {"murder", "murderer", "killer", "murd"},
            responses = function()
                local murderers = findPlayersWithTool("Knife")
                if #murderers > 0 then
                    local names = ""
                    for i, player in ipairs(murderers) do
                        if isWhitelisted(player) then
                            return "I don't wanna snitch."
                        end
                        names = names .. player.Name:sub(1,3)
                        if i < #murderers then
                            names = names .. ", "
                        end
                    end
                    return "Murderer: " .. names .. "!"
                else
                    return "No murderer found..."
                end
            end
        },
        {
            patterns = {"sheriff", "sherif"},
            responses = function()
                local sheriffs = findPlayersWithTool("Gun")
                if #sheriffs > 0 then
                    local names = ""
                    for i, player in ipairs(sheriffs) do
                        if isWhitelisted(player) then
                            return "I don't wanna snitch."
                        end
                        names = names .. player.Name:sub(1,3)
                        if i < #sheriffs then
                            names = names .. ", "
                        end
                    end
                    return "Sheriff: " .. names .. "!"
                else
                    return "No law around here!"
                end
            end
        },
        {
            patterns = {"hello", "hi", "hey", "greetings"},
            responses = {
                "Hello there!",
                "Hi! How can I help?",
                "Hey! What's up?",
                "Greetings!"
            }
        },
        {
            patterns = {"thanks", "thank you", "ty"},
            responses = {
                "You're welcome!",
                "No problem!",
                "Happy to help!"
            }
        },
        {
            patterns = {"help", "what to do", "what should i do"},
            responses = {
                "Try to survive and find the murderer!",
                "Stay with other players for safety!",
                "Look for the gun to become sheriff!"
            }
        }
    }
    for _, responseGroup in ipairs(responsePatterns) do
        if stringContainsAny(msg, responseGroup.patterns) then
            local response
            if type(responseGroup.responses) == "function" then
                response = responseGroup.responses()
            else
                response = responseGroup.responses[math.random(1, #responseGroup.responses)]
            end
            makeStandSpeak(response)
            lastResponseTime = tick()
            return
        end
    end
end

local function processWhisper(speaker, recipient, message)
    if hasAdminPermissions(speaker) or hasAdminPermissions(recipient) then
        return
    end

    if not hasAdminPermissions(speaker) and not hasAdminPermissions(recipient) then
        makeStandSpeak(speaker.Name:sub(1,3).." messaged "..recipient.Name:sub(1,3).." this: "..message)
    end

    if message:sub(1,1) == config.Prefix or message:sub(1,1) == "!" then
        processCommand(speaker, message)
    end
end

local function stopPVPMode()
    PVP_MODE.Enabled = false
    if PVP_MODE.Connection then
        PVP_MODE.Connection:Disconnect()
        PVP_MODE.Connection = nil
    end
    PVP_MODE.Target = nil
    PVP_MODE.Location = nil
    PVP_MODE.Countdown = 0
    if PVP_MODE.Path then
        PVP_MODE.Path:Destroy()
        PVP_MODE.Path = nil
    end

    if localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.AutoRotate = true
        end
    end
end

local function calculatePredictedPosition(targetRoot, weaponType)
    local distance = (targetRoot.Position - getRoot(localPlayer.Character).Position).Magnitude
    local predictionTime = 0

    if weaponType == "Gun" then
        predictionTime = math.clamp(distance / 100, 0.1, 0.3) * (1 + (1 - PVP_MODE.Accuracy) * 0.5)
    else
        predictionTime = math.clamp(distance / 50, 0.2, 0.6) * (1 + (1 - PVP_MODE.Accuracy) * 0.8)
    end

    predictionTime = predictionTime * (0.9 + math.random() * 0.2)

    return targetRoot.Position + (targetRoot.Velocity * predictionTime)
end

local function isPositionSafe(position)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {localPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local region = Region3.new(position - Vector3.new(2,2,2), position + Vector3.new(2,2,2))
    local parts = workspace:FindPartsInRegion3(region, nil, math.huge)
    for _, part in ipairs(parts) do
        if part.CanCollide and not part:IsDescendantOf(localPlayer.Character) then
            return false
        end
    end

    local raycastResult = workspace:Raycast(position, Vector3.new(0, -10, 0), raycastParams)
    if not raycastResult then
        return false
    end

    return true
end

local function findSafePositionNear(targetPosition, minDistance, maxDistance)
    for i = 1, 10 do
        local direction = Vector3.new(
            math.random() * 2 - 1,
            0,
            math.random() * 2 - 1
        ).Unit

        local distance = math.random(minDistance * 100, maxDistance * 100) / 100
        local testPos = targetPosition + (direction * distance)
        testPos = Vector3.new(testPos.X, targetPosition.Y, testPos.Z)

        if isPositionSafe(testPos) then
            return testPos
        end
    end
    return targetPosition + Vector3.new(maxDistance, 0, 0)
end

local function executeMovementPattern(humanoid, targetRoot, myRoot)
    local currentTime = os.clock()

    if currentTime - PVP_MODE.LastMovementChange > PVP_MODE.MovementDuration or 
        (PVP_MODE.LastPosition and (myRoot.Position - PVP_MODE.LastPosition).Magnitude < 1) then

        PVP_MODE.CurrentMovement = PVP_MODE.MovementPatterns[math.random(1, #PVP_MODE.MovementPatterns)]
        PVP_MODE.LastMovementChange = currentTime
        PVP_MODE.MovementDuration = 0.5 + math.random() * 1.5
    end

    PVP_MODE.LastPosition = myRoot.Position

    local desiredPosition = myRoot.Position
    local targetDirection = (targetRoot.Position - myRoot.Position).Unit
    local rightVector = targetRoot.CFrame.RightVector

    if PVP_MODE.CurrentMovement == "StrafeLeft" then
        desiredPosition = myRoot.Position + (-rightVector * 5 * PVP_MODE.MovementVariance)
    elseif PVP_MODE.CurrentMovement == "StrafeRight" then
        desiredPosition = myRoot.Position + (rightVector * 5 * PVP_MODE.MovementVariance)
    elseif PVP_MODE.CurrentMovement == "Jump" then
        humanoid.Jump = true
    elseif PVP_MODE.CurrentMovement == "Backpedal" then
        desiredPosition = myRoot.Position + (-targetDirection * 4 * PVP_MODE.MovementVariance)
    elseif PVP_MODE.CurrentMovement == "CircleLeft" then
        local angle = currentTime * 3
        desiredPosition = targetRoot.Position + (
            (-rightVector * math.cos(angle) * 7) + 
                (targetDirection * math.sin(angle) * 7))
    elseif PVP_MODE.CurrentMovement == "CircleRight" then
        local angle = currentTime * 3
        desiredPosition = targetRoot.Position + (
            (rightVector * math.cos(angle) * 7) + 
                (targetDirection * math.sin(angle) * 7))
    elseif PVP_MODE.CurrentMovement == "RandomZigzag" then
        local zigzag = math.sin(currentTime * 10) * 5
        desiredPosition = myRoot.Position + (rightVector * zigzag * PVP_MODE.MovementVariance)
    elseif PVP_MODE.CurrentMovement == "Advance" then
        desiredPosition = myRoot.Position + (targetDirection * 5 * PVP_MODE.MovementVariance)
    elseif PVP_MODE.CurrentMovement == "Retreat" then
        desiredPosition = myRoot.Position + (-targetDirection * 5 * PVP_MODE.MovementVariance)
    elseif PVP_MODE.CurrentMovement == "FeintLeft" then
        if math.random() < 0.7 then
            desiredPosition = myRoot.Position + (-rightVector * 8 * PVP_MODE.MovementVariance)
        else
            desiredPosition = myRoot.Position + (rightVector * 8 * PVP_MODE.MovementVariance)
        end
    elseif PVP_MODE.CurrentMovement == "FeintRight" then
        if math.random() < 0.7 then
            desiredPosition = myRoot.Position + (rightVector * 8 * PVP_MODE.MovementVariance)
        else
            desiredPosition = myRoot.Position + (-rightVector * 8 * PVP_MODE.MovementVariance)
        end
    elseif PVP_MODE.CurrentMovement == "QuickAdvance" then
        desiredPosition = myRoot.Position + (targetDirection * 8 * PVP_MODE.MovementVariance)
    end

    if PVP_MODE.CombatStyle == "Gun" then
        local distance = (targetRoot.Position - desiredPosition).Magnitude
        if distance < PVP_MODE.CombatDistance * 0.8 then
            desiredPosition = desiredPosition + (-targetDirection * 5)
        elseif distance > PVP_MODE.CombatDistance * 1.2 then
            desiredPosition = desiredPosition + (targetDirection * 3)
        end
    else
        local distance = (targetRoot.Position - desiredPosition).Magnitude
        if distance > 10 then
            desiredPosition = desiredPosition + (targetDirection * 5)
        end
    end

    if not isPositionSafe(desiredPosition) then
        desiredPosition = findSafePositionNear(myRoot.Position, 5, 10)
    end

    if not PVP_MODE.Path then
        PVP_MODE.Path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
    end

    PVP_MODE.Path:ComputeAsync(myRoot.Position, desiredPosition)

    if PVP_MODE.Path.Status == Enum.PathStatus.Success then
        local waypoints = PVP_MODE.Path:GetWaypoints()
        if #waypoints > 1 then
            for i, waypoint in ipairs(waypoints) do
                if i > 1 then
                    humanoid:MoveTo(waypoint.Position)
                    if waypoint.Action == Enum.PathWaypointAction.Jump then
                        humanoid.Jump = true
                    end

                    local reached = false
                    while not reached and PVP_MODE.Enabled do
                        if (myRoot.Position - waypoint.Position).Magnitude < 2 then
                            reached = true
                        end
                        task.wait()
                    end

                    if not PVP_MODE.Enabled then break end
                end
            end
        else
            humanoid:MoveTo(desiredPosition)
        end
    else
        humanoid:MoveTo(desiredPosition)
    end
end

local function handleGunCombat(humanoid, targetRoot, myRoot)
    local gun = localPlayer.Character:FindFirstChild("Gun")
    if not gun then return end

    local predictedPos = calculatePredictedPosition(targetRoot, "Gun")

    if math.random() > PVP_MODE.Accuracy then
        predictedPos = predictedPos + Vector3.new(
            (math.random() - 0.5) * 5,
            (math.random() - 0.5) * 3,
            (math.random() - 0.5) * 5
        )
    end

    if os.clock() - PVP_MODE.LastShotTime > PVP_MODE.ShotCooldown then
        local args = {
            1,
            predictedPos,
            "AH2"
        }
        local remote = gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
        if remote then
            remote:InvokeServer(unpack(args))
        end
        PVP_MODE.LastShotTime = os.clock()
    end

    humanoid.AutoRotate = math.random() < 0.8
    executeMovementPattern(humanoid, targetRoot, myRoot)
end

local function handleKnifeCombat(humanoid, targetRoot, myRoot)
    local knife = localPlayer.Character:FindFirstChild("Knife")
    if not knife then return end

    local predictedPos = calculatePredictedPosition(targetRoot, "Knife")

    if os.clock() - PVP_MODE.LastKnifeTime > PVP_MODE.KnifeCooldown then
        local args = {
            myRoot.CFrame,
            predictedPos
        }
        local remote = knife:FindFirstChild("Throw")
        if remote then
            remote:FireServer(unpack(args))
        end
        PVP_MODE.LastKnifeTime = os.clock()
    end

    humanoid.AutoRotate = true
    executeMovementPattern(humanoid, targetRoot, myRoot)
end

local function handlePVPCombat()
    if not PVP_MODE.Enabled or not PVP_MODE.Target or not PVP_MODE.Target.Character then
        stopPVPMode()
        return
    end

    local targetRoot = getRoot(PVP_MODE.Target.Character)
    local myRoot = getRoot(localPlayer.Character)
    local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")

    if not targetRoot or not myRoot or not humanoid then 
        stopPVPMode()
        return
    end

    if PVP_MODE.Countdown > 0 then
        if math.floor(PVP_MODE.Countdown) ~= math.floor(PVP_MODE.Countdown + 0.016) then
            makeStandSpeak(tostring(math.floor(PVP_MODE.Countdown)).."...")
        end
        PVP_MODE.Countdown = PVP_MODE.Countdown - 0.016

        if PVP_MODE.Countdown <= 0 then
            makeStandSpeak("GO!")
            PVP_MODE.Countdown = 0
            humanoid.WalkSpeed = PVP_MODE.WalkSpeed
        else
            humanoid.WalkSpeed = 0
            return
        end
    end

    if PVP_MODE.WaitingForResponse then
        PVP_MODE.ResponseTimer = PVP_MODE.ResponseTimer - 0.016
        if PVP_MODE.ResponseTimer <= 0 then
            makeStandSpeak("Time's up! Eliminating "..PVP_MODE.Target.Name.."!")
            PVP_MODE.WaitingForResponse = false
            if PVP_MODE.CombatStyle == "Gun" then
                startShooting(PVP_MODE.Target)
            else
                owners = {PVP_MODE.Target}
                eliminatePlayers()
            end
            stopPVPMode()
            return
        end
        return
    end

    local gun = localPlayer.Character:FindFirstChild("Gun")
    local knife = localPlayer.Character:FindFirstChild("Knife")

    if gun then
        PVP_MODE.CombatStyle = "Gun"
        handleGunCombat(humanoid, targetRoot, myRoot)
    elseif knife then
        PVP_MODE.CombatStyle = "Knife"
        handleKnifeCombat(humanoid, targetRoot, myRoot)
    else
        local gunInBackpack = localPlayer.Backpack:FindFirstChild("Gun")
        local knifeInBackpack = localPlayer.Backpack:FindFirstChild("Knife")

        if gunInBackpack then
            gunInBackpack.Parent = localPlayer.Character
        elseif knifeInBackpack then
            knifeInBackpack.Parent = localPlayer.Character
        else
            local gunDrop = findGunDrop()
            if gunDrop then
                myRoot.CFrame = gunDrop.CFrame * CFrame.new(0, 3, 0)
                task.wait(0.5)
            else
                makeStandSpeak("I can't 1v1 without a weapon!")
                stopPVPMode()
            end
        end
    end

    if os.clock() - PVP_MODE.LastHealthCheck > 2 then
        PVP_MODE.LastHealthCheck = os.clock()

        local myHealth = humanoid.Health / humanoid.MaxHealth
        if myHealth < 0.5 then
            PVP_MODE.Defensiveness = math.min(0.8, PVP_MODE.Defensiveness + 0.2)
            PVP_MODE.Aggressiveness = math.max(0.2, PVP_MODE.Aggressiveness - 0.2)
        else
            PVP_MODE.Defensiveness = 0.3
            PVP_MODE.Aggressiveness = 0.7
        end
    end
end

local function startPVPMode(targetPlayer)
    stopActiveCommand()
    activeCommand = "pvp"
    PVP_MODE.Enabled = true
    PVP_MODE.Target = targetPlayer
    PVP_MODE.Location = nil
    PVP_MODE.Countdown = 0
    PVP_MODE.CurrentMovement = nil
    PVP_MODE.LastMovementChange = 0
    PVP_MODE.ResponseTimer = 10
    PVP_MODE.WaitingForResponse = true

    local gun = localPlayer.Backpack:FindFirstChild("Gun") or localPlayer.Character:FindFirstChild("Gun")
    local knife = localPlayer.Backpack:FindFirstChild("Knife") or localPlayer.Character:FindFirstChild("Knife")

    if gun then
        PVP_MODE.CombatStyle = "Gun"
        local targetRoot = getRoot(targetPlayer.Character)
        local myRoot = getRoot(localPlayer.Character)
        if targetRoot and myRoot then
            local behindPosition = targetRoot.Position + (targetRoot.CFrame.LookVector * -PVP_MODE.CombatDistance)
            behindPosition = Vector3.new(behindPosition.X, targetRoot.Position.Y, behindPosition.Z)

            local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
                humanoid:MoveTo(behindPosition)
            end

            makeStandSpeak("Hey "..targetPlayer.Name.."! Let's 1v1!")
            makeStandSpeak("Say 'go' to accept or 'no' to decline (10 seconds)")
        end
    elseif knife then
        PVP_MODE.CombatStyle = "Knife"
        makeStandSpeak(targetPlayer.Name..", wanna 1v1?")
        makeStandSpeak("Say 'go' to accept or 'no' to decline (10 seconds)")
    else
        makeStandSpeak("I need a weapon to 1v1!")
        stopPVPMode()
        return
    end

    PVP_MODE.Connection = RunService.Heartbeat:Connect(handlePVPCombat)
end

local function getRandomMovementPattern()
    local availablePatterns = {}
    for _, pattern in ipairs(PLAY_ROUND.MovementPatterns) do
        local recentlyUsed = false
        for _, usedPattern in ipairs(PLAY_ROUND.MovementHistory) do
            if usedPattern == pattern then
                recentlyUsed = true
                break
            end
        end
        
        if not recentlyUsed then
            table.insert(availablePatterns, pattern)
        end
    end
    
    if #availablePatterns == 0 then
        PLAY_ROUND.MovementHistory = {}
        return PLAY_ROUND.MovementPatterns[math.random(1, #PLAY_ROUND.MovementPatterns)]
    end
    
    local selectedPattern = availablePatterns[math.random(1, #availablePatterns)]
    table.insert(PLAY_ROUND.MovementHistory, selectedPattern)
    
    if #PLAY_ROUND.MovementHistory > PLAY_ROUND.MaxMovementHistory then
        table.remove(PLAY_ROUND.MovementHistory, 1)
    end
    
    return selectedPattern
end

local function determineRole()
    local knife = localPlayer.Backpack:FindFirstChild("Knife") or localPlayer.Character:FindFirstChild("Knife")
    local gun = localPlayer.Backpack:FindFirstChild("Gun") or localPlayer.Character:FindFirstChild("Gun")

    if knife then
        PLAY_ROUND.CurrentRole = "Murderer"
    elseif gun then
        PLAY_ROUND.CurrentRole = "Sheriff"
    else
        PLAY_ROUND.CurrentRole = "Innocent"
    end
end

local function findClosestPlayerWithTool(toolName)
    local closestPlayer = nil
    local closestDistance = math.huge
    local myRoot = getRoot(localPlayer.Character)
    if not myRoot then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and not blacklistedPlayers[player.Name] then
            local targetRoot = getRoot(player.Character)
            if targetRoot then
                local distance = (targetRoot.Position - myRoot.Position).Magnitude
                if distance < closestDistance then
                    local hasTool = false
                    if player.Character:FindFirstChild(toolName) or 
                        (player.Backpack and player.Backpack:FindFirstChild(toolName)) then
                        hasTool = true
                    end
                    if hasTool then
                        closestPlayer = player
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function findClosestPlayerWithoutTool(toolName)
    local closestPlayer = nil
    local closestDistance = math.huge
    local myRoot = getRoot(localPlayer.Character)
    if not myRoot then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and not blacklistedPlayers[player.Name] then
            local targetRoot = getRoot(player.Character)
            if targetRoot then
                local distance = (targetRoot.Position - myRoot.Position).Magnitude
                if distance < closestDistance then
                    local hasTool = false
                    if player.Character:FindFirstChild(toolName) or 
                        (player.Backpack and player.Backpack:FindFirstChild(toolName)) then
                        hasTool = true
                    end
                    if not hasTool then
                        closestPlayer = player
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function findRandomSafePosition()
    local myRoot = getRoot(localPlayer.Character)
    if not myRoot then return nil end

    for i = 1, 10 do
        local direction = Vector3.new(
            math.random() * 2 - 1,
            0,
            math.random() * 2 - 1
        ).Unit

        local distance = math.random(10, 50)
        local testPos = myRoot.Position + (direction * distance)
        testPos = Vector3.new(testPos.X, myRoot.Position.Y, testPos.Z)

        if isPositionSafe(testPos) then
            return testPos
        end
    end
    return nil
end

local function playRoundChat()
    if os.time() - PLAY_ROUND.LastChatTime < PLAY_ROUND.ChatCooldown then return end
    PLAY_ROUND.LastChatTime = os.time()
    PLAY_ROUND.ChatCooldown = math.random(10, 30)

    local messages = PLAY_ROUND.ChatMessages[PLAY_ROUND.CurrentRole]
    if messages and #messages > 0 then
        makeStandSpeak(messages[math.random(1, #messages)])
    end
end

local function handleMurdererBehavior(humanoid, myRoot)
    local target = findClosestPlayerWithoutTool("Knife")
    if not target or not target.Character then
        local randomPos = findRandomSafePosition()
        if randomPos then
            humanoid:MoveTo(randomPos)
        end
        return
    end

    local targetRoot = getRoot(target.Character)
    if not targetRoot then return end

    local distance = (targetRoot.Position - myRoot.Position).Magnitude

    local knife = localPlayer.Backpack:FindFirstChild("Knife") or localPlayer.Character:FindFirstChild("Knife")
    if distance < 10 then
        if knife and knife.Parent ~= localPlayer.Character then
            knife.Parent = localPlayer.Character
        end

        if localPlayer.Character:FindFirstChild("Knife") then
            myRoot.CFrame = CFrame.new(targetRoot.Position - (targetRoot.CFrame.LookVector * 2), targetRoot.Position)
            simulateClick()
        end
    else
        if not PLAY_ROUND.Path then
            PLAY_ROUND.Path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true
            })
        end

        PLAY_ROUND.Path:ComputeAsync(myRoot.Position, targetRoot.Position)

        if PLAY_ROUND.Path.Status == Enum.PathStatus.Success then
            local waypoints = PLAY_ROUND.Path:GetWaypoints()
            if #waypoints > 1 then
                humanoid:MoveTo(waypoints[2].Position)
                if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
            end
        else
            humanoid:MoveTo(targetRoot.Position)
        end
    end
end

local function handleSheriffBehavior(humanoid, myRoot)
    local target = findClosestPlayerWithTool("Knife")
    if not target or not target.Character then
        local randomPos = findRandomSafePosition()
        if randomPos then
            humanoid:MoveTo(randomPos)
        end
        return
    end

    local targetRoot = getRoot(target.Character)
    if not targetRoot then return end

    local distance = (targetRoot.Position - myRoot.Position).Magnitude

    local gun = localPlayer.Backpack:FindFirstChild("Gun") or localPlayer.Character:FindFirstChild("Gun")
    if distance < 20 then
        if gun and gun.Parent ~= localPlayer.Character then
            gun.Parent = localPlayer.Character
        end

        if localPlayer.Character:FindFirstChild("Gun") then
            local predictedPos = calculatePredictedPosition(targetRoot, "Gun")
            myRoot.CFrame = CFrame.new(myRoot.Position, predictedPos)

            local args = {
                1,
                predictedPos,
                "AH2"
            }
            local remote = gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
            if remote then
                remote:InvokeServer(unpack(args))
            end
        end
    else
        local approachPos = targetRoot.Position - (targetRoot.CFrame.LookVector * 15)
        approachPos = Vector3.new(approachPos.X, targetRoot.Position.Y, approachPos.Z)

        if not PLAY_ROUND.Path then
            PLAY_ROUND.Path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true
            })
        end

        PLAY_ROUND.Path:ComputeAsync(myRoot.Position, approachPos)

        if PLAY_ROUND.Path.Status == Enum.PathStatus.Success then
            local waypoints = PLAY_ROUND.Path:GetWaypoints()
            if #waypoints > 1 then
                humanoid:MoveTo(waypoints[2].Position)
                if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
            end
        else
            humanoid:MoveTo(approachPos)
        end
    end
end

local function handleInnocentBehavior(humanoid, myRoot)
    local murderer = findClosestPlayerWithTool("Knife")
    if murderer and murderer.Character then
        local murdererRoot = getRoot(murderer.Character)
        if murdererRoot then
            local distance = (murdererRoot.Position - myRoot.Position).Magnitude
            if distance < 30 then
                local fleeDirection = (myRoot.Position - murdererRoot.Position).Unit
                local fleePos = myRoot.Position + (fleeDirection * 20)
                fleePos = Vector3.new(fleePos.X, myRoot.Position.Y, fleePos.Z)

                if not PLAY_ROUND.Path then
                    PLAY_ROUND.Path = PathfindingService:CreatePath({
                        AgentRadius = 2,
                        AgentHeight = 5,
                        AgentCanJump = true
                    })
                end

                PLAY_ROUND.Path:ComputeAsync(myRoot.Position, fleePos)

                if PLAY_ROUND.Path.Status == Enum.PathStatus.Success then
                    local waypoints = PLAY_ROUND.Path:GetWaypoints()
                    if #waypoints > 1 then
                        humanoid:MoveTo(waypoints[2].Position)
                        if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                            humanoid.Jump = true
                        end
                    end
                else
                    humanoid:MoveTo(fleePos)
                end
                return
            end
        end
    end

    local sheriff = findClosestPlayerWithTool("Gun")
    if sheriff and sheriff.Character then
        local sheriffRoot = getRoot(sheriff.Character)
        if sheriffRoot then
            local distance = (sheriffRoot.Position - myRoot.Position).Magnitude
            if distance > 15 then
                local followPos = sheriffRoot.Position - (sheriffRoot.CFrame.LookVector * 10)
                followPos = Vector3.new(followPos.X, sheriffRoot.Position.Y, followPos.Z)

                if not PLAY_ROUND.Path then
                    PLAY_ROUND.Path = PathfindingService:CreatePath({
                        AgentRadius = 2,
                        AgentHeight = 5,
                        AgentCanJump = true
                    })
                end

                PLAY_ROUND.Path:ComputeAsync(myRoot.Position, followPos)

                if PLAY_ROUND.Path.Status == Enum.PathStatus.Success then
                    local waypoints = PLAY_ROUND.Path:GetWaypoints()
                    if #waypoints > 1 then
                        humanoid:MoveTo(waypoints[2].Position)
                        if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                            humanoid.Jump = true
                        end
                    end
                else
                    humanoid:MoveTo(followPos)
                end
                return
            end
        end
    end

    local currentTime = os.clock()
    if currentTime - PLAY_ROUND.LastMovementChange > PLAY_ROUND.MovementDuration then
        PLAY_ROUND.CurrentMovement = getRandomMovementPattern()
        PLAY_ROUND.LastMovementChange = currentTime
        PLAY_ROUND.MovementDuration = 2 + math.random() * 3
    end

    if PLAY_ROUND.CurrentMovement == "Wander" then
        local randomPos = findRandomSafePosition()
        if randomPos then
            humanoid:MoveTo(randomPos)
        end
    elseif PLAY_ROUND.CurrentMovement == "CircleLeft" then
        local center = myRoot.Position + myRoot.CFrame.LookVector * 5
        local angle = currentTime * 2
        local circlePos = center + Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
        humanoid:MoveTo(circlePos)
    elseif PLAY_ROUND.CurrentMovement == "CircleRight" then
        local center = myRoot.Position + myRoot.CFrame.LookVector * 5
        local angle = currentTime * -2
        local circlePos = center + Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
        humanoid:MoveTo(circlePos)
    elseif PLAY_ROUND.CurrentMovement == "Pause" then
        -- Do nothing
    elseif PLAY_ROUND.CurrentMovement == "RandomJumps" then
        if math.random() < 0.3 then
            humanoid.Jump = true
        end
        local randomPos = findRandomSafePosition()
        if randomPos then
            humanoid:MoveTo(randomPos)
        end
    elseif PLAY_ROUND.CurrentMovement == "ZigZag" then
        local zigzag = math.sin(currentTime * 5) * 5
        local forwardPos = myRoot.Position + myRoot.CFrame.LookVector * 5
        local zigzagPos = forwardPos + myRoot.CFrame.RightVector * zigzag
        humanoid:MoveTo(zigzagPos)
    end
end

local function checkForGunDrop()
    if os.time() - PLAY_ROUND.LastGunCheck < PLAY_ROUND.GunCheckInterval then return nil end
    PLAY_ROUND.LastGunCheck = os.time()
    
    local gunDrop = findGunDrop()
    if not gunDrop then return nil end
    
    local myRoot = getRoot(localPlayer.Character)
    if not myRoot then return nil end
    
    local distance = (gunDrop.Position - myRoot.Position).Magnitude
    if distance > 50 then return nil end
    
    return gunDrop
end

local function handlePlayRound()
    if not PLAY_ROUND.Enabled or not localPlayer.Character then
        stopPlayRound()
        return
    end

    local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    local myRoot = getRoot(localPlayer.Character)
    if not humanoid or not myRoot then return end

    if os.time() - PLAY_ROUND.LastRoleCheck > 5 then
        PLAY_ROUND.LastRoleCheck = os.time()
        determineRole()
    end

    playRoundChat()

    local gunDrop = checkForGunDrop()
    if gunDrop and PLAY_ROUND.CurrentRole ~= "Sheriff" then
        if not PLAY_ROUND.Path then
            PLAY_ROUND.Path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true
            })
        end

        PLAY_ROUND.Path:ComputeAsync(myRoot.Position, gunDrop.Position)

        if PLAY_ROUND.Path.Status == Enum.PathStatus.Success then
            local waypoints = PLAY_ROUND.Path:GetWaypoints()
            if #waypoints > 1 then
                humanoid:MoveTo(waypoints[2].Position)
                if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
            end
        else
            humanoid:MoveTo(gunDrop.Position)
        end
        return
    end

    if PLAY_ROUND.CurrentRole == "Murderer" then
        handleMurdererBehavior(humanoid, myRoot)
    elseif PLAY_ROUND.CurrentRole == "Sheriff" then
        handleSheriffBehavior(humanoid, myRoot)
    else
        handleInnocentBehavior(humanoid, myRoot)
    end
end

local function startPlayRound()
    stopActiveCommand()
    activeCommand = "playround"
    PLAY_ROUND.Enabled = true
    PLAY_ROUND.LastRoleCheck = 0
    PLAY_ROUND.LastChatTime = 0
    PLAY_ROUND.CurrentMovement = "Wander"
    PLAY_ROUND.LastMovementChange = 0
    PLAY_ROUND.MovementHistory = {}

    determineRole()
    makeStandSpeak("... role: "..PLAY_ROUND.CurrentRole)

    PLAY_ROUND.Connection = RunService.Heartbeat:Connect(handlePlayRound)
end

local function stopPlayRound()
    PLAY_ROUND.Enabled = false
    if PLAY_ROUND.Connection then
        PLAY_ROUND.Connection:Disconnect()
        PLAY_ROUND.Connection = nil
    end
    PLAY_ROUND.CurrentTarget = nil
    if PLAY_ROUND.Path then
        PLAY_ROUND.Path:Destroy()
        PLAY_ROUND.Path = nil
    end

    if localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.AutoRotate = true
        end
    end
end

local function processCommandOriginal(speaker, message)
    if not message then return end
    local commandPrefix = message:match("^["..config.Prefix.."!]")
    if not commandPrefix then return end
    if tick() - lastCommandTime < commandDelay then return end
    lastCommandTime = tick()
    local args = {}
    for word in message:gmatch("%S+") do
        table.insert(args, word)
    end
    local cmd = args[1]:lower()

    if cmd == config.Prefix.."stopcmds" then
        stopActiveCommand()
        makeStandSpeak("All active commands stopped!")
    elseif cmd == config.Prefix.."rejoin" then
        makeStandSpeak("Rejoining game...")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
    elseif cmd == config.Prefix.."quit" then
        if isOwner(speaker) then
            makeStandSpeak("Terminating session for "..speaker.Name.."!")
            wait(0.5)
            speaker:Kick("Admin-requested termination")
        else
            checkAdminLeft()
        end
    elseif cmd == config.Prefix.."follow" and args[2] then
        local targetName = args[2]:lower()
        if targetName == "murder" then
            local target = findPlayerWithTool("Knife")
            if target then
                owners = {target}
                followOwners()
                makeStandSpeak("Tracking murderer!")
            else
                makeStandSpeak("No murderer found")
            end
        elseif targetName == "sheriff" then
            local target = findPlayerWithTool("Gun")
            if target then
                owners = {target}
                followOwners()
                makeStandSpeak("Following sheriff!")
            else
                makeStandSpeak("No sheriff found")
            end
        elseif targetName == "random" then
            local target = getRandomPlayer()
            if target then
                owners = {target}
                followOwners()
                makeStandSpeak("Following random player "..target.Name)
            else
                makeStandSpeak("No random player found")
            end
        else
            local target = findTarget(table.concat(args, " ", 2))
            if target then
                owners = {target}
                followOwners()
                makeStandSpeak("Following "..target.Name)
            else
                makeStandSpeak("Target not found")
            end
        end
    elseif cmd == config.Prefix.."protect" and args[2] then
        if args[2]:lower() == "on" then
            startProtection()
        elseif args[2]:lower() == "off" then
            stopProtection()
        end
    elseif cmd == config.Prefix.."say" and args[2] then
        makeStandSpeak(table.concat(args, " ", 2))
    elseif cmd == config.Prefix.."reset" then
        resetStand()
    elseif cmd == config.Prefix.."hide" then
        hideStand()
    elseif cmd == config.Prefix.."dismiss" then
        dismissStand()
    elseif cmd == config.Prefix.."summon" then
        summonStand(speaker)
    elseif cmd == config.Prefix.."autofarm" and args[2] then
        if args[2]:lower() == "on" then
            autoFarm()
        elseif args[2]:lower() == "off" then
            stopAutoFarm()
        end
    elseif cmd == config.Prefix.."fling" and args[2] then
        local targetName = args[2]:lower()
        if targetName == "all" then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer and not blacklistedPlayers[player.Name] then
                    spawn(function() flingPlayer(player) end)
                end
            end
            makeStandSpeak("Launching everyone!")
        elseif targetName == "murder" then
            local target = findPlayerWithTool("Knife")
            if target then
                flingPlayer(target)
                makeStandSpeak("Eliminating murderer!")
            else
                makeStandSpeak("No murderer found")
            end
        elseif targetName == "sheriff" then
            local target = findPlayerWithTool("Gun")
            if target then
                flingPlayer(target)
                makeStandSpeak("Taking down sheriff!")
            else
                makeStandSpeak("No sheriff found")
            end
        elseif targetName == "random" then
            local target = getRandomPlayer()
            if target then
                flingPlayer(target)
                makeStandSpeak("Flinging random player "..target.Name)
            else
                makeStandSpeak("No random player found")
            end
        else
            local target = findTarget(table.concat(args, " ", 2))
            if target then
                flingPlayer(target)
                makeStandSpeak("Target locked!")
            else
                makeStandSpeak("Target not found")
            end
        end
    elseif cmd == config.Prefix.."bringgun" then
        stealGun(speaker)
    elseif cmd == config.Prefix.."whitelist" and args[2] then
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            whitelistPlayer(target.Name)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."blacklist" and args[2] then
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            blacklistPlayer(target.Name)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."addowner" and args[2] then
        if not isMainOwner(speaker) then
            local mainOwner = getMainOwner()
            local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
            makeStandSpeak("Only "..ownerName.." can use this command!")
            return
        end
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            addOwner(target.Name)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."headadmin" and args[2] then
        if not isMainOwner(speaker) then
            local mainOwner = getMainOwner()
            local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
            makeStandSpeak("Only "..ownerName.." can use this command!")
            return
        end
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            addHeadAdmin(target.Name)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."addadmin" and args[2] then
        if not isMainOwner(speaker) then
            local mainOwner = getMainOwner()
            local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
            makeStandSpeak("Only "..ownerName.." can use this command!")
            return
        end
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            addAdmin(target.Name)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."removeadmin" and args[2] then
        if not isMainOwner(speaker) then
            local mainOwner = getMainOwner()
            local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
            makeStandSpeak("Only "..ownerName.." can use this command!")
            return
        end
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            removeAdmin(target.Name)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."sus" and args[2] then
        local targetName = args[2]:lower()
        local speed = tonumber(args[3])
        if targetName == "murder" then
            local target = findPlayerWithTool("Knife")
            if target then
                startSus(target, speed)
            else
                makeStandSpeak("No murderer found")
            end
        elseif targetName == "sheriff" then
            local target = findPlayerWithTool("Gun")
            if target then
                startSus(target, speed)
            else
                makeStandSpeak("No sheriff found")
            end
        elseif targetName == "random" then
            local target = getRandomPlayer()
            if target then
                startSus(target, speed)
                makeStandSpeak("Sussing random player "..target.Name)
            else
                makeStandSpeak("No random player found")
            end
        else
            local target = findTarget(table.concat(args, " ", 2))
            if target then
                startSus(target, speed)
            else
                makeStandSpeak("Target not found")
            end
        end
    elseif cmd == config.Prefix.."stopsus" then
        stopSus()
    elseif cmd == config.Prefix.."eliminate" then
        if args[2] and args[2]:lower() == "random" then
            local target = getRandomPlayer()
            if target then
                owners = {target}
                eliminatePlayers()
            else
                makeStandSpeak("No random player found")
            end
        else
            eliminatePlayers()
        end
    elseif cmd == config.Prefix.."eliminateall" then
        eliminateAllPlayers()
    elseif cmd == config.Prefix.."win" and args[2] then
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            winGame(target)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."commands" then
        showCommandsForRank(speaker)
    elseif cmd == config.Prefix.."disable" and args[2] then
        if not isMainOwner(speaker) then
            local mainOwner = getMainOwner()
            local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
            makeStandSpeak("Only "..ownerName.." can use this command!")
            return
        end
        disableCommand(args[2])
    elseif cmd == config.Prefix.."enable" and args[2] then
        if not isMainOwner(speaker) then
            local mainOwner = getMainOwner()
            local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
            makeStandSpeak("Only "..ownerName.." can use this command!")
            return
        end
        enableCommand(args[2])
    elseif cmd == config.Prefix.."describe" and args[2] then
        local messages = describePlayer(table.concat(args, " ", 2))
        for _, msg in ipairs(messages) do
            makeStandSpeak(msg)
            task.wait(1.5)
        end
    elseif cmd == config.Prefix.."shoot" and args[2] then
        local targetName = args[2]:lower()
        if targetName == "murder" then
            local target = findPlayerWithTool("Knife")
            if target then
                startShooting(target)
                makeStandSpeak("Shooting murderer!")
            else
                makeStandSpeak("No murderer found")
            end
        else
            local target = findTarget(table.concat(args, " ", 2))
            if target then
                startShooting(target)
                makeStandSpeak("Shooting target!")
            else
                makeStandSpeak("Target not found")
            end
        end
    elseif cmd == config.Prefix.."trade" and args[2] then
        local target = findTarget(table.concat(args, " ", 2))
        if target then
            tradePlayer(target)
        else
            makeStandSpeak("Player not found")
        end
    elseif cmd == config.Prefix.."quiet" and args[2] then
        if args[2]:lower() == "on" then
            quietModeUsers[speaker.Name] = true
            makeStandSpeak("Quiet mode enabled for you. I'll whisper responses.")
        elseif args[2]:lower() == "off" then
            quietModeUsers[speaker.Name] = nil
            makeStandSpeak("Quiet mode disabled. I'll speak normally.")
        end
    elseif cmd == config.Prefix.."spy" and args[2] then
        if args[2]:lower() == "on" then
            startSpyMode()
        elseif args[2]:lower() == "off" then
            stopSpyMode()
        end
    elseif cmd == config.Prefix.."prefix" and args[2] then
        if not isMainOwner(speaker) then
            local mainOwner = getMainOwner()
            local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
            makeStandSpeak("Only "..ownerName.." can use this command!")
            return
        end

        local newPrefix = args[2]
        if #newPrefix ~= 1 then
            makeStandSpeak("Prefix must be a single character!")
            return
        end

        local isValid = false
        for _, allowedPrefix in ipairs(config.AllowedPrefixes) do
            if newPrefix == allowedPrefix then
                isValid = true
                break
            end
        end

        if not isValid then
            makeStandSpeak("Invalid prefix! Allowed prefixes: "..table.concat(config.AllowedPrefixes, ", "))
            return
        end

        config.Prefix = newPrefix
        makeStandSpeak("Command prefix changed to: "..newPrefix)
    elseif cmd == config.Prefix.."pvp" and args[2] then
        if args[2]:lower() == "on" then
            local targetName = args[3] and args[3]:lower() or "random"
            local target = nil
            
            if targetName == "murder" then
                target = findPlayerWithTool("Knife")
            elseif targetName == "sheriff" then
                target = findPlayerWithTool("Gun")
            elseif targetName == "random" then
                target = getRandomPlayer()
            else
                target = findTarget(table.concat(args, " ", 3))
            end
            
            if target then
                startPVPMode(target)
                makeStandSpeak("1v1 mode activated against "..target.Name)
            else
                makeStandSpeak("Target not found for 1v1")
            end
        elseif args[2]:lower() == "off" then
            stopPVPMode()
            makeStandSpeak("1v1 mode deactivated")
        end
    elseif cmd == config.Prefix.."playround" and args[2] then
        if args[2]:lower() == "on" then
            startPlayRound()
            makeStandSpeak("AI play mode activated!")
        elseif args[2]:lower() == "off" then
            stopPlayRound()
            makeStandSpeak("AI play mode deactivated")
        end
    end
end

local function processCommand(speaker, message)
    if not message then return end
    local commandPrefix = message:match("^["..config.Prefix.."!]")
    if not commandPrefix then return end

    if message:sub(1,1) == "!" then
        local cmd = message:match("^([^%s]+)"):lower()

        if cmd == "!pricing" then
            showPricing(speaker)
            return
        elseif cmd == "!freetrial" then
            if isOwner(speaker) or isHeadAdmin(speaker) or isAdmin(speaker) then
                makeStandSpeak("You already have "..(isOwner(speaker) and "owner" or isHeadAdmin(speaker) and "headadmin" or "admin").." privileges!")
                return
            end
            if not isFreeTrial(speaker) then
                table.insert(getgenv().FreeTrial, speaker.Name)
                makeStandSpeak("Thanks for redeeming free trial! You have 5 minutes to use commands.")
                showCommandsForRank(speaker)
                spawn(function() processFreeTrial(speaker) end)
            else
                makeStandSpeak("You already have an active free trial")
            end
            return
        elseif cmd == "!checkrole" then
            local args = {}
            for word in message:gmatch("%S+") do
                table.insert(args, word)
            end
            if not args[2] then
                makeStandSpeak("Usage: !checkrole <username>")
                return
            end

            local target = findTarget(table.concat(args, " ", 2))
            if not target then
                makeStandSpeak("Player not found.")
                return
            end

            local role = "No special role"
            if isOwner(target) then
                role = "Owner"
            elseif isHeadAdmin(target) then
                role = "HeadAdmin"
            elseif isAdmin(target) then
                role = "Admin"
            elseif isFreeTrial(target) then
                role = "Free Trial User"
            end

            makeStandSpeak(target.Name.." is "..role..".")
            return
        end
    end

    if speaker ~= localPlayer then
        if not hasAdminPermissions(speaker) then
            makeStandSpeak("Hi "..speaker.Name..", unfortunately you can't use commands. Try !freetrial to try out or !pricing to buy.")
            return
        end

        if isPlayerSuspended(speaker.Name) then
            local remaining = suspendedPlayers[speaker.Name] - os.time()
            makeStandSpeak(speaker.Name.." is suspended for "..math.floor(remaining).." more seconds")
            return
        end
        local currentTime = os.time()
        commandCooldowns[speaker.Name] = commandCooldowns[speaker.Name] or 0
        if currentTime - commandCooldowns[speaker.Name] < 1 then
            warnCommandAbuse(speaker)
            return
        end
        commandCooldowns[speaker.Name] = currentTime
    end

    if message:sub(1,1) == config.Prefix then
        local cmd = message:match("^([^%s]+)"):lower()

        if cmd == config.Prefix.."commands" then
            showCommandsForRank(speaker)
            return
        end

        if not checkCommandPermissions(speaker, cmd) then
            makeStandSpeak(speaker.Name..", you don't have permission for this command")
            return
        end
        if isCommandDisabled(cmd) then
            makeStandSpeak("This command is currently disabled")
            return
        end

        processCommandOriginal(speaker, message)
    end
end

local function setupChatListeners()
    for _, player in ipairs(Players:GetPlayers()) do
        player.Chatted:Connect(function(message)
            respondToChat(player, message)
            processCommand(player, message)

            if PVP_MODE.Enabled and PVP_MODE.Target and player == PVP_MODE.Target then
                local msg = message:lower()
                if msg == "go" then
                    PVP_MODE.WaitingForResponse = false
                    PVP_MODE.Countdown = 3.5
                    makeStandSpeak("Accepted! Starting in 3...")
                elseif msg == "no" then
                    makeStandSpeak("Aww ok ):")
                    if PVP_MODE.CombatStyle == "Gun" then
                        startShooting(PVP_MODE.Target)
                    else
                        owners = {PVP_MODE.Target}
                        eliminatePlayers()
                    end
                    stopPVPMode()
                end
            end
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(message)
            respondToChat(player, message)
            processCommand(player, message)
        end)
    end)

    if TextChatService then
        TextChatService.MessageReceived:Connect(function(message)
            if message.TextSource then
                local speaker = Players:GetPlayerByUserId(message.TextSource.UserId)
                if speaker then
                    if message.Metadata and message.Metadata["PrivateMessage"] then
                        local recipient = Players:GetPlayerByUserId(message.Metadata["PrivateMessage"].RecipientId)
                        if recipient then
                            processWhisper(speaker, recipient, message.Text)
                        end
                    end
                    respondToChat(speaker, message.Text)
                end
            end
        end)
    end

    Players.PlayerRemoving:Connect(function(player)
        if hasAdminPermissions(player) then
            checkAdminLeft()
        end
        if PVP_MODE.Enabled and PVP_MODE.Target and player == PVP_MODE.Target then
            stopPVPMode()
        end
    end)
end

if localPlayer then
    owners = findOwners()
    if #owners > 0 then
        disablePlayerMovement()
        followOwners()
        makeStandSpeak(getgenv().Configuration.Msg)
    end
    local success, err = pcall(function()
        setupChatListeners()
    end)
    if not success then
        warn("Failed to setup listeners: "..tostring(err))
    end
    script.Destroying:Connect(function()
        dismissStand()
        stopSus()
        stopPVPMode()
        stopPlayRound()
        stopSpyMode()
    end)
else
    warn("LocalPlayer not found!")
end
