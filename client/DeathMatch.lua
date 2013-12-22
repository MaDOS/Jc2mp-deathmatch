class 'DeathMatch'

function DeathMatch:__init()
    Network:Subscribe("SetState", self, self.SetState)
	Network:Subscribe("SetAllowedItems", self, self.SetAllowedItems)
	
    Network:Subscribe("OutOfArena", self, self.OutOfArena)
    Network:Subscribe("BackInArena", self, self.BackInArena)

    Network:Subscribe("PlayerCount", self, self.PlayerCount)

    Events:Subscribe("Render", self, self.Render)
    Events:Subscribe("ModuleLoad", self, self.ModulesLoad)
    Events:Subscribe("ModulesLoad", self, self.ModulesLoad)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)

    Events:Subscribe("LocalPlayerInput" , self , self.LocalPlayerInput)

    --states
    self.state = "Inactive"
    self.playerCount = nil
    self.countdownTimer = nil
    self.blockedKeys = { Action.ExitVehicle, Action.EnterVehicle, Action.UseItem }
	self.allowedKeysInit = { Action.LookDown, Action.LookLeft, Action.LookRight , Action.LookUp}
	self.parachuteActions = { Action.ParachuteOpenClose, Action.DeployParachuteWhileReelingAction, Action.ExitToStuntposParachute, Action.ParachuteLandOnVehicle}

	
	self.grapplingAllowed = true
	self.parachuteAllowed = true
	
	self.timer = nil
end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------NETWORK EVENTS-------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:SetState(newstate)
    self.state = newstate
    if (newstate == "Inactive") then
        self:BackInArena()
    end
    if (newstate == "Lobby") then
        self.state = "Lobby"
        self:BackInArena()
    elseif (newstate == "Setup") then
        self.state = "Setup"
    elseif (newstate == "Countdown") then
        self.state = "Countdown"
        self.countdownTimer = Timer()
    elseif (newstate == "Running") then
        self.state = "Running"
    end
end

function DeathMatch:SetAllowedItems(settings)
	self.grapplingAllowed = settings.grapplingAllowed
	self.parachuteAllowed = settings.parachuteAllowed
end

function DeathMatch:PlayerCount(amount)
    self.playerCount = amount
end
function DeathMatch:OutOfArena()
	self.timer = Timer()
end
function DeathMatch:BackInArena()
    self.timer = nil
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:ModulesLoad()
    Events:FireRegisteredEvent("HelpAddItem",
        {
            name = "DeathMatch",
            text = "Type /deathmatch in chat to enter a deathmatch. After setup you get 10 seconds to flee after which everyone will be given a random gun. Longer alive means more money."
        } )
end

function DeathMatch:ModuleUnload()
    Events:FireRegisteredEvent("HelpRemoveItem",
        {
            name = "DeathMatch"
        } )
end

function DeathMatch:LocalPlayerInput(args)
	if(self.state == "Running" or self.state == "Countdown") then
		if(args.input == Action.FireGrapple and self.grapplingAllowed == false) then
			return false
		end

		if(self.parachuteAllowed == false) then
			for i, action in ipairs(self.parachuteActions) do
				if args.input == action then
					return false
				end
			end
		end
		print(tostring(args.input))
	end
	
    if (self.state == "Running") then
		for i, action in ipairs(self.blockedKeys) do
			if args.input == action then
				return false
			end
		end
    elseif (self.state == "Setup") then
		local returnVal = false
		for i, action in ipairs(self.allowedKeysInit) do
			if args.input == action then
				returnVal = true
			end
		end
       return returnVal
    end
end
function DeathMatch:TextPos(text, size, offsetx, offsety)
    local text_width = Render:GetTextWidth(text, size)
    local text_height = Render:GetTextHeight(text, size)
    local pos = Vector2((Render.Width - text_width + offsetx)/2, (Render.Height - text_height + offsety)/2)

    return pos
end
function DeathMatch:Render()
    if (self.state == "Inactive") then return end
    if Game:GetState() ~= GUIState.Game then return end

    if (self.state ~= "Inactive") then
        local pos = Vector2(3, Render.Height - 32)
        Render:DrawText(pos, "DeathMatch v0.0.1 By M1nd0", Color(255, 255, 255), TextSize.Default) 
    end
    if (self.state == "Lobby") then
        local pos = Vector2(3, Render.Height -  49)
        Render:DrawText(pos, "Players Joined: " .. self.playerCount, Color(255, 255, 255), TextSize.Default) 
    end
    if (self.state == "Setup") then
        local pos = Vector2(3, Render.Height -  49)
        Render:DrawText(pos, "Players Left: " .. self.playerCount, Color(255, 255, 255), TextSize.Default)

        local text = "Initializing"
        local textinfo = self:TextPos(text, TextSize.VeryLarge, 0, -200)
        Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.VeryLarge)    

        local text = "Please Wait..."
        local textinfo = self:TextPos(text, TextSize.Default, 0, -155)
        Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.Default)        

    elseif (self.state == "Countdown") then
        local pos = Vector2(3, Render.Height -  49)
        Render:DrawText(pos, "Players Left: " .. self.playerCount, Color(255, 255, 255), TextSize.Default)

        local time = 10 - math.floor(math.clamp(self.countdownTimer:GetSeconds(), 0 , 10))
        local message = {"Go!", "One", "Two", "Three"}
		local text = ""
		if(time > 3) then
			text = tostring(time)
		else
			text = message[time + 1]
		end
        local textinfo = self:TextPos(text, TextSize.Huge, 0, -200)
        Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.Huge)  
    elseif (self.state == "Running") then
        local pos = Vector2(3, Render.Height -  49)
        Render:DrawText(pos, "Players Left: " .. self.playerCount, Color(255, 255, 255), TextSize.Default) 
		
		if(self.countdownTimer ~= nil) then
			if(self.countdownTimer:GetSeconds() < 11) then
				local text = "Go!"
				local textinfo = self:TextPos(text, TextSize.Huge, 0, -200)
				Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.Huge)
			else
				self.countdownTimer = nil
			end
		end
    end
	
	if(self.state == "Running" or self.state == "Countdown") then
	--OUT OF ARENA
        if (self.timer ~= nil) then
            Render:FillArea(Vector2(Render.Width - 110, 70), Vector2(Render.Width - 110, 110), Color(0, 0, 0, 165))
            local time = 20 - math.floor(math.clamp(self.timer:GetSeconds(), 0, 20 ))
            if time <= 0 then return end
            local text = tostring(time)
            local text_width = Render:GetTextWidth(text, TextSize.Huge)
            local text_height = Render:GetTextHeight(text, TextSize.Huge)
            local pos = Vector2(((110 - text_width)/2) + Render.Width - 110, (text_height))
            Render:DrawText( pos, text, Color( 255, 69, 0 ), TextSize.Huge)
            pos.y = pos.y + 70
            pos.x = Render.Width - 106
            Render:DrawText( pos, "Seconds to re-enter", Color( 255, 255, 255 ), 12)
            pos.y = pos.y + 15
            Render:DrawText( pos, "the arena", Color( 255, 255, 255 ), 12)
        end
	end
end
DeathMatch = DeathMatch()