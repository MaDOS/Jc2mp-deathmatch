class 'DeathMatch'
function DeathMatch:__init()
    --states
    self.state = "Inactive"
    self.countdownTimer = nil
    self.blockedKeys = { Action.ExitVehicle, Action.EnterVehicle, Action.UseItem }
	self.allowedKeysInit = { Action.LookDown, Action.LookLeft, Action.LookRight , Action.LookUp}
	self.parachuteActions = { Action.ParachuteOpenClose, Action.DeployParachuteWhileReelingAction, Action.ExitToStuntposParachute, Action.ParachuteLandOnVehicle}

	
	self.grapplingAllowed = true
	self.parachuteAllowed = true
	
	self.isAdmin = false
	self.timer = nil
	self.interfaceActive = false
	self.arenaName = nil
	self.rows = {}
	self.rowJoinButtons = {}
	self.rowStartButtons = {}
	self.rowDebugStartButtons = {}
	self:CreateGui()
	
	self.playerCount = 0
	
	Network:Subscribe("SetState", self, self.SetState)
	Network:Subscribe("SetAllowedItems", self, self.SetAllowedItems)
    Network:Subscribe("OutOfArena", self, self.OutOfArena)
    Network:Subscribe("BackInArena", self, self.BackInArena)
	Network:Subscribe("DeathmatchInfo", self, self.DeathmatchInfo)
	Network:Subscribe("ArenaName", self, self.ArenaName)
	Network:Subscribe("SetIsAdmin", self, self.SetIsAdmin)
	Network:Subscribe("PlayerCount", self, self.PlayerCount)
	
    Events:Subscribe("Render", self, self.Render)
    Events:Subscribe("ModuleLoad", self, self.ModulesLoad)
    Events:Subscribe("ModulesLoad", self, self.ModulesLoad)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
	Events:Subscribe("KeyUp", self, self.KeyUp )
    Events:Subscribe("LocalPlayerInput" , self , self.LocalPlayerInput)
	Events:Subscribe("LocalPlayerChat", self, self.ChatMessage)
end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------NETWORK EVENTS-------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:SetIsAdmin(isAdmin)
	self.isAdmin = isAdmin
	if(isAdmin == true) then
		--Start
		self.listbox:AddColumn("")
		--Debugstart
		self.listbox:AddColumn("")
	end
end

function DeathMatch:PlayerCount(amount)
    self.playerCount = amount
end

function DeathMatch:ArenaName(arenaName)
	self.arenaName = arenaName
end

function DeathMatch:DeathmatchInfo(deathmatchInfo)
	if(self.interfaceActive == false) then return end
	
	for index, dmInfo in pairs(deathmatchInfo) do
		local row = self.rows[dmInfo.name]
		
		if(row == nil) then
			row = self.listbox:AddItem( dmInfo.location )
			row:SetDataString( "id", dmInfo.name )
			self.rows[dmInfo.name] = row
		end
		
		local humanMessage = nil
		if(dmInfo.state == "Lobby") then
			humanMessage = "Waiting for players"
		elseif(dmInfo.state == "Setup" or dmInfo.state == "Countdown") then
			humanMessage = "Preparing to start"
		elseif(dmInfo.state == "Running") then
			humanMessage = "In progress"
		elseif(dmInfo.state == "Cleanup") then
			humanMessage = "Ending"	
		else
			humanMessage = "Unknown"
		end
		
		row:SetCellText( 1, humanMessage )
		row:SetCellText( 2, dmInfo.curPlayers .. "/" .. dmInfo.maxPlayers )
		
		local text = "Join"
		if(self.arenaName ~= nil) then
			if(self.arenaName == dmInfo.name) then
				text = "Leave"	
			end
		end
		
		--Join button
		local joinArenaButton = self.rowJoinButtons[dmInfo.name]
		local joinArenaButtonBase = nil
		if(joinArenaButton == nil) then
			joinArenaButtonBase, joinArenaButton = self:CreateListButton(text, true)
			joinArenaButton:Subscribe("Press", function() self:Join(dmInfo.name) end)
			row:SetCellContents(3, joinArenaButtonBase)
			self.rowJoinButtons[dmInfo.name] = joinArenaButton
		end
		joinArenaButton:SetText(text)
		joinArenaButton:SetEnabled(dmInfo.state == "Lobby")
		
		--Admin buttons
		if(self.isAdmin == true) then
	   
			local startButton = self.rowStartButtons[dmInfo.name]
			local startButtonButtonBase = nil
			if(startButton == nil) then
				startButtonButtonBase, startButton = self:CreateListButton("Start", true)
				startButton:Subscribe("Press", function() self:Start(dmInfo.name) end)
				row:SetCellContents(4, startButtonButtonBase)
				self.rowStartButtons[dmInfo.name] = startButton
			end
			startButton:SetEnabled(dmInfo.state == "Lobby")
		
		
			local debugstartButton = self.rowDebugStartButtons[dmInfo.name]
			local debugstartButtonBase = nil
			if(debugstartButton == nil) then
				debugstartButtonBase, debugstartButton = self:CreateListButton("Debugstart", true)
				debugstartButton:Subscribe("Press", function() self:Start(dmInfo.name, true) end)
				row:SetCellContents(5, debugstartButtonBase)
				self.rowDebugStartButtons[dmInfo.name] = debugstartButton
			end
			debugstartButton:SetEnabled(dmInfo.state == "Lobby")
		end
	end
end

function DeathMatch:Start(arenaName, debugMode)
	if(debugMode == nil) then
		debugMode = false
	end
	
	 Network:Send( "DeathMatchStart", { arenaName = arenaName, debugMode = debugMode } )
end


function DeathMatch:Join( arenaName )
    Network:Send( "DeathMatchJoinArena", { arenaName = arenaName } )
end

-----
function DeathMatch:ChatMessage(args)
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
	
	if (cmdargs[1] == "/dm" or cmdargs[1] == "/deathmatch") then
		self:SetActive( not self.interfaceActive )
	end
end

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
		self:SetActive(false)
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

function DeathMatch:OutOfArena()
	self.timer = Timer()
end
function DeathMatch:BackInArena()
    self.timer = nil
end

function DeathMatch:ModulesLoad()
    Events:FireRegisteredEvent("HelpAddItem",
        {
            name = "DeathMatch",
            text = "Pres 'K' to open the Deathmatch window and join a deathmatch. The longer you survive the more money you get."
        } )
end

function DeathMatch:ModuleUnload()
    Events:FireRegisteredEvent("HelpRemoveItem",
        {
            name = "DeathMatch"
        } )
end

function DeathMatch:LocalPlayerInput(args)
	if self.interfaceActive and Game:GetState() == GUIState.Game then
        return false
    end

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

function DeathMatch:KeyUp(args)
    if args.key == string.byte('K') then
        self:SetActive( not self.interfaceActive )
    end
end

---------------------------------------------------------------------------------------------------------------------
--------------------------------------------------GUI STUF-----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function DeathMatch:CreateListButton(text, enabled)
	local buttonBase = BaseWindow.Create(self.window)
	buttonBase:SetDock(GwenPosition.Fill)
	buttonBase:SetSize(Vector2(1, 23))
        
    local buttonBackground = Rectangle.Create(buttonBase)
    buttonBackground:SetSizeRel(Vector2(0.5, 1.0))
    buttonBackground:SetDock(GwenPosition.Fill)
    buttonBackground:SetColor(Color(0, 0, 0, 100))
        
	local button = Button.Create(buttonBase)
	button:SetText(text)
	button:SetDock(GwenPosition.Fill)
	button:SetEnabled(enabled)
	
	return buttonBase, button
end

function DeathMatch:CreateGui()
	self.window = Window.Create()
    self.window:SetSizeRel( Vector2( 0.6, 0.5 ) )
    self.window:SetPositionRel( Vector2( 0.5, 0.5 ) - self.window:GetSizeRel() / 2 )
    self.window:SetVisible( self.interfaceActive )
    self.window:SetTitle( "Deathmatch menu" )
    self.window:Subscribe( "WindowClosed", self, self.Close )
	
	local base1 = BaseWindow.Create( self.window )
    base1:SetDock( GwenPosition.Bottom )
    base1:SetSize( Vector2( self.window:GetSize().x, 32 ) )
	
	local background = Rectangle.Create( base1 )
    background:SetSizeRel( Vector2( 0.5, 1.0 ) )
    background:SetDock( GwenPosition.Fill )
    background:SetColor( Color( 0, 0, 0, 100 ) )

	self.sort_dir = false
    self.last_column = -1

    self.listbox = SortedList.Create( self.window  )
    self.listbox:SetDock( GwenPosition.Fill )
    self.listbox:AddColumn( "Name" )
    self.listbox:AddColumn( "State")
	self.listbox:AddColumn( "Players")
	self.listbox:AddColumn( "")
    self.listbox:SetSort( self, self.SortFunction )

    self.listbox:Subscribe( "SortPress",
        function(button)
            self.sort_dir = not self.sort_dir
        end)
end

function DeathMatch:SortFunction( column, a, b )
    if column ~= -1 then
        self.last_column = column
    elseif column == -1 and self.last_column ~= -1 then
        column = self.last_column
    else
        column = 0
    end

    local a_value = a:GetCellText(column)
    local b_value = b:GetCellText(column)

    if column == 1 then
        local a_num = tonumber(a_value)
        local b_num = tonumber(b_value)

        if a_num ~= nil and b_num ~= nil then
            a_value = a_num
            b_value = b_num
        end
    end

    if self.sort_dir then
        return a_value > b_value
    else
        return a_value < b_value
    end
end

function DeathMatch:Close( args )
    self:SetActive( false )
end

function DeathMatch:SetActive( active )
    if self.interfaceActive ~= active then
        if active == true and LocalPlayer:GetWorld() ~= DefaultWorld and self.isAdmin == false then
            Chat:Print( "You are not in the main world!", Color( 255, 0, 0 ) )
            return
        end

        self.interfaceActive = active
		Network:Send( "DeathMatchOpenArenaWindow",  self.interfaceActive)
		
		if(Mouse ~= nil) then
			Mouse:SetVisible( active )
		end
    end
end

function DeathMatch:TextPos(text, size, offsetx, offsety)
    local text_width = Render:GetTextWidth(text, size)
    local text_height = Render:GetTextHeight(text, size)
    local pos = Vector2((Render.Width - text_width + offsetx)/2, (Render.Height - text_height + offsety)/2)

    return pos
end

function DeathMatch:Render()
    if Game:GetState() ~= GUIState.Game then return end
	
	local is_visible = self.interfaceActive and (Game:GetState() == GUIState.Game)

    if self.window:GetVisible() ~= is_visible then
        self.window:SetVisible( is_visible )
    end

    if self.interfaceActive and Mouse ~= nil then
        Mouse:SetVisible( true )
    end
	
	if (self.state == "Inactive") then return end
	
    local pos = Vector2(3, Render.Height - 32)
    Render:DrawText(pos, "DeathMatch v0.2.0 By M1nd0", Color(255, 255, 255), TextSize.Default) 
    
	
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