class "DeathMatchManager"
function DeathMatchManager:__init()
	self.players = {}
	self.playerIds = {}
	self.admins = {}
	self:LoadAdmins()
	
	self.arenamanager = Arena(self)
	self.deathmatches = {}
	
	self.clientsListening = {}
	--create arena for each dm
	for index, arenaName in pairs(self.arenamanager.arenas) do
		self.deathmatches[arenaName] = DeathMatch(self, World.Create(), arenaName)
	end
	
	self.timerInfo = Timer()
	self.timerInstance = Timer()
   
	Events:Subscribe("PlayerJoin", self, self.PlayerJoin)
	Events:Subscribe("PlayerChat", self, self.ChatMessage)
	Events:Subscribe("PostTick", self, self.PostTick)
	Network:Subscribe("DeathMatchOpenArenaWindow", self, self.OpenArenaWindow)
	Network:Subscribe("DeathMatchJoinArena", self, self.JoinArena)
	Network:Subscribe("DeathMatchJoinAll", self, self.JoinAll)
	Network:Subscribe("DeathMatchStart", self, self.Start)
	
	--If module is reloaded make sure admins are set to admin again
	self.adminCheckTimer = Timer()
end

function DeathMatchManager:LoadAdmins()
	local path = "/admins.txt"
	local tempFile , tempFileError = io.open(path , "r")
	if tempFileError then
			print()
			print("*ERROR*")
			print(tempFileError)
			print()
			fatalError = true
			return
	else
			io.close(tempFile)
	end
	
	for line in io.lines(path) do
		
		if line:sub(1,1) == "A" then
			line = line:gsub("Admin%(", "")
			line = line:gsub("%)", "")
			line = line:gsub(" ", "")
			local tokens = line:split(",") 
			
			self.admins[tokens[2]] = tokens[1]
		end
	end
end


function DeathMatchManager:Start(args, player)
	if (self:IsAdmin(player)) then
		self.deathmatches[args.arenaName].debugMode = args.debugMode
		self.deathmatches[args.arenaName]:Start()
		local deathmatchInfo = self:GenereateDMInfo()
		self:SendDeathmatchInfoToClient(player, deathmatchInfo)
	end
end

function DeathMatchManager:IsAdmin(player)
	return self.admins[tostring(player:GetSteamId())] ~= nil
end

function DeathMatchManager:JoinAll(args, player)
	if (self:IsAdmin(player)) then
		local isInAny = false
		for p in Server:GetPlayers() do 
			for arenaName, deathmatch in pairs(self.deathmatches) do
				if(deathmatch:HasPlayer(p) == true) then
					isInAny = true
				end
			end
			if(isInAny == false) then
				self.deathmatches[args.arenaName]:JoinPlayer(p)
			end
		end
	end
	local deathmatchInfo = self:GenereateDMInfo()
	self:SendDeathmatchInfoToClient(player, deathmatchInfo)
end

function DeathMatchManager:PlayerJoin(args)
	local player = args.player
	
	if (self:IsAdmin(player)) then
		Network:Send(player, "SetIsAdmin", true)
	end
end

function DeathMatchManager:JoinArena(args, player)
	--Remove from other dm if needed
	local joinAgain = true
	for arenaName, deathmatch in pairs(self.deathmatches) do
		if(deathmatch:HasPlayer(player) == true) then
			deathmatch:RemovePlayer(player)
			if(args.arenaName == arenaName) then
				joinAgain = false
			end
		end
	end
	
	local arenaName = nil
	if(joinAgain) then
		self.deathmatches[args.arenaName]:JoinPlayer(player)
		arenaName = args.arenaName
	end
	
	--update arenaName on client
	Network:Send(player, "ArenaName", arenaName)
	local deathmatchInfo = self:GenereateDMInfo()
	self:SendDeathmatchInfoToClient(player, deathmatchInfo)
end

--Clients opens window, from now on start sending update messages
function DeathMatchManager:OpenArenaWindow(open, player)
	if(open) then
		self.clientsListening[player:GetId()] = player
		local deathmatchInfo = self:GenereateDMInfo()
		self:SendDeathmatchInfoToClient(player, deathmatchInfo)
	else
		self.clientsListening[player:GetId()] = nil
	end
end

function DeathMatchManager:PostTick()
	if(self.timerInfo:GetSeconds() >= 5) then
		local deathmatchInfo = self:GenereateDMInfo()
		
		for index, player in pairs(self.clientsListening) do
			self:SendDeathmatchInfoToClient(player, deathmatchInfo)
		end
		self.timerInfo:Restart()
	end
	
	--Resend p admins stats if script is reloaded
	if(self.adminCheckTimer ~= nil) then
		if( self.adminCheckTimer:GetSeconds() >= 5) then
			for p in Server:GetPlayers() do 
				self:PlayerJoin({player = p}) 
			end
			self.adminCheckTimer = nil
		end
	end
	
	if(self.timerInstance:GetSeconds() > 2) then
		for arenaName, deathmatch in pairs(self.deathmatches) do
			if(deathmatch.state == "Lobby") then
				for index, player in pairs(deathmatch.players) do
					if(player:GetWorld() ~= DefaultWorld) then
						deathmatch:RemovePlayer(player, "You are no longer in the default instance and are removed from the deathmatch queue.")
					end
				end
			end
		end
		self.timerInstance:Restart()
	end
end

function DeathMatchManager:SendDeathmatchInfoToClient(player, deathmatchInfo)
	Network:Send(player, "DeathmatchInfo", deathmatchInfo)
end

function DeathMatchManager:GenereateDMInfo()
	local deathmatchInfo = {}
	for index, deathmatch in pairs(self.deathmatches) do
		local info = {}
		info.location = deathmatch.arena.Location
		info.name = deathmatch.arena.name
		info.state = deathmatch.state
		info.curPlayers = deathmatch.numPlayers
		info.minPlayers = deathmatch.arena.minPlayers
		info.maxPlayers = deathmatch.arena.maxPlayers
		info.grapplingAllowed = deathmatch.arena.grapplingAllowed
		info.parachuteAllowed = deathmatch.arena.parachuteAllowed
		table.insert(deathmatchInfo, info)
	end
	return deathmatchInfo
end

-------------
--CHAT STUF--
-------------
function DeathMatchManager:MessagePlayer(player, message)
	player:SendChatMessage( "[DeathMatch] " .. message, Color(30, 200, 220) )
end

function DeathMatchManager:MessageGlobal(message)
	Chat:Broadcast( "[DeathMatch] " .. message, Color(0, 255, 255) )
end

function DeathMatchManager:ChatMessage(args)
	local msg = args.text
	local player = args.player
	
	-- If the string is't a command, we're not interested!
	if ( msg:sub(1, 1) ~= "/" ) then
		return true
	end    
	
	local cmdargs = {}
	for word in string.gmatch(msg, "[^%s]+") do
		table.insert(cmdargs, word)
	end
	
	if (self:IsAdmin(player)) then
		--admins can output points to file for easy creation of arenas spawns 
		if (cmdargs[1] == "/p") then
			local text = "Spawn(" .. tostring(player:GetPosition()) .. "," .. tostring(player:GetAngle()) .. ")\n"
			local file = io.open("server/Arenas/SpawnPointsOutput.txt" , "a+")
			file:write(text)
			file:close()
		end
		
		--if (cmdargs[1] == "/port") then
		--	player:SetPosition(Vector3(14014.245117, 458.688324, 14270.292969))
		--end
	end
	return false
end