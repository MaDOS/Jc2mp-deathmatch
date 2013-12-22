class "DeathMatchManager"
function DeathMatchManager:__init()
	self.count = 0
	self.players = {}
	self.playerIds = {}
	self.events = {}
	self.adminId = "STEAM_0:1:26896132"
	
	self:CreateDeathMatchEvent(nil)
	Events:Subscribe("PlayerChat", self, self.ChatMessage)
end

function DeathMatchManager:CreateDeathMatchEvent(arenaName)
	self.currentDeathMatch = self:DeathMatchEvent(self:GenerateName(), arenaName)
end

function DeathMatchManager:DeathMatchEvent(name, arenaName)
	local deathMatch = DeathMatch(name, self, World.Create(), arenaName)
	table.insert(self.events, deathMatch)

	self.count = self.count + 1
	return deathMatch
end
function DeathMatchManager:RemoveDeathMatch(deathMatch)
	for index, event in ipairs(self.events) do
		if event.name == deathMatch.name then
				table.remove(self.events, index)
				break
		end
	end	
end
function DeathMatchManager:GenerateName()
	return "DeathMatch-"..tostring(self.count)
end

-------------
--CHAT SHIT--
-------------
function DeathMatchManager:MessagePlayer(player, message)
	player:SendChatMessage( "[DeathMatch-" .. tostring(self.count) .."] " .. message, Color(30, 200, 220) )
end

function DeathMatchManager:MessageGlobal(message)
	Chat:Broadcast( "[DeathMatch-" .. tostring(self.count) .."] " .. message, Color(0, 255, 255) )
end

function DeathMatchManager:HasPlayer(player)
	return self.playerIds[player:GetId()]
end
function DeathMatchManager:RemovePlayer(player)
	for index, event in ipairs(self.events) do
		if (event.players[player:GetId()]) then
			event:RemovePlayer(player, "You have been removed from the Deathmatch event.")
		end
	end
end

function DeathMatchManager:CreateEvenFromArgs(cmdargs)
	--Ugly workaround for dm with space
	local arenaName = cmdargs[2]
	if(cmdargs[3] ~= nil) then
		arenaName = arenaName .. " " .. cmdargs[3]
	end
	self:CreateDeathMatchEvent(arenaName)
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
	
	if (cmdargs[1] == "/deathmatch") then 
		if (self.currentDeathMatch:HasPlayer(player)) then
			self.currentDeathMatch:RemovePlayer(player, "You have been removed from the Deathmatch event.")
		else
			--Admin command to start a match with prefered map
			if (player:GetSteamId() == SteamId(self.adminId)) then
				if(cmdargs[2] ~= nil) then
					self:CreateEvenFromArgs(cmdargs)
				end
			end
			if (self:HasPlayer(player)) then
				self:RemovePlayer(player)
			else
				self.currentDeathMatch:JoinPlayer(player)
			end
		end
	end
	
	if (player:GetSteamId() == SteamId(self.adminId)) then
		--Debug command to start a match with 1p & dont check finish criteria for first 60 sec of match
		if (cmdargs[1] == "/dmdebugstart") then
			if(cmdargs[2] ~= nil) then
				self:CreateEvenFromArgs(cmdargs)
				self.currentDeathMatch:JoinPlayer(player)
			end
			self.currentDeathMatch.debug = true
			self.currentDeathMatch:Start()
		end
		--Joins all players into current dm game
		if (cmdargs[1] == "/dmjoinall") then
			for player in Server:GetPlayers() do
				if not self.currentDeathMatch:HasPlayer(player) then
					self.currentDeathMatch:JoinPlayer(player)
				end
			end
			self.currentDeathMatch:Start()
		end
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