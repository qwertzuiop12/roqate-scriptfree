local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ChatService = game:GetService("Chat")
local TextChatService = game:GetService("TextChatService")
local localPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLLOW_OFFSET = Vector3.new(0, 3, 5)
local MOVEMENT_SMOOTHNESS = 0.1
local PROTECTION_RADIUS = 15
local SUS_ANIMATION_R6 = "72042024"
local SUS_ANIMATION_R15 = "698251653"
local STAND_ANIMATION_ID = "10714347256"

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
local commandDelay = 0.5
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
local rudePhrases = {"pmo", "sybau", "syfm", "stfu", "kys", "idc", "suck my","shut"}
local randomTargets = {}
local activeCommand = nil
local susBlock = nil
local followBlock = nil

local function isOwner(player)
	for _, ownerName in ipairs(getgenv().Owners) do
		if player.Name == ownerName or (player.DisplayName and player.DisplayName == ownerName) then
			return true, "owner"
		end
	end
	return false
end

local function isHeadAdmin(player)
	for _, name in ipairs(getgenv().HeadAdmins) do
		if player.Name == name or (player.DisplayName and player.DisplayName == name) then
			return true, "headadmin"
		end
	end
	return false
end

local function isAdmin(player)
	for _, name in ipairs(getgenv().Admins) do
		if player.Name == name or (player.DisplayName and player.DisplayName == name) then
			return true, "admin"
		end
	end
	return false
end

local function isFreeTrial(player)
	for _, name in ipairs(getgenv().FreeTrial) do
		if player.Name == name or (player.DisplayName and player.DisplayName == name) then
			return true, "freetrial"
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
		task.wait(300)
		for i, name in ipairs(getgenv().FreeTrial) do
			if name == player.Name then
				table.remove(getgenv().FreeTrial, i)
				makeStandSpeak(player.Name.."'s free trial has ended")
				break
			end
		end
	end
end

local function showPricing(speaker)
	makeStandSpeak("Admin costs 100 Robux or 1 godly (Basic commands)")
	task.wait(1)
	makeStandSpeak("Head Admin costs 500 Robux or 5 godly (Can sell admin)")
	task.wait(1)
	makeStandSpeak("Type !freetrial to test commands for 5 minutes")
	task.wait(1)
	local availableAdmins = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if isOwner(player) or isHeadAdmin(player) then
			table.insert(availableAdmins, player.Name)
		end
	end
	if #availableAdmins > 0 then
		makeStandSpeak("Available to pay: " .. table.concat(availableAdmins, ", "))
	else
		makeStandSpeak("No admins available right now")
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
		makeStandSpeak("You don't have permission to use commands. Type .pricing or .freetrial")
		return
	end

	local commands = {
		owner = {
			".follow", ".protect", ".say", ".reset", ".hide", ".dismiss", ".summon", 
			".fling", ".bringgun", ".whitelist", ".addowner", ".addadmin", ".removeadmin", 
			".sus", ".stopsus", ".eliminate", ".win", ".commands", ".disable", ".enable", 
			".stopcmds", ".rejoin", ".quit", ".describe", ".headadmin", ".pricing", ".freetrial", ".trade", ".eliminateall", ".shoot", ".breakgun", ".fireshot"
		},
		headadmin = {
			".follow", ".protect", ".say", ".reset", ".hide", ".dismiss", ".summon", 
			".fling", ".bringgun", ".whitelist", ".addadmin", ".sus", ".stopsus", 
			".eliminate", ".win", ".commands", ".stopcmds", ".rejoin", ".describe", ".pricing", ".freetrial", ".trade", ".shoot", ".breakgun", ".fireshot"
		},
		admin = {
			".follow", ".protect", ".say", ".reset", ".hide", ".dismiss", ".summon", 
			".fling", ".bringgun", ".sus", ".stopsus", ".eliminate", ".win", 
			".commands", ".stopcmds", ".describe", ".pricing", ".freetrial", ".trade", ".shoot", ".breakgun", ".fireshot"
		},
		freetrial = {
			".follow", ".protect", ".say", ".reset", ".hide", ".dismiss", ".summon", 
			".fling", ".bringgun", ".sus", ".stopsus", ".eliminate", ".win", 
			".commands", ".stopcmds", ".describe", ".pricing", ".shoot", ".breakgun", ".fireshot"
		}
	}

	makeStandSpeak("Commands for "..rank..":")
	for i, cmd in ipairs(commands[rank]) do
		if i % 5 == 0 then
			task.wait(1)
		end
		makeStandSpeak(cmd)
	end
end

local function checkCommandPermissions(speaker, cmd)
	if isOwner(speaker) then return true end

	if isHeadAdmin(speaker) then
		if cmd == ".addowner" or cmd == ".removeadmin" or cmd == ".disable" or cmd == ".enable" or cmd == ".quit" then
			return false
		end
		return true
	end

	if isAdmin(speaker) then
		if cmd == ".addowner" or cmd == ".addadmin" or cmd == ".removeadmin" or cmd == ".whitelist" or 
			cmd == ".disable" or cmd == ".enable" or cmd == ".quit" or cmd == ".headadmin" then
			return false
		end
		return true
	end

	if isFreeTrial(speaker) then
		if cmd == ".addowner" or cmd == ".addadmin" or cmd == ".removeadmin" or cmd == ".whitelist" or 
			cmd == ".disable" or cmd == ".enable" or cmd == ".quit" or cmd == ".headadmin" or cmd == ".trade" or cmd == ".eliminateall" then
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
	end
	flinging = false
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

local function makeStandSpeak(message)
	if not localPlayer.Character then return end
	local head = localPlayer.Character:FindFirstChild("Head")
	if head then
		ChatService:Chat(head, message, Enum.ChatColor.White)
	end
	if TextChatService and TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral then
		TextChatService.TextChannels.RBXGeneral:SendAsync(message)
	end
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
		if player ~= localPlayer then
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
		if player == localPlayer then continue end
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
		if player == localPlayer then continue end
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
						if player ~= localPlayer and player.Character then
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

	if not equipKnife() then
		makeStandSpeak("No knife found!")
		return
	end

	makeStandSpeak("Initiating elimination protocol!")
	local knife = localPlayer.Character:FindFirstChild("Knife")
	if not knife then return end

	local eliminated = {}
	local startTime = tick()

	while activeCommand == "eliminate" do
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Character then
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

	if knife then knife.Parent = localPlayer.Backpack end
	makeStandSpeak("Elimination protocol complete!")
end

local function eliminateAllPlayers(speaker)
	stopActiveCommand()
	activeCommand = "eliminateall"

	if not equipKnife() then
		makeStandSpeak("No knife found!")
		return
	end

	makeStandSpeak("Initiating mass elimination!")
	local knife = localPlayer.Character:FindFirstChild("Knife")
	if not knife then return end

	if not speaker or not speaker.Character then return end
	local speakerRoot = getRoot(speaker.Character)
	if not speakerRoot then return end

	local myRoot = getRoot(localPlayer.Character)
	if not myRoot then return end

	myRoot.CFrame = speakerRoot.CFrame * CFrame.new(0, 0, -2)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local targetRoot = getRoot(player.Character)
				if targetRoot then
					targetRoot.Anchored = true
					targetRoot.CFrame = speakerRoot.CFrame * CFrame.new(math.random(-5,5), 0, math.random(-5,5))
				end
			end
		end
	end

	for i = 1, 100 do
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

	if knife then knife.Parent = localPlayer.Backpack end
	makeStandSpeak("GG, elimination complete!")
end

local function winGame(targetPlayer)
	stopActiveCommand()

	if not targetPlayer or targetPlayer == localPlayer then return end
	makeStandSpeak("Making "..targetPlayer.Name.." the winner!")

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player ~= targetPlayer then
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
					resetStand()
				end
			end
		end
		return
	end

	local gunDrop = findGunDrop()
	if not gunDrop then
		makeStandSpeak("Gun is not on the floor yet!")
		return
	end

	makeStandSpeak("Found gun!")
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
	if not targetPlayer or not targetPlayer.Character then return end
	
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
	
	if not gun then
		makeStandSpeak("No gun found!")
		return
	end

	makeStandSpeak("Shooting "..targetPlayer.Name.."!")
	
	local targetRoot = getRoot(targetPlayer.Character)
	local myRoot = getRoot(localPlayer.Character)
	if not targetRoot or not myRoot then return end
	
	local originalPos = myRoot.CFrame
	myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -2)
	
	if workspace.CurrentCamera then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = CFrame.new(myRoot.Position + Vector3.new(0, 3, -5), myRoot.Position)
	end
	
	gun.Parent = localPlayer.Character
	
	local args = {
		1,
		targetRoot.Position,
		"AH2"
	}
	
	local remote = gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
	if remote then
		remote:InvokeServer(unpack(args))
	end
	
	task.wait(0.2)
	
	if workspace.CurrentCamera then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
	
	myRoot.CFrame = originalPos
end

local function breakGun(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then return end
	
	makeStandSpeak("Breaking gun on "..targetPlayer.Name.."!")
	
	local args = {
		1,
		Vector3.new(math.huge, math.huge, math.huge),
		"AH2"
	}
	
	local gun = targetPlayer.Backpack:FindFirstChild("Gun") or targetPlayer.Character:FindFirstChild("Gun")
	if gun then
		local remote = gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
		if remote then
			remote:InvokeServer(unpack(args))
		end
	end
end

local function fireShot(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then return end
	
	local shooter = nil
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			local gun = player.Backpack:FindFirstChild("Gun") or player.Character:FindFirstChild("Gun")
			if gun then
				shooter = player
				break
			end
		end
	end
	
	if not shooter then
		makeStandSpeak("No one is holding a gun!")
		return
	end
	
	local shooterRoot = getRoot(shooter.Character)
	local targetRoot = getRoot(targetPlayer.Character)
	if not shooterRoot or not targetRoot then return end
	
	if (shooterRoot.Position - targetRoot.Position).Magnitude > 10 then
		makeStandSpeak(shooter.Name.." is too far from "..targetPlayer.Name.."!")
		return
	end
	
	makeStandSpeak("Forcing "..shooter.Name.." to shoot "..targetPlayer.Name.."!")
	
	local gun = shooter.Backpack:FindFirstChild("Gun") or shooter.Character:FindFirstChild("Gun")
	if not gun then return end
	
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

local function tradePlayer(targetPlayer)
	if not targetPlayer then return end
	makeStandSpeak("Sending trade request to "..targetPlayer.Name)

	local args = {
		targetPlayer
	}

	local success, err = pcall(function()
		ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"):InvokeServer(unpack(args))
	end)

	if not success then
		makeStandSpeak("Failed to send trade request!")
	end
end

local function whitelistPlayer(playerName)
	table.insert(getgenv().Configuration.whitelist, playerName)
	makeStandSpeak("Added "..playerName.." to whitelist!")
end

local function addOwner(playerName)
	table.insert(getgenv().Owners, playerName)
	owners = findOwners()
	if #owners > 0 then
		followOwners()
	end
	makeStandSpeak("Added "..playerName.." as owner!")
end

local function addHeadAdmin(playerName)
	table.insert(getgenv().HeadAdmins, playerName)
	makeStandSpeak("Added "..playerName.." as head admin!")
end

local function addAdmin(playerName)
	table.insert(getgenv().Admins, playerName)
	makeStandSpeak("Added "..playerName.." as admin!")
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
	local r, g, b = skinColor.r * 255, skinColor.g * 255, skinColor.b * 255

	if r > 240 and g > 220 and b > 200 then return "Pale White"
	elseif r > 220 and g > 190 and b > 160 then return "Fair"
	elseif r > 200 and g > 170 and b > 140 then return "Light"
	elseif r > 180 and g > 150 and b > 120 then return "Medium Light"
	elseif r > 160 and g > 130 and b > 100 then return "Medium"
	elseif r > 140 and g > 110 and b > 80 then return "Tan"
	elseif r > 120 and g > 90 and b > 60 then return "Brown"
	elseif r > 100 and g > 70 and b > 40 then return "Dark Brown"
	elseif r > 80 and g > 50 and b > 30 then return "Dark"
	elseif r > 60 and g > 40 and b > 20 then return "Very Dark"
	else return "Custom Color" end
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
		local half = math.ceil(#accessories / 2)
		local firstHalf = {}
		local secondHalf = {}

		for i = 1, half do
			table.insert(firstHalf, accessories[i])
		end

		for i = half + 1, #accessories do
			table.insert(secondHalf, accessories[i])
		end

		if #firstHalf > 0 then
			table.insert(messages, "Accessories (1/"..(#accessories > 1 and "2" or "1").."): "..table.concat(firstHalf, ", "))
		end

		if #secondHalf > 0 then
			table.insert(messages, "Accessories (2/2): "..table.concat(secondHalf, ", "))
		end
	else
		table.insert(messages, "No accessories found")
	end

	return messages
end

local function checkCommandAbuse(speaker)
	if not isOwner(speaker) then return false end
	local mainOwner = getMainOwner()
	if mainOwner and speaker.Name == mainOwner.Name then return false end

	if isPlayerSuspended(speaker.Name) then
		local remaining = suspendedPlayers[speaker.Name] - os.time()
		makeStandSpeak(speaker.Name.." is suspended for "..remaining.." more seconds!")
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
		table.insert(murdererNames, isWhitelisted(player) and player.Name:sub(1,1) or player.Name)
	end

	for _, player in ipairs(sheriffs) do
		table.insert(sheriffNames, isWhitelisted(player) and player.Name:sub(1,1) or player.Name)
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

	local commandGroups = {
		".follow (user/murder/sheriff/random), .protect (on/off), .say (message), .reset, .hide",
		".dismiss, .summon, .fling (all/sheriff/murder/user/random), .bringgun, .whitelist (user)",
		".addowner (user), .removeadmin (user), .sus (user/murder/sheriff/random) (speed), .stopsus",
		".eliminate (random), .win (user), .commands, .disable (cmd), .enable (cmd), .stopcmds, .rejoin",
		".describe (user/murd/sheriff), .headadmin (user), .pricing, .freetrial, .trade (user), .eliminateall",
		".shoot (user/murd), .breakgun (user), .fireshot (user/murd)"
	}

	for _, group in ipairs(commandGroups) do
		makeStandSpeak(group)
		task.wait(1)
	end
end

local function checkRudeMessage(speaker, message)
	local mainOwner = getMainOwner()
	if mainOwner and speaker.Name == mainOwner.Name then return false end
	local msg = message:lower()
	for _, phrase in ipairs(rudePhrases) do
		if msg:find(phrase) then
			rudePlayers[speaker.Name] = true
			makeStandSpeak("Hey "..speaker.Name..", that's not cool! Don't say those things to my owner!")
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

local function respondToChat(speaker, message)
	if speaker == localPlayer then return end
	if tick() - lastResponseTime < 5 then return end

	if checkRudeMessage(speaker, message) then return end
	if checkApology(speaker, message) then return end

	local msg = message:lower()

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

	if msg:find("who is innocent") or msg:find("whos innocent") then
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
						names = names .. player.Name
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
						names = names .. player.Name
						if i < #sheriffs then
							names = names .. ", "
						end
					end
					return "Sheriff: " .. names .. "!"
				else
					return "No law around here!"
				end
			end
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

local function processCommandOriginal(speaker, message)
	if not message then return end
	local commandPrefix = message:match("^%.")
	if not commandPrefix then return end

	if tick() - lastCommandTime < commandDelay then return end
	lastCommandTime = tick()

	local args = {}
	for word in message:gmatch("%S+") do
		table.insert(args, word)
	end
	local cmd = args[1]:lower()

	if cmd == ".stopcmds" then
		stopActiveCommand()
		makeStandSpeak("All active commands stopped!")
	elseif cmd == ".rejoin" then
		makeStandSpeak("Rejoining game...")
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
	elseif cmd == ".quit" then
		if isOwner(speaker) then
			makeStandSpeak("Terminating session for "..speaker.Name.."!")
			wait(0.5)
			speaker:Kick("Admin-requested termination")
		else
			checkAdminLeft()
		end
	elseif cmd == ".follow" and args[2] then
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
	elseif cmd == ".protect" and args[2] then
		if args[2]:lower() == "on" then
			startProtection()
		elseif args[2]:lower() == "off" then
			stopProtection()
		end
	elseif cmd == ".say" and args[2] then
		makeStandSpeak(table.concat(args, " ", 2))
	elseif cmd == ".reset" then
		resetStand()
	elseif cmd == ".hide" then
		hideStand()
	elseif cmd == ".dismiss" then
		dismissStand()
	elseif cmd == ".summon" then
		summonStand(speaker)
	elseif cmd == ".fling" and args[2] then
		local targetName = args[2]:lower()
		if targetName == "all" then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= localPlayer then
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
	elseif cmd == ".bringgun" then
		stealGun(speaker)
	elseif cmd == ".whitelist" and args[2] then
		local target = findTarget(table.concat(args, " ", 2))
		if target then
			whitelistPlayer(target.Name)
		else
			makeStandSpeak("Player not found")
		end
	elseif cmd == ".addowner" and args[2] then
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
	elseif cmd == ".headadmin" and args[2] then
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
	elseif cmd == ".addadmin" and args[2] then
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
	elseif cmd == ".removeadmin" and args[2] then
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
	elseif cmd == ".sus" and args[2] then
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
	elseif cmd == ".stopsus" then
		stopSus()
	elseif cmd == ".eliminate" then
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
	elseif cmd == ".eliminateall" then
		eliminateAllPlayers(speaker)
	elseif cmd == ".win" and args[2] then
		local target = findTarget(table.concat(args, " ", 2))
		if target then
			winGame(target)
		else
			makeStandSpeak("Player not found")
		end
	elseif cmd == ".commands" then
		showCommandsForRank(speaker)
	elseif cmd == ".disable" and args[2] then
		if not isMainOwner(speaker) then
			local mainOwner = getMainOwner()
			local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
			makeStandSpeak("Only "..ownerName.." can use this command!")
			return
		end
		disableCommand(args[2])
	elseif cmd == ".enable" and args[2] then
		if not isMainOwner(speaker) then
			local mainOwner = getMainOwner()
			local ownerName = mainOwner and mainOwner.Name or getgenv().Owners[1]
			makeStandSpeak("Only "..ownerName.." can use this command!")
			return
		end
		enableCommand(args[2])
	elseif cmd == ".describe" and args[2] then
		local messages = describePlayer(table.concat(args, " ", 2))
		for _, msg in ipairs(messages) do
			makeStandSpeak(msg)
			task.wait(1.5)
		end
	elseif cmd == ".shoot" and args[2] then
		local targetName = args[2]:lower()
		if targetName == "murder" then
			local target = findPlayerWithTool("Knife")
			if target then
				shootPlayer(target)
			else
				makeStandSpeak("No murderer found")
			end
		else
			local target = findTarget(table.concat(args, " ", 2))
			if target then
				shootPlayer(target)
			else
				makeStandSpeak("Target not found")
			end
		end
	elseif cmd == ".breakgun" and args[2] then
		local targetName = args[2]:lower()
		if targetName == "murder" then
			local target = findPlayerWithTool("Knife")
			if target then
				breakGun(target)
			else
				makeStandSpeak("No murderer found")
			end
		else
			local target = findTarget(table.concat(args, " ", 2))
			if target then
				breakGun(target)
			else
				makeStandSpeak("Target not found")
			end
		end
	elseif cmd == ".fireshot" and args[2] then
		local targetName = args[2]:lower()
		if targetName == "murder" then
			local target = findPlayerWithTool("Knife")
			if target then
				fireShot(target)
			else
				makeStandSpeak("No murderer found")
			end
		else
			local target = findTarget(table.concat(args, " ", 2))
			if target then
				fireShot(target)
			else
				makeStandSpeak("Target not found")
			end
		end
	elseif cmd == "!pricing" then
		showPricing(speaker)
	elseif cmd == "!freetrial" then
		if isOwner(speaker) or isHeadAdmin(speaker) or isAdmin(speaker) then
			makeStandSpeak("You already have "..(isOwner(speaker) and "owner" or isHeadAdmin(speaker) and "headadmin" or "admin").." privileges!")
			return
		end
		if not isFreeTrial(speaker) then
			table.insert(getgenv().FreeTrial, speaker.Name)
			makeStandSpeak("Thanks for redeeming free trial! You have 5 minutes to use commands. Type .commands to see available commands")
			spawn(function() processFreeTrial(speaker) end)
		else
			makeStandSpeak("You already have an active free trial")
		end
	elseif cmd == ".trade" and args[2] then
		local target = findTarget(table.concat(args, " ", 2))
		if target then
			tradePlayer(target)
		else
			makeStandSpeak("Player not found")
		end
	end
end

local function processCommand(speaker, message)
	if not message then return end
	local commandPrefix = message:match("^[.!]")
	if not commandPrefix then return end

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
			makeStandSpeak("Thanks for redeeming free trial! You have 5 minutes to use commands. Type .commands to see available commands")
			spawn(function() processFreeTrial(speaker) end)
		else
			makeStandSpeak("You already have an active free trial")
		end
		return
	end

	if speaker ~= localPlayer then
		if not hasAdminPermissions(speaker) then
			makeStandSpeak("Hey "..speaker.Name..", you can't use commands. Type !pricing to see pricing or !freetrial to try it out")
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

	local args = {}
	for word in message:gmatch("%S+") do
		table.insert(args, word)
	end
	cmd = args[1]:lower()

	if cmd == ".pricing" then
		showPricing(speaker)
		return
	elseif cmd == ".freetrial" then
		if isOwner(speaker) or isHeadAdmin(speaker) or isAdmin(speaker) then
			makeStandSpeak("You already have "..(isOwner(speaker) and "owner" or isHeadAdmin(speaker) and "headadmin" or "admin").." privileges!")
			return
		end
		if not isFreeTrial(speaker) then
			table.insert(getgenv().FreeTrial, speaker.Name)
			makeStandSpeak("Thanks for redeeming free trial! You have 5 minutes to use commands. Type .commands to see available commands")
			spawn(function() processFreeTrial(speaker) end)
		else
			makeStandSpeak("You already have an active free trial")
		end
		return
	elseif cmd == ".commands" then
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

local function setupChatListeners()
	for _, player in ipairs(Players:GetPlayers()) do
		player.Chatted:Connect(function(message)
			respondToChat(player, message)
			processCommand(player, message)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			respondToChat(player, message)
			processCommand(player, message)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if hasAdminPermissions(player) then
			checkAdminLeft()
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
	end)
else
	warn("LocalPlayer not found!")
end
