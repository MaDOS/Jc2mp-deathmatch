function math.round(x)
	if x%2 ~= 0.5 then
		return math.floor(x+0.5)
	end
	return x-0.5
end
class "DeathMatch"
function DeathMatch:__init(manager, world, arenaName)
	self.deathMatchManager = manager
	self.world = world
	
	self.arenamanager = Arena(self.deathMatchManager)
	self.arena = self.arenamanager:LoadArena(arenaName)

	self:InitVars()
	
	Events:Subscribe("PostTick", self, self.PostTick)
	Events:Subscribe("JoinGamemode", self, self.JoinGamemode)
	Events:Subscribe("PlayerDeath", self, self.PlayerDeath)
	Events:Subscribe("PlayerQuit", self, self.PlayerLeave)
	Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
end

---------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------EVENTS----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:PostTick()
	if (self.state == "Lobby") then
		if ((self.numPlayers >= self.minPlayers and self.startTimer:GetSeconds() > 30) or (self.numPlayers >= self.minPlayers and self.globalStartTimer:GetSeconds() > 300)) then
			self:Start()
		end
	elseif (self.state == "Setup") then
		if (self.setupTimer:GetSeconds() > 10) then
			self.countdownTimer = Timer()
			--set state
			self.state = "Countdown"
			self:SetClientState()
			self.setupTimer = nil
		end
	elseif (self.state == "Countdown") then
		if (self.countdownTimer:GetSeconds() > 10) then
			--set state
			self.state = "Running"
			self:SetClientState()
			self.countdownTimer = nil
			self.deathMatchTimer = Timer()
		end
		self:CheckBoundaries()
	elseif (self.state == "Running") then
		--Check if players need to be prepped
		if(self.playerPrepped == false) then
			self:PreparePlayers()
			self.playerPrepped = true
		end
		
		--player gets killed when out of boundries
		self:CheckBoundaries()
			
		--Actively check for players & handle DeathMatch ending (if debug 60 secs later cause of test)
		if (self.debugMode == false or self.deathMatchTimer:GetSeconds() > 60) then
			self:CheckPlayers()
		end
	end
end

function DeathMatch:PlayerDeath(args)
	if self:HasPlayer(args.player) then
		if (self.state ~= "Lobby" and args.player:GetWorld() == self.world) then
			local numberEnding = ""
			local lastDigit = self.numPlayers % 10
			if ((self.numPlayers < 10) or (self.numPlayers > 20 and self.numPlayers < 110) or (self.numPlayers > 120)) then
				if (lastDigit  == 1) then
					numberEnding = "st"
				elseif (lastDigit == 2) then
					numberEnding = "nd"
				elseif (lastDigit == 3) then
					numberEnding = "rd"
				else
					numberEnding = "th"
				end
			else
				numberEnding = "th"
			end
			self.deathMatchManager:MessagePlayer(args.player, "Congratulations you came " ..tostring(self.numPlayers) .. numberEnding)
			self:RemovePlayer(args.player)

			local currentMoney = args.player:GetMoney()
			local addMoney = math.ceil(100 * math.exp(self.scaleFactor * (self.startPlayers - self.numPlayers))) / 2
			args.player:SetMoney(currentMoney + addMoney)
		end
	end
end

function DeathMatch:PlayerLeave(args)
	if (self:HasPlayer(args.player)) then
		self:RemovePlayer(args.player)
	end
end

function DeathMatch:SetClientState(newstate)
	for index,player in pairs(self.players) do
		if newstate == nil then
			Network:Send(player, "SetState", self.state)
		else
			Network:Send(player, "SetState", newstate)
		end
	end
end

function DeathMatch:SendSettingsToClient()
	local settings = {}
	settings.grapplingAllowed = self.grapplingAllowed
	settings.parachuteAllowed = self.parachuteAllowed

	for index,player in pairs(self.players) do
		Network:Send(player, "SetAllowedItems", settings)
	end
end

function DeathMatch:UpdatePlayerCount()  
	for id ,player in pairs(self.players) do
		Network:Send(player, "PlayerCount", self.numPlayers)
	end
end

function DeathMatch:ModuleUnload()
	for k,p in pairs(self.eventPlayers) do
		if (self.state ~= "Lobby") then
			p:Leave()
			self.deathMatchManager:MessagePlayer(p.player, "DeathMatch script unloaded. You have been restored to your starting position.")
			self:SetClientState("Inactive")
		end
	end
end
function DeathMatch:JoinGamemode( args )
	if args.name ~= "DeathMatch" then
		self:RemovePlayer(args.player)
	end
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:PreparePlayers()
	for k,p in pairs(self.eventPlayers) do
		p.player:SetHealth(1)
		p.player:GiveWeapon(self.weapon.slot, Weapon( self.weapon.id, self.weapon.ammo1, self.weapon.ammo2))
	end
end
function DeathMatch:CheckBoundaries()
	for k,p in pairs(self.players) do
		local boundary = self.arena.Boundary.position
		local radius = self.arena.Boundary.radius
		local distance = (p:GetPosition():Distance2D(boundary)) 
		
		--CHECK IS PLAYER IS OUTSIDE THE EVENT BOUNDARIES
		if(p:GetWorld() == self.world) then
			if (distance > radius or p:GetPosition().y > self.arena.MaximumY or p:GetPosition().y < self.arena.MinimumY) then
				if (p.timer ~= nil) then
					if p.timer:GetSeconds() > 20 then
						--Kill the player
						p:SetHealth(0)
						p.timer = nil
					end
				else
					p.timer = Timer()
					p.outOfArena = true
					Network:Send(p, "OutOfArena")
				end
			elseif (p.outOfArena) then
				p.outOfArena = false
				p.timer = nil
				Network:Send(p, "BackInArena")
			end
		end
	end
end
function DeathMatch:CheckPlayers()
	if (self.numPlayers == 1 and self.state ~= "Lobby") then
	--kick everyone out and broadcast the winner
		for k,p in pairs(self.players) do
			self.deathMatchManager:MessageGlobal(p:GetName() .. " has won the Deathmatch event " .. self.arena.Location .. "!")

			local currentMoney = p:GetMoney()
			local addMoney = math.ceil(100 * math.exp(self.scaleFactor * (self.startPlayers - self.numPlayers))) / 2
			p:SetMoney(currentMoney + addMoney)
			self:RemovePlayer(p, "Congratulations you came 1st!")
		end
		self:Cleanup()
	elseif (self.numPlayers == 0) then
		self:Cleanup()
	end
end
---------------------------------------------------------------------------------------------------------------------
--------------------------------------------------EVENT START--------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:Start()
	self.state = "Setup"
	self.startPlayers = self.numPlayers
	self.setupTimer = Timer()
	self:SendSettingsToClient()
	self:SetClientState()
	
	local tempPlayers = {}
	for id , player in pairs(self.players) do
		table.insert(tempPlayers , player)
	end
	local divider = math.floor(self.maxPlayers / self.numPlayers)
	local idInc = 1

	for index, player in ipairs(tempPlayers)do 
		if (player:GetHealth() == 0) then
			self:RemovePlayer(player, "You have been removed from the DeathMatch event.")
		else
			self:SpawnPlayer(player, tonumber(math.round(idInc)))
		end
		idInc = idInc + divider
	end

	self.highestMoney = self.startPlayers * 400
	self.scaleFactor = math.log(self.highestMoney/100)/self.startPlayers
end

function DeathMatch:SpawnPlayer(player, index)
	if (IsValid(self.arena.SpawnPoint[index]) ~= nil) then
		--TELEPORT THE PLAYER
		player:SetWorld(self.world)
		player:SetPosition(self.arena.SpawnPoint[index].position + Vector3(0,1,0))
		player:SetAngle(self.arena.SpawnPoint[index].angle)
		player:ClearInventory()

		local p = self.eventPlayers[player:GetId()]
		p.deathMatchPosition = self.arena.SpawnPoint[index].position
		p.deathMatchAngle = self.arena.SpawnPoint[index].angle
		
	else
		self:RemovePlayer(player, "An error occured, you were removed from the DeathMatch.")
	end

end
---------------------------------------------------------------------------------------------------------------------
-------------------------------------------PLAYER JOINING/LEAVING----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:HasPlayer(player)
	return self.players[player:GetId()] ~= nil
end

function DeathMatch:JoinPlayer(player)
	if (player:GetWorld() ~= DefaultWorld) then
		self.deathMatchManager:MessagePlayer(player, "You must exit other gamemodes before you can join.")
	else
		if (self.state == "Lobby") then
			local p = Player(player)
			self.eventPlayers[player:GetId()] = p
			self.players[player:GetId()] = player

			self.deathMatchManager.playerIds[player:GetId()] = true
			self.numPlayers = self.numPlayers + 1
			--self:MessagePlayer(player, "You have been entered into the next DeathMatch event! It will begin shortly.") 

			Network:Send(player, "SetState", "Lobby")
			self:UpdatePlayerCount()
			self.startTimer:Restart()

			if (self.numPlayers == self.maxPlayers) then
				self:Start()
			end
		end
	end
end

function DeathMatch:RemovePlayer(player, message)
	if message ~= nil then
		self.deathMatchManager:MessagePlayer(player, message)    
	end
	
	local p = self.eventPlayers[player:GetId()]
	if p == nil then 
		return nil
	else
		self.players[player:GetId()] = nil
		self.eventPlayers[player:GetId()] = nil
		self.deathMatchManager.playerIds[player:GetId()] = nil
		self.numPlayers = self.numPlayers - 1
		if (self.state ~= "Lobby") then
			p:Leave()
		end
		Network:Send(player, "SetState", "Inactive")
		self:UpdatePlayerCount()
	end
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------CLEANUP-----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:Cleanup()
	self.state = "Cleanup"
	for index, player in pairs(self.players) do
		self:RemovePlayer(player)
	end
	self.state = "Lobby"
end

function DeathMatch:InitVars()
	self.weapon = table.randomvalue(self.arena.Weapons)
	self.debugMode = false
	self.playerPrepped = false
	self.state = "Lobby"
	self.startTimer = Timer()
	self.players = {}
	self.eventPlayers = {}
	self.grapplingAllowed = self.arena.grapplingAllowed
	self.parachuteAllowed = self.arena.parachuteAllowed
	self.minPlayers = self.arena.minPlayers
	self.maxPlayers = self.arena.maxPlayers
	self.startPlayers = 0
	self.numPlayers = 0
	self.highestMoney = 0
	self.scaleFactor = 0

	self.globalStartTimer = Timer()
	self.setupTimer = nil
	self.countdownTimer = nil
	self.deathMatchTimer = nil
end