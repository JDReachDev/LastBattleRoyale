// Made by Kanade

TEAM_PLAYER = 1
TEAM_CONT = 2
TEAM_SPEC = 3

surface.CreateFont( "ScoreBoardFont1", {
	font = "CloseCaption_Bold",
	extended = false,
	size = ScreenScale(7.5),
	weight = 1000,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )
surface.CreateFont( "ScoreBoardFont1blur", {
	font = "CloseCaption_Bold",
	extended = false,
	size = ScreenScale(7.5),
	weight = 1000,
	blursize = 4,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )
surface.CreateFont( "ScoreBoardFont1blurKanade", {
	font = "CloseCaption_Bold",
	extended = false,
	size = ScreenScale(7.5),
	weight = 1000,
	blursize = 10,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )
surface.CreateFont( "ScoreBoardFont2", {
	font = "Arial",
	extended = false,
	size = ScreenScale(8),
	weight = 1000,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )
surface.CreateFont( "ScoreBoardFontMain", {
	font = "CloseCaption_Bold",
	extended = false,
	size = ScreenScale(13),
	weight = 800,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )
surface.CreateFont( "ScoreBoardFontMain2", {
	font = "CloseCaption_Bold",
	extended = false,
	size = ScreenScale(11),
	weight = 800,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )
surface.CreateFont( "ScoreBoardFontTeams", {
	font = "CloseCaption_Bold",
	extended = false,
	size = ScreenScale(16),
	weight = 800,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )
surface.CreateFont( "ScoreBoardFontTeamsBlur", {
	font = "CloseCaption_Bold",
	extended = false,
	size = ScreenScale(16),
	weight = 800,
	blursize = 4,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

local usergroups = {
	owner = "Owner",
	superadmin = "Super Admin",
	testadmin = "Test Admin",
	admin = "Admin",
	moderator = "Moderator",
	testmoderator = "Test Moderator",
	testmod = "Test Mod",
	operator = "Operator",
	donator = "Donator",
	vip = "Vip",
	veteran = "Veteran",
	founder = "Founder",
	creator = "Creator"
}

// please do not change this, be a good person
local donators = {
	{"76561198098529139", Color(255,255,0)}, // LionM
	{"76561198046774227", Color(0,255,0)},
	{"76561198156389563", Color(242,20,70)},
	{"76561198124708739", Color(0,255,242)} // GPX- Demo
}

local Frame = nil

function ShowScoreBoard()
	
	local count = 1
	local allplayers = player.GetAll()
	local waitingply = team.GetPlayers(TEAM_PLAYER)
	local contestants = team.GetPlayers(TEAM_CONT)
	local spectators = team.GetPlayers(TEAM_SPEC)
	
	Frame = vgui.Create( "DFrame" )
	local scrH = ScrH()
	local scrW = ScrW()
	
	local waitingply_colorbackground = Color(240, 240, 240, 100)
	local waitingply_color = Color(255, 255, 255, 255)
	local waitingply_colorbluured = Color(230, 230, 230, 160)
	local waitingply_playercolor = Color(170, 170, 170, 150)
	
	local contestant_colorbackground = Color(240, 240, 240, 100)
	local contestant_color = Color(255, 255, 255, 255)
	local contestant_colorbluured = Color(230, 230, 230, 160)
	local contestant_playercolor = Color(170, 170, 170, 150)
	
	local spectator_colorbackground = Color(250, 250, 250, 100)
	local spectator_color = Color(250, 250, 250, 255)
	local spectator_colorbluured = Color(250, 250, 250, 160)
	local spectator_playercolor = Color(150, 150, 150, 150)
	
	Frame:SetPos( 960, 540 )
	Frame:SetSize(scrW / 1.908, scrH / 1.5 )
	Frame:SetTitle( "" )
	Frame:SetVisible( true )
	Frame:SetDraggable( true )
	Frame:ShowCloseButton( true )
	Frame:Center()
	Frame:MakePopup()
	Frame.Paint = function( self, w, h )
		draw.RoundedBox( 2, 0, 0, w, h, Color( 83, 86, 90, 190 ) )
	end
	
	local dock1 = vgui.Create( "DPanel", Frame )
	dock1.Paint = function( self, w, h )
		
	end
	dock1:Dock(FILL)
	
	local DScrollPanel = vgui.Create( "DScrollPanel", dock1 )
	DScrollPanel:Dock( FILL )
	
	local main_background = vgui.Create( "DPanel", DScrollPanel )
	main_background.Paint = function( self, w, h )
		draw.RoundedBox( 4, 0, 0, w, h, (Color(150,150,150, 150)) )
	end
	main_background:SetSize(scrW / 1.908, scrH / 12.5)
	main_background:Dock(TOP)
	
	local main_hostname = vgui.Create( "DLabel", main_background )
	main_hostname:SetText(GetHostName())
	main_hostname:SetFont("ScoreBoardFontMain")
	main_hostname:SetColor(Color(255,255,255))
	main_hostname:SetSize(scrW / 4, scrH / 25)
	main_hostname:Dock(TOP)
	main_hostname:DockMargin( 10, 0, 0, 0 )
	main_hostname:DockMargin( 10, 0, 0, 0 )
	
	for k,v in pairs(player.GetAll()) do
		if v.GetLevel == nil or v.GetLSTClass == nil then
			player_manager.RunClass( v, "SetupDataTables" )
		end
	end
	
	// /////////////////////////////////////////////////////////////// waitingply ///////////////////////////////////////////////////////////////
	if #waitingply > 0 then
		count = count + 1
		local waitingply_background = vgui.Create( "DPanel", DScrollPanel )
		waitingply_background.Paint = function( self, w, h )
			draw.RoundedBox( 4, 0, 0, w, h, waitingply_colorbackground )
		end
		waitingply_background:SetSize(scrW / 1.908, scrH / 25)
		waitingply_background:SetPos(0,count * 48)
		waitingply_background:Dock(TOP)
		waitingply_background:DockMargin( 0, ScrH() / 108, 0, 0 )
		waitingply_background:DockPadding( 0, 0, 0, 0 )
		
		local waitingply_textblur = vgui.Create( "DLabel", waitingply_background )
		waitingply_textblur:SetText("Waiting Players " .. "(" .. tostring(#waitingply) .. ")")
		waitingply_textblur:SetFont("ScoreBoardFontTeamsBlur")
		waitingply_textblur:SetColor(waitingply_colorbluured)
		waitingply_textblur:SetSize(scrW / 4, scrH / 25)
		waitingply_textblur:Dock(TOP)
		
		local waitingply_text = vgui.Create( "DLabel", waitingply_textblur )
		waitingply_text:SetText("Waiting Players " .. "(" .. tostring(#waitingply) .. ")")
		waitingply_text:SetFont("ScoreBoardFontTeams")
		waitingply_text:SetColor(waitingply_color)
		waitingply_text:SetSize(scrW / 4, scrH / 25)
		waitingply_text:Dock(TOP)
		
		for k,v in pairs(waitingply) do
			count = count + 1
			local DLabel = vgui.Create( "DLabel", DScrollPanel )
			DLabel:SetText("")
			DLabel:SetHeight(scrH / 25)
			DLabel:Dock(TOP) // 250
			DLabel:DockMargin( 0, scrH / 250, 0, 0 )
			DLabel.Paint = function( self, w, h )
				draw.RoundedBox( 2, 0, 0, w, h, waitingply_playercolor )
			end
			
			
			local name = vgui.Create( "DLabel", DLabel )
			name:SetText(string.sub( v:Nick(), 1, 14 ))
			name:SetSize(scrW / 4.8,scrH / 36)
			name:Dock(TOP)
			name:DockMargin( scrH / 21.6, 4.5, 0, 0 )
			name:SetFont("ScoreBoardFont1")
			name.Paint = function( self, w, h ) end
			for key2,donator in pairs(donators) do
				if donator[1] == v:SteamID64() then
					name:SetColor(donator[2])
					local nameblur = vgui.Create( "DLabel", name )
					nameblur:SetText(string.sub( v:Nick(), 1, 14 ))
					nameblur:SetSize(scrW / 4.8,scrH / 36)
					nameblur:SetColor(donator[2])
					nameblur:SetPos(0, 0)
					nameblur:SetFont("ScoreBoardFont1blur")
				end
			end
			
			local healthicon = vgui.Create( "DImage", DLabel )
			healthicon:SetPos(scrW / 7.5, 4.5)
			healthicon:SetSize( scrH / 36, scrH / 36 )
			if v:Alive() and v:Health() > 0 then
				healthicon:SetImage( "zpicons/health.png" )
			else
				healthicon:SetImage( "zpicons/skull.png" )
			end
			
			if v:Alive() and v:Health() > 0 then
				local health = vgui.Create( "DLabel", DLabel )
				health:SetText(v:Health())
				health:SetSize(scrW / 4.8,scrH / 36)
				health:SetPos(scrW / 6.4, 4.5)
				health:SetFont("ScoreBoardFont2")
				health.Paint = function( self, w, h )
					health:SetText(v:Health())
				end
			end
			
			local fragsicon = vgui.Create( "DImage", DLabel )
			fragsicon:SetPos(scrW / 4.9, 4.5)
			fragsicon:SetSize( scrH / 36, scrH / 36 )
			fragsicon:SetImage( "zpicons/cash.png" )
			
			local frags = vgui.Create( "DLabel", DLabel )
			frags:SetPos(scrW / 4.517, 4.5)
			frags:SetText(v:Frags())
			frags:SetSize(scrW / 4.8,scrH / 36)
			frags:SetFont("ScoreBoardFont2")
			frags.Paint = function( self, w, h ) end
			
			
			local pingicon = vgui.Create( "DImage", DLabel )
			pingicon:SetPos(scrW / 2.23, 4.5)
			pingicon:SetSize( scrH / 36, scrH / 36 )
			local ping = v:Ping()
			if ping < 80 then
				if v:IsBot() == false then
					pingicon:SetImage( "zpicons/pingMax.png" )
				end
			elseif ping >= 80 and ping < 175 then
				pingicon:SetImage( "zpicons/pingGood.png" )
			elseif ping >= 175 and ping < 250 then
				pingicon:SetImage( "zpicons/pingLow.png" )
			elseif ping >= 175 and ping < 250 then
				pingicon:SetImage( "zpicons/pingCritical.png" )
			else
				pingicon:SetImage( "zpicons/pingCritical.png" )
			end
			
			local ping = vgui.Create( "DLabel", DLabel )
			if v:IsBot() then
				ping:SetText("BOT")
				ping:SetPos(scrW / 2.2, 4.5)
			else
				ping:SetText(v:Ping())
				ping:SetPos(scrW / 2.133, 4.5)
			end
			ping:SetSize(scrW / 4.8,scrH / 36)
			ping:SetFont("ScoreBoardFont2")
			
			local plinfoicon = vgui.Create( "DImage", DLabel )
			plinfoicon:SetSize( scrH / 40, scrH / 40	 )
			plinfoicon:SetPos(scrW / 4, 4.5)
			local lvl = v:GetLevel()
			if lvl < 10 then // 1-9
				plinfoicon:SetImage( "zpicons/rank1.png" )
			elseif lvl > 9 and lvl < 25 then // 10-24
				plinfoicon:SetImage( "zpicons/rank2.png" )
			elseif lvl > 24 and lvl < 50 then // 25-49
				plinfoicon:SetImage( "zpicons/rank3.png" )
			elseif lvl > 49 then // 50+
				plinfoicon:SetImage( "zpicons/rank4.png" )
			else
				plinfoicon:SetImage( "zpicons/rank1.png" )
			end
			
			local plinfo = vgui.Create( "DLabel", DLabel )
			plinfo:SetText(v:GetLSTClass() .. " " .. v:GetLevel())
			plinfo:SetSize(scrW / 5.2 ,scrH / 36)
			plinfo:SetPos(scrW / 3.7, 4.5)
			plinfo:SetFont("ScoreBoardFont2")
			plinfo.Paint = function( self, w, h ) end
			
			if usergroups[v:GetUserGroup()] or v:SteamID() == "STEAM_0:0:46273348" or v:SteamID() == "STEAM_0:1:98061917"then
				local usergroup = vgui.Create( "DLabel", DLabel )
				if v:SteamID() == "STEAM_0:0:46273348" or v:SteamID() == "STEAM_0:1:98061917" then
					usergroup:SetText("Last Stand Creator")
				else
					usergroup:SetText(usergroups[v:GetUserGroup()])
				end
				usergroup:SetSize(scrW / 4.8,scrH / 36)
				usergroup:SetPos(scrW / 2.87, 4.5)
				usergroup:SetFont("ScoreBoardFont2")
				usergroup.Paint = function( self, w, h ) end
			end
			
			local Avatar = vgui.Create( "AvatarImage", DLabel )
			Avatar:SetSize( scrH / 25, scrH / 25 )
			Avatar:SetPos( 0, 0 )
			Avatar:SetPlayer( v, 64 )
		end
	end
	
	////////////////////////////////////////////////////////////////// contestants ///////////////////////////////////////////////////////////////
	
	if #contestants > 0 then
		count = count + 1
		local contestant_background = vgui.Create( "DPanel", DScrollPanel )
		contestant_background.Paint = function( self, w, h )
			draw.RoundedBox( 4, 0, 0, w, h, contestant_colorbackground )
		end
		contestant_background:SetSize(scrW / 1.908, scrH / 25)
		contestant_background:SetPos(0,count * 48)
		contestant_background:Dock(TOP)
		contestant_background:DockMargin( 0, ScrH() / 108, 0, 0 )
		contestant_background:DockPadding( 0, 0, 0, 0 )
		
		local contestant_textblur = vgui.Create( "DLabel", contestant_background )
		contestant_textblur:SetText("Players " .. "(" .. tostring(#contestants) .. ")")
		contestant_textblur:SetFont("ScoreBoardFontTeamsBlur")
		contestant_textblur:SetColor(contestant_colorbluured)
		contestant_textblur:SetSize(scrW / 4, scrH / 25)
		contestant_textblur:Dock(TOP)
		
		local contestant_text = vgui.Create( "DLabel", contestant_textblur )
		contestant_text:SetText("Players " .. "(" .. tostring(#contestants) .. ")")
		contestant_text:SetFont("ScoreBoardFontTeams")
		contestant_text:SetColor(contestant_color)
		contestant_text:SetSize(scrW / 4, scrH / 25)
		contestant_text:Dock(TOP)
		
		for k,v in pairs(contestants) do
			count = count + 1
			local DLabel = vgui.Create( "DLabel", DScrollPanel )
			DLabel:SetText("")
			DLabel:SetHeight(scrH / 25)
			DLabel:Dock(TOP) // 250
			DLabel:DockMargin( 0, scrH / 250, 0, 0 )
			DLabel.Paint = function( self, w, h )
				draw.RoundedBox( 2, 0, 0, w, h, contestant_playercolor )
			end
			
			local name = vgui.Create( "DLabel", DLabel )
			name:SetText(string.sub( v:Nick(), 1, 14 ))
			name:SetSize(scrW / 4.8,scrH / 36)
			name:Dock(TOP)
			name:DockMargin( scrH / 21.6, 4.5, 0, 0 )
			name:SetFont("ScoreBoardFont1")
			name.Paint = function( self, w, h ) end
			for key2,donator in pairs(donators) do
				if donator[1] == v:SteamID64() then
					name:SetColor(donator[2])
					local nameblur = vgui.Create( "DLabel", name )
					nameblur:SetText(string.sub( v:Nick(), 1, 14 ))
					nameblur:SetSize(scrW / 4.8,scrH / 36)
					nameblur:SetColor(donator[2])
					nameblur:SetPos(0, 0)
					nameblur:SetFont("ScoreBoardFont1blur")
				end
			end
			
			local healthicon = vgui.Create( "DImage", DLabel )
			healthicon:SetPos(scrW / 7.5, 4.5)
			healthicon:SetSize( scrH / 36, scrH / 36 )
			if v:Alive() and v:Health() > 0 then
				healthicon:SetImage( "zpicons/health.png" )
			else
				healthicon:SetImage( "zpicons/skull.png" )
			end
			
			if v:Alive() and v:Health() > 0 then
				local health = vgui.Create( "DLabel", DLabel )
				health:SetText("Alive")//health:SetText(v:Health())
				health:SetSize(scrW / 4.8,scrH / 36)
				health:SetPos(scrW / 6.4, 4.5)
				health:SetFont("ScoreBoardFont2")
				health.Paint = function( self, w, h )
					if !IsValid(v) then return end
					health:SetText("Alive")
				end
			end
			
			local fragsicon = vgui.Create( "DImage", DLabel )
			fragsicon:SetPos(scrW / 4.9, 4.5)
			fragsicon:SetSize( scrH / 36, scrH / 36 )
			fragsicon:SetImage( "zpicons/cash.png" )
			
			local frags = vgui.Create( "DLabel", DLabel )
			frags:SetPos(scrW / 4.517, 4.5)
			frags:SetText(v:Frags())
			frags:SetSize(scrW / 4.8,scrH / 36)
			frags:SetFont("ScoreBoardFont2")
			frags.Paint = function( self, w, h ) end
			
			
			local pingicon = vgui.Create( "DImage", DLabel )
			pingicon:SetPos(scrW / 2.23, 4.5)
			pingicon:SetSize( scrH / 36, scrH / 36 )
			local ping = v:Ping()
			if ping < 80 then
				if v:IsBot() == false then
					pingicon:SetImage( "zpicons/pingMax.png" )
				end
			elseif ping >= 80 and ping < 175 then
				pingicon:SetImage( "zpicons/pingGood.png" )
			elseif ping >= 175 and ping < 250 then
				pingicon:SetImage( "zpicons/pingLow.png" )
			elseif ping >= 175 and ping < 250 then
				pingicon:SetImage( "zpicons/pingCritical.png" )
			else
				pingicon:SetImage( "zpicons/pingCritical.png" )
			end
			
			local ping = vgui.Create( "DLabel", DLabel )
			if v:IsBot() then
				ping:SetText("BOT")
				ping:SetPos(scrW / 2.2, 4.5)
			else
				ping:SetText(v:Ping())
				ping:SetPos(scrW / 2.133, 4.5)
			end
			ping:SetSize(scrW / 4.8,scrH / 36)
			ping:SetFont("ScoreBoardFont2")
			
			local plinfoicon = vgui.Create( "DImage", DLabel )
			plinfoicon:SetSize( scrH / 40, scrH / 40	 )
			plinfoicon:SetPos(scrW / 4, 4.5)
			local lvl = v:GetLevel()
			if lvl < 10 then // 1-9
				plinfoicon:SetImage( "zpicons/rank1.png" )
			elseif lvl > 9 and lvl < 25 then // 10-24
				plinfoicon:SetImage( "zpicons/rank2.png" )
			elseif lvl > 24 and lvl < 50 then // 25-49
				plinfoicon:SetImage( "zpicons/rank3.png" )
			elseif lvl > 49 then // 50+
				plinfoicon:SetImage( "zpicons/rank4.png" )
			else
				plinfoicon:SetImage( "zpicons/rank1.png" )
			end
			
			local plinfo = vgui.Create( "DLabel", DLabel )
			plinfo:SetText(v:GetLSTClass() .. " " .. v:GetLevel())
			plinfo:SetSize(scrW / 5.2 ,scrH / 36)
			plinfo:SetPos(scrW / 3.7, 4.5)
			plinfo:SetFont("ScoreBoardFont2")
			plinfo.Paint = function( self, w, h ) end
			
			if usergroups[v:GetUserGroup()] or v:SteamID() == "STEAM_0:0:46273348" or v:SteamID() == "STEAM_0:1:98061917"then
				local usergroup = vgui.Create( "DLabel", DLabel )
				if v:SteamID() == "STEAM_0:0:46273348" or v:SteamID() == "STEAM_0:1:98061917" then
					usergroup:SetText("Last Stand Creator")
				else
					usergroup:SetText(usergroups[v:GetUserGroup()])
				end
				usergroup:SetSize(scrW / 4.8,scrH / 36)
				usergroup:SetPos(scrW / 2.87, 4.5)
				usergroup:SetFont("ScoreBoardFont2")
				usergroup.Paint = function( self, w, h ) end
			end
			
			local Avatar = vgui.Create( "AvatarImage", DLabel )
			Avatar:SetSize( scrH / 25, scrH / 25 )
			Avatar:SetPos( 0, 0 )
			Avatar:SetPlayer( v, 64 )
		end
	end
	
	////////////////////////////////////////////////////////////////// SPECTATORS ///////////////////////////////////////////////////////////////
	
	if #spectators > 0 then
		count = count + 1
		local spectator_background = vgui.Create( "DPanel", DScrollPanel )
		spectator_background.Paint = function( self, w, h )
			draw.RoundedBox( 4, 0, 0, w, h, spectator_colorbackground )
		end
		spectator_background:SetSize(scrW / 1.908, scrH / 25)
		spectator_background:SetPos(0,count * 48)
		spectator_background:Dock(TOP)
		spectator_background:DockMargin( 0, ScrH() / 108, 0, 0 )
		spectator_background:DockPadding( 0, 0, 0, 0 )
		
		local spectator_textblur = vgui.Create( "DLabel", spectator_background )
		spectator_textblur:SetText("Spectators " .. "(" .. tostring(#spectators) .. ")")
		spectator_textblur:SetFont("ScoreBoardFontTeamsBlur")
		spectator_textblur:SetColor(spectator_colorbluured)
		spectator_textblur:SetSize(scrW / 4, scrH / 25)
		spectator_textblur:Dock(TOP)
		
		local spectator_text = vgui.Create( "DLabel", spectator_textblur )
		spectator_text:SetText("Spectators " .. "(" .. tostring(#spectators) .. ")")
		spectator_text:SetFont("ScoreBoardFontTeams")
		spectator_text:SetColor(contestant_color)
		spectator_text:SetSize(scrW / 4, scrH / 25)
		spectator_text:Dock(TOP)
		
		for k,v in pairs(spectators) do
			count = count + 1
			local DLabel = vgui.Create( "DLabel", DScrollPanel )
			DLabel:SetText("")
			DLabel:SetHeight(scrH / 25)
			DLabel:Dock(TOP) // 250
			DLabel:DockMargin( 0, scrH / 250, 0, 0 )
			DLabel.Paint = function( self, w, h )
				draw.RoundedBox( 2, 0, 0, w, h, spectator_playercolor )
			end
			
			local name = vgui.Create( "DLabel", DLabel )
			name:SetText(string.sub( v:Nick(), 1, 14 ))
			name:SetSize(scrW / 4.8,scrH / 36)
			name:Dock(TOP)
			name:DockMargin( scrH / 21.6, 4.5, 0, 0 )
			name:SetFont("ScoreBoardFont1")
			name.Paint = function( self, w, h ) end
			for key2,donator in pairs(donators) do
				if donator[1] == v:SteamID64() then
					name:SetColor(donator[2])
					local nameblur = vgui.Create( "DLabel", name )
					nameblur:SetText(string.sub( v:Nick(), 1, 14 ))
					nameblur:SetSize(scrW / 4.8,scrH / 36)
					nameblur:SetColor(donator[2])
					nameblur:SetPos(0, 0)
					nameblur:SetFont("ScoreBoardFont1blur")
				end
			end
			
			local healthicon = vgui.Create( "DImage", DLabel )
			healthicon:SetPos(scrW / 7.5, 4.5)
			healthicon:SetSize( scrH / 36, scrH / 36 )
			healthicon:SetImage( "zpicons/skull.png" )
			
			local fragsicon = vgui.Create( "DImage", DLabel )
			fragsicon:SetPos(scrW / 4.9, 4.5)
			fragsicon:SetSize( scrH / 36, scrH / 36 )
			fragsicon:SetImage( "zpicons/cash.png" )
			
			local frags = vgui.Create( "DLabel", DLabel )
			frags:SetPos(scrW / 4.517, 4.5)
			frags:SetText(v:Frags())
			frags:SetSize(scrW / 4.8,scrH / 36)
			frags:SetFont("ScoreBoardFont2")
			frags.Paint = function( self, w, h ) end
			
			
			local pingicon = vgui.Create( "DImage", DLabel )
			pingicon:SetPos(scrW / 2.23, 4.5)
			pingicon:SetSize( scrH / 36, scrH / 36 )
			local ping = v:Ping()
			if ping < 80 then
				if v:IsBot() == false then
					pingicon:SetImage( "zpicons/pingMax.png" )
				end
			elseif ping >= 80 and ping < 175 then
				pingicon:SetImage( "zpicons/pingGood.png" )
			elseif ping >= 175 and ping < 250 then
				pingicon:SetImage( "zpicons/pingLow.png" )
			elseif ping >= 175 and ping < 250 then
				pingicon:SetImage( "zpicons/pingCritical.png" )
			else
				pingicon:SetImage( "zpicons/pingCritical.png" )
			end
			
			local ping = vgui.Create( "DLabel", DLabel )
			if v:IsBot() then
				ping:SetText("BOT")
				ping:SetPos(scrW / 2.2, 4.5)
			else
				ping:SetText(v:Ping())
				ping:SetPos(scrW / 2.133, 4.5)
			end
			ping:SetSize(scrW / 4.8,scrH / 36)
			ping:SetFont("ScoreBoardFont2")
			
			local plinfoicon = vgui.Create( "DImage", DLabel )
			plinfoicon:SetSize( scrH / 40, scrH / 40	 )
			plinfoicon:SetPos(scrW / 4, 4.5)
			local lvl = v:GetLevel()
			if lvl < 10 then // 1-9
				plinfoicon:SetImage( "zpicons/rank1.png" )
			elseif lvl > 9 and lvl < 25 then // 10-24
				plinfoicon:SetImage( "zpicons/rank2.png" )
			elseif lvl > 24 and lvl < 50 then // 25-49
				plinfoicon:SetImage( "zpicons/rank3.png" )
			elseif lvl > 49 then // 50+
				plinfoicon:SetImage( "zpicons/rank4.png" )
			else
				plinfoicon:SetImage( "zpicons/rank1.png" )
			end
			
			local plinfo = vgui.Create( "DLabel", DLabel )
			plinfo:SetText(v:GetLSTClass() .. " " .. v:GetLevel())
			plinfo:SetSize(scrW / 5.2 ,scrH / 36)
			plinfo:SetPos(scrW / 3.7, 4.5)
			plinfo:SetFont("ScoreBoardFont2")
			plinfo.Paint = function( self, w, h ) end
			
			if usergroups[v:GetUserGroup()] or v:SteamID() == "STEAM_0:0:46273348" or v:SteamID() == "STEAM_0:1:98061917"then
				local usergroup = vgui.Create( "DLabel", DLabel )
				if v:SteamID() == "STEAM_0:0:46273348" or v:SteamID() == "STEAM_0:1:98061917" then
					usergroup:SetText("Last Stand Creator")
				else
					usergroup:SetText(usergroups[v:GetUserGroup()])
				end
				usergroup:SetSize(scrW / 4.8,scrH / 36)
				usergroup:SetPos(scrW / 2.87, 4.5)
				usergroup:SetFont("ScoreBoardFont2")
				usergroup.Paint = function( self, w, h ) end
			end
			
			local Avatar = vgui.Create( "AvatarImage", DLabel )
			Avatar:SetSize( scrH / 25, scrH / 25 )
			Avatar:SetPos( 0, 0 )
			Avatar:SetPlayer( v, 64 )
		end
	end
	
end

function GM:ScoreboardShow()
	ShowScoreBoard()
end

function GM:ScoreboardHide()
	if IsValid(Frame) then
		Frame:SetVisible(false)
	end
end
