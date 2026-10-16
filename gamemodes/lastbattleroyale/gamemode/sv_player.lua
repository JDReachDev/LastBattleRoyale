
// Server-side, used for meta player functions

TEAM_PLAYER = 1
TEAM_CONT = 2
TEAM_SPEC = 3

local ply = FindMetaTable( "Player" )

function ply:SetSpectator()
	self:StripWeapons()
	self:RemoveAllAmmo()
	self:SetTeam(TEAM_SPEC)
	self:SetNoDraw(true)
	self:SetNoCollideWithTeammates( true )
	self:AllowFlashlight( false )
	self:Spectate(6)
	self:GodEnable()
end

function ply:SetWaitingPly()
	self:UnSpectate()
	self:StripWeapons()
	self:RemoveAllAmmo()
	self:SetTeam(TEAM_PLAYER)
	self:SetModel( table.Random( MAPCONFIG[game.GetMap()]["playermodels"] ) )
	self:SetHealth(100)
	self:SetMaxHealth(100)
	self:SetArmor(0)
	self:SetWalkSpeed(200)
	self:SetRunSpeed(275)
	self:SetMaxSpeed(275)
	self:SetJumpPower(200)
	self:SetNoCollideWithTeammates( true )
	self:AllowFlashlight( false )
	self:GodEnable()
end

function ply:SetActivePlayer()
	self:UnSpectate()
	self:StripWeapons()
	self:RemoveAllAmmo()
	self:SetTeam(TEAM_CONT)
	self:SetModel( table.Random( MAPCONFIG[game.GetMap()]["playermodels"] ) )
	self:SetNoCollideWithTeammates( true )
	self:AllowFlashlight( true )
	self:GodDisable()
	if self.shouldchangeclass then
		self.shouldchangeclass = false
		player_manager.RunClass( self, "SaveStats" )
		player_manager.SetPlayerClass( self, self.class )
	end
	player_manager.OnPlayerSpawn( self )
	player_manager.RunClass( self, "Loadout" )
	player_manager.RunClass( self, "ApplyStats" )
end

function WipeStats()
	 for k,v in pairs(player.GetAll()) do
		v:ResetStats()
	 end
end

function ply:ResetStats()
	self:SetLevel(0)
	self:SetEXP(0)
	self:PrintMessage(HUD_PRINTTALK, "Your stats were reseted.")
end

function ply:LevelUpdate()
	local lvl = self:GetLevel()
	local nextlevel = lvl + 1
	local exp = self:GetEXP()
	local class = player_manager.RunClass( self, "ReturnStat", "DisplayName" )
	if exp >= nextlevel * LevelEXP() then
		self:SetEXP( self:GetEXP() - (nextlevel * LevelEXP()) )
		self:SetLevel(nextlevel)
		self:PlayerMsg(Color(255,130,0) , "You have reached level " .. nextlevel .. " on " .. class ..", Congratulations!")
		self:LevelUpdate()
	else
		local needed = (nextlevel * LevelEXP()) - self:GetEXP()
		self:PrintMessage(HUD_PRINTCONSOLE, "You need to have " .. needed .. " more EXP to reach level " .. nextlevel .. ". (" .. (nextlevel * LevelEXP()) .. ")")
	end
end

function ply:PrintStats()
	local class = player_manager.RunClass( self, "ReturnStat", "DisplayName" )
	self:PrintMessage(HUD_PRINTTALK, "Class: " .. class .. "   Level: " .. self:GetLevel() .. "   EXP: " .. self:GetEXP())
end


function ply:ForceChangeClass(class)
	self.class = class
end

function ply:ChangeClass(class)
	if CLASSES == nil then
		self:PrintMessage(HUD_PRINTTALK, "CLASSES table is invalid.")
		return
	end
	local getclass = nil
	for k,v in pairs(CLASSES) do
		if v["class"] == class then
			getclass = v
			break
		end
		if #class > 2 then
			if string.find( v["name"], class) then
				getclass = v
				break
			end
		end
	end
	if getclass == nil then
		self:PrintMessage(HUD_PRINTTALK, "Invalid class.")
		return
	end
	if getclass["premium"] then
		print("premium")
		print(self.Premium)
		if self.Premium == false then
			self:PrintMessage(HUD_PRINTTALK, "This class is for donators only.")
			return
		end
	end
	if getclass["class"] == self.class then
		self:PrintMessage(HUD_PRINTTALK, "You have this class already.")
		return
	end
	if getclass["customcheck"] != nil then
		if getclass["customcheck"](self) == false then
			if getclass["customcheckfailmsg"] != nil then
				self:PrintMessage(HUD_PRINTTALK, getclass["customcheckfailmsg"])
			else
				self:PrintMessage(HUD_PRINTTALK, "You can't use this class.")
			end
			return
		end
	end
	local needed = getclass["classesneeded"]
	local canuse = true
	if #needed > 0 then
		for k,v in pairs(needed) do
			local bclass = baseclass.Get( v["class"] )
			local lvl = self:GetPData(bclass["OVPCLASSNAME"] .. "_level", 0)
			if self.class == v["class"] then
				if self:GetLevel() < v["level"] then
					canuse = false
					self:PrintMessage(HUD_PRINTTALK, "You need to have " .. v["level"] .. " on class " .. bclass["DisplayName"] .. " to use this class")
				end
			else
				if tonumber(lvl) < v["level"] then
					canuse = false
					self:PrintMessage(HUD_PRINTTALK, "You need to have " .. v["level"] .. " on class " .. bclass["DisplayName"] .. " to use this class")
				end
			end
		end
	end
	if canuse == false then return end
	self.shouldchangeclass = true
	self.class = getclass["class"]
	self:PrintMessage(HUD_PRINTTALK, "You have sucefully changed your class to " .. baseclass.Get( getclass["class"] )["DisplayName"])
end

function UpdateAllTeamers()
	for k,v in pairs(player.GetAll()) do
		v:UpdateTeamers()
	end
end

function ply:UpdateTeamers()
	if self.TeamingPlayers == nil then return end
	net.Start( "UpdateTeamers" )
		if #self.TeamingPlayers < 4 then
			print("send teaming plys:")
			PrintTable(self.TeamingPlayers)
			net.WriteTable( self.TeamingPlayers )
		end
	net.Send(self)
end
