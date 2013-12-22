class "Arena"
function Arena:__init(manager)
	self.deathMatchManager = manager
	self.arenaRootpath = "/server/Arenas/"
	self.manifestPath = self.arenaRootpath .. "Manifest.txt"
	--TODO: Fix this ugly stuff
	--Arena names
	self.arenaNames = {}
	self.numArenas = 0
	
	--ClassNames
	self.arenas = {}
	

	
	self.ammo_counts            = {
	[2] = { 12, 60 }, [4] = { 7, 35 }, [5] = { 30, 90 },
	[6] = { 3, 18 }, [11] = { 20, 100 }, [13] = { 6, 36 },
	[14] = { 4, 32 }, [16] = { 3, 12 }, [17] = { 5, 5 },
	[28] = { 26, 130 } 
	}
	
	self.settings = {}
	
	self:LoadManifest(self.manifestPath)
	self:DetermineClass()
end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------MANIFEST LOADING-----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Arena:LoadManifest(path)
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
	-- Loop through each line in the manifest.
	for line in io.lines(path) do
		-- Make sure this line has stuff in it.
		if string.find(line , "%S") then
				-- Add the entire line, sans comments, to self.arenaNames
				table.insert(self.arenaNames , line)
				self.numArenas = self.numArenas + 1
		end
	end
end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------DETERMINE CLASSES----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Arena:DetermineClass()
	for index, arena in pairs(self.arenaNames) do
		local path = self.arenaRootpath .. arena .. ".arena"
		--check if path is invalid
		if path == nil then
			print("*ERROR* - Arena path is nil!")
			return nil
		end	
		local file = io.open(path , "r") 
		--check if file exists
		if not file then
			print("*ERROR* - Cannot open arena file: "..path)
			return nil
		end
		
		table.insert(self.arenas, arena)
	end
end
---------------------------------------------------------------------------------------------------------------------
-----------------------------------------------ARENA FILE PARSING---------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Arena:LoadArena(name)
	if name == nil then
		name = self:PickArena()
	end
	local path = self.arenaRootpath .. name .. ".arena"
	--check if path is invalid
	if path == nil then
		print("*ERROR* - Arena path is nil!")
		return nil
	end	
	local file = io.open(path , "r") 
	--check if file exists
	if not file then
		print("*ERROR* - Cannot open Arena file: "..path)
		return nil
	end

	local arena = {}
	arena.Location = nil
	arena.minPlayers = nil
	arena.maxPlayers = nil
	arena.SpawnPoint = {}
	arena.Boundary = {}
	arena.MinimumY = nil
	arena.MaximumY = nil
	arena.Weapons = {}
	arena.grapplingAllowed = true
	arena.parachuteAllowed = true
	
	--loop through file line by line
	for line in file:lines() do
		if line:sub(1,1) == "L" then
			arena.Location =  self:Location(line)
		elseif line:sub(1,2) == "Pl" then
			local playerCount = self:Players(line)
			arena.minPlayers = playerCount.minPlayers
			arena.maxPlayers = playerCount.maxPlayers
		elseif line:sub(1,1) == "B" then
			local boundary = self:Boundary(line)
			arena.Boundary.position = boundary.position
			arena.Boundary.radius = boundary.radius
		elseif line:sub(1,1) == "M" and line:sub(2,2) == "i"then
			arena.MinimumY = self:MinimumY(line)
		elseif line:sub(1,1) == "M" and line:sub(2,2) == "a"then
			arena.MaximumY = self:MaximumY(line)
		elseif line:sub(1,1) == "S" then
			table.insert(arena.SpawnPoint, self:Spawn(line))
		elseif line:sub(1,1) == "W" then
			table.insert(arena.Weapons, self:Weapon(line))
		elseif line:sub(1,1) == "G" then
			arena.grapplingAllowed = self:GetGrapplingAllowed(line)
		elseif line:sub(1,2) == "Pa" then
			arena.parachuteAllowed = self:GetParachuteAllowed(line)
		end
	end
	return arena
end
function Arena:Location(line)
	line = line:gsub("Location%(", "")
	line = line:gsub("%)", "")

	return line
end
function Arena:GetGrapplingAllowed(line)
	line = line:gsub("GrapplingHookAllowed%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")
	
	if(line == "true") then
		return true
	else
		return false
	end
end
function Arena:GetParachuteAllowed(line)
	line = line:gsub("ParachuteAllowed%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")
	
	if(line == "true") then
		return true
	else
		return false
	end
end
function Arena:Weapon(line)
	line = line:gsub("Weapon%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")
	local tokens = line:split(",") 
	
	weapon = {}
	
	if(tokens[1] == "Handgun") then
		weapon.id = Weapon.Handgun
		weapon.slot = WeaponSlot.Right
	elseif(tokens[1] == "Revolver") then
		weapon.id = Weapon.Revolver
		weapon.slot = WeaponSlot.Right
	elseif(tokens[1] == "SMG") then
		weapon.id = Weapon.SMG
		weapon.slot = WeaponSlot.Right	
	elseif(tokens[1] == "SawnOffShotgun") then
		weapon.id = Weapon.SawnOffShotgun
		weapon.slot = WeaponSlot.Right
	elseif(tokens[1] == "Assault") then
		weapon.id = Weapon.Assault
		weapon.slot = WeaponSlot.Primary	
	elseif(tokens[1] == "Shotgun") then
		weapon.id = Weapon.Shotgun
		weapon.slot = WeaponSlot.Primary		
	elseif(tokens[1] == "Sniper") then
		weapon.id = Weapon.Sniper
		weapon.slot = WeaponSlot.Primary	
	elseif(tokens[1] == "MachineGun") then
		weapon.id = Weapon.MachineGun
		weapon.slot = WeaponSlot.Primary
	end
	
	--If weapon unknown parse rest of line for id and ammo counts
	if(weapon.id == nil) then
		weapon.id = tokens[1]
	end
	
	--load custom ammo counts or pre defined
	if(tokens[2] ~= nil) then
		weapon.ammo1 = tokens[2]
		weapon.ammo2 = tokens[3]
	else
		weapon.ammo1 = self.ammo_counts[weapon.id][1]
		weapon.ammo2 = self.ammo_counts[weapon.id][2] * 6
	end
	
	return weapon
end
function Arena:Players(line)
	line = line:gsub("Players%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}

	args.minPlayers = tonumber(tokens[1])
	args.maxPlayers = tonumber(tokens[2])

	return args
end
function Arena:Boundary(line)
	line = line:gsub("Boundary%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}
	-- Create tables containing appropriate strings
	args.position	= Vector3(tonumber(tokens[1]), tonumber(tokens[2]), tonumber(tokens[3]))
	args.radius		= tonumber(tokens[4])

	return args
end
function Arena:MinimumY(line)
	line = line:gsub("MinimumY%(", "")
	line = line:gsub("%)", "")

	return tonumber(line)
end
function Arena:MaximumY(line)
	line = line:gsub("MaximumY%(", "")
	line = line:gsub("%)", "")

	return tonumber(line)
end
function Arena:Spawn(line)
	line = line:gsub("Spawn%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}
	-- Create tables containing appropriate strings
	args.position	= Vector3(tonumber(tokens[1]), tonumber(tokens[2]), tonumber(tokens[3]))
	args.angle		= Angle(tonumber(tokens[4]), tonumber(tokens[5]), tonumber(tokens[6]))

	return args
end
function Arena:PickArena()
	return table.randomvalue(self.arenas)
end