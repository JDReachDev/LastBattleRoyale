// client-side file
 
include( "cl_scoreboard.lua" )
include( "classes.lua" )
include( "shared.lua" )
include( "cl_zone.lua" )
include( "cl_hud.lua" )
include( "cl_editor.lua" )
include( "cl_perf.lua" )

TEAM_PLAYER = 1
TEAM_CONT = 2
TEAM_SPEC = 3

RunConsoleCommand("cw_crosshair", "1")
RunConsoleCommand("cw_disable_all_attachments_on_spawn")
if TEAMERSTAB == nil then
	TEAMERSTAB = {}
	answeredcall = nil
	lastcalltime = nil
	gotzonepos = nil
	candrawend = false
end

surface.CreateFont( "TeamListFont1", {
	font = "Arial",
	extended = false,
	size = ScreenScale(7),
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
surface.CreateFont( "EndPosFont1", {
	font = "Arial",
	extended = false,
	size = 12,
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
surface.CreateFont( "WarningFont1", {
	font = "CloseCaption_Bold",
	extended = false,
	size = 14,
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

surface.CreateFont( "Hud1", {
	font = "CloseCaption_Bold",
	extended = false,
	size = 30,
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
	outline = true,
} )

surface.CreateFont( "Hud2", {
	font = "Arial",
	extended = false,
	size = 14,
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
	outline = true,
} )

hook.Add("Tick", "checktime_teamup", function()
	if answeredcall != nil then
		if CurTime() > lastcalltime then
			answeredcall = nil
			LocalPlayer():PrintMessage(HUD_PRINTTALK, "You didn't accept the request in time")
		end
	end
end)

net.Receive( "LST_PrepStart", function( )
	
end)

net.Receive( "LST_RoundStart", function( )
	print("Round has started")
end)

net.Receive( "LST_ZoneSetup", function( )
	candrawend = true
end)

net.Receive( "LST_ActionStart", function( )
	print("Action Start")
end)

net.Receive( "LST_RoundEnd", function( )
	gotzonepos = nil
	candrawend = false
end)

net.Receive( "SendTeamRequestBack", function( )
	local getstr = net.ReadString()
	if LocalPlayer():IsBot() then
		net.Start( "SendTeamRequestBTS" )
			net.WriteBool( true )
		net.SendToServer()
		return
	end
	ShowTeamRequest(getstr)
	answeredcall = false
	lastcalltime = CurTime() + 15
	print("received team request from server")
end)

net.Receive( "UpdateTeamers", function( )
	local gettbl = net.ReadTable()
	TEAMERSTAB = gettbl
end)




// HUD: cl_hud.lua - zone and loot outlines: cl_zone.lua - map editor: cl_editor.lua


concommand.Add("lst_changeclass", function(ply,command,args)
	if args == nil then
		print("Invalid class.")
		print("List of all available classes: ")
		for k,v in pairs(CLASSES) do
			print("" .. k .. ". " .. v["name"])
		end
		return
	end
	if args[1] == nil then
		print("Invalid class.")
		print("List of all available classes: ")
		for k,v in pairs(CLASSES) do
			print("" .. k .. ". " .. v["name"])
		end
		return
	end
	if args[1] == "" then
		print("Invalid class.")
		print("List of all available classes: ")
		for k,v in pairs(CLASSES) do
			print("" .. k .. ". " .. v["name"])
		end
		return
	end
	if CLASSES == nil then
		ply:PrintMessage(HUD_PRINTCONSOLE, "CLASSES table is invalid.")
		return
	end
	local getclass = nil
	for k,v in pairs(CLASSES) do
		if v["class"] == args[1] then
			getclass = v
			break
		end
		if #args[1] > 2 then
			if string.find( v["name"], args[1]) then
				getclass = v
				break
			end
		end
	end
	if getclass == nil then
		print("Invalid class.")
		print("List of all available classes: ")
		for k,v in pairs(CLASSES) do
			print("" .. k .. ". " .. v["name"])
		end
		return
	end
	
	net.Start( "ChangeClass" )
		net.WriteString(args[1])
	net.SendToServer()
end)

function GM:Tick()
	if input.IsKeyDown( KEY_F6 ) then
		DecilineRequest()
	end
	if input.IsKeyDown( KEY_F7	) then
		AcceptRequest()
	end
end

function GM:PlayerBindPress( ply, bind, pressed )
	if bind == "gm_showspare2" then
		ShowTeamMenu()
		return
	end
	if bind == "gm_showspare1" then
		ShowClassMenu()
		return
	end
	if bind == "gm_showteam" then
		--ShowMap()
		return
	end
	if bind == "+menu" then
		net.Start( "DropWeapon" )
		net.SendToServer()
	end
end

function ShowMap()

	local frame = vgui.Create( "DFrame" )
	frame:SetSize( ScrW() /1.75, ScrH() - 100 )
	frame:Center()
	frame:MakePopup()
	local wi = 800
	local he = 800
	function frame:Paint( w, h )

		local x, y = self:GetPos()
		
		render.RenderView {
		origin = Vector(0,0,8000),
		angles = Angle(90,0,0),
		x = (ScrW()/2)-wi/2,
		y = (ScrH()/2)-he/2 ,
		w = wi,
		h = he,
		ortho = true,
		ortholeft = -15500,
		orthoright = 12800,
		orthotop = -15000,
		orthobottom = 13400,
		znear = 0,
		zfar = 10000
		}

	end
	
	-- local ply = LocalPlayer()
	-- local MainFrame = vgui.Create( "DFrame" )
	-- MainFrame:SetSize( ScrW() / 1.5, ScrH() / 1.5)
	-- MainFrame:SetTitle( "Map" )
	-- MainFrame:SetDraggable( true )
	-- MainFrame:Center()
	-- MainFrame:MakePopup()
	
	
	
	
	-- local map_image = vgui.Create( "DImage", MainFrame )
	-- map_image:Dock(FILL)
	-- map_image:SetImage( "laststand/" .. game.GetMap() .. ".jpg")

	-- local EndDot = vgui.Create( "DPanel", MainFrame )
	-- EndDot:SetSize( ScrW() / 3, ScrH() / 1.5 )
	-- EndDot:Center()
	-- function EndDot:Paint( w, h ) end
	
	-- local Shape = vgui.Create( "DLabel", MainFrame )
	-- Shape:SetSize( 32, 32 )
	-- Shape:SetText("")
	-- Shape:SetPos(ScrW() / GetGlobalFloat("Zone_Pos2D_x"), ScrH() / GetGlobalFloat("Zone_Pos2D_y"))
	-- function Shape:Paint( w, h )
		-- draw.RoundedBox( 16, 0, 0, w, h, Color(255, 0, 0, 255 ) )
	-- end
	
	-- local Shape2 = vgui.Create( "DLabel", MainFrame )
	-- Shape2:SetSize( 16, 16 )
	-- Shape2:SetText("")
	-- Shape2:SetPos(ScrW() / GetGlobalFloat("Zone_Pos2D_x") + 8, ScrH() / GetGlobalFloat("Zone_Pos2D_y")  + 8)
	-- function Shape2:Paint( w, h )
		-- draw.RoundedBox( 8, 0, 0, w, h, Color(255, 255, 255, 255 ) )
	-- end
	
end

function ShowClassMenu()
	local ply = LocalPlayer()
	
	local MainFrame = vgui.Create( "DFrame" )
	MainFrame:SetSize( ScrW() / 10, ScrH() / 4)
	MainFrame:SetTitle( "Class menu" )
	MainFrame:SetDraggable( true )
	MainFrame:Center()
	MainFrame:MakePopup()
	
	local ClassesList = vgui.Create( "DListView", MainFrame )
	ClassesList:SetMultiSelect( false )
	ClassesList:Dock(FILL)
	ClassesList:AddColumn( "Class" )
	
	for k,v in pairs(CLASSES) do
		ClassesList:AddLine( v["name"] )
	end
	function ClassesList:DoDoubleClick( lineID, line )
		RunConsoleCommand("lst_changeclass", line:GetValue( 1 ))
		MainFrame:Close()
	end
end
concommand.Add("showclassmenu", ShowClassMenu)

function ShowTeamMenu()
	local ply = LocalPlayer()
	
	local MainFrame = vgui.Create( "DFrame" )
	MainFrame:SetSize( ScrW() / 8, ScrH() / 3)
	MainFrame:SetTitle( "Team menu" )
	MainFrame:SetDraggable( true )
	MainFrame:Center()
	MainFrame:MakePopup()
	
	local ClassesList = vgui.Create( "DListView", MainFrame )
	ClassesList:SetMultiSelect( false )
	ClassesList:Dock(FILL)
	ClassesList:AddColumn( "Players" )
	
	for k,v in pairs(player.GetAll()) do
		if v:Alive() and v != LocalPlayer() and v:Team() != TEAM_SPEC then
			ClassesList:AddLine( v:Nick() )
		end
	end
	function ClassesList:DoDoubleClick( lineID, line )
		net.Start( "SendTeamRequest" )
			net.WriteString(line:GetValue( 1 ))
		net.SendToServer()
		MainFrame:Close()
	end
	
end
concommand.Add("showteammenu", ShowTeamMenu)

local RequestFrame = nil

function ShowTeamRequest(str)
	if IsValid(RequestFrame) then
		if RequestFrame:IsVisible() == false then
			RequestFrame:SetVisible( true )
			return
		else
			return
		end
	end
	surface.CreateFont( "TeamRequestFont1", {
		font = "CloseCaption_Bold",
		extended = false,
		size = ScreenScale(6),
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
	RequestFrame = vgui.Create( "DFrame" )
	RequestFrame:SetTitle( "" )
	RequestFrame:SetSize( 380, 60 )
	RequestFrame:SetSizable(false)
	RequestFrame:ShowCloseButton(false)
	RequestFrame:Dock( TOP )
	RequestFrame:DockMargin( ScrW() / 1.324, 0, 0, 0 )
	RequestFrame:DockPadding( ScrW() / 1.324, 0, 0, 0 )
	RequestFrame.Paint = function( self, w, h )
		draw.RoundedBox( 6, 0, 0, w, h, Color( 25, 25, 25, 230 ) )
	end
	
	local Panel = vgui.Create( "DLabel", RequestFrame )
	Panel:SetText(string.sub( str, 1, 15 ) .. " wants to team-up with you")
	Panel:SetSize(ScrW() / 4.8,ScrH() / 36)
	Panel:SetPos(10, 0)
	Panel:SetFont("TeamRequestFont1")
	Panel.Paint = function( self, w, h ) end
	
	local Panel = vgui.Create( "DLabel", RequestFrame )
	Panel:SetText("F6 to decline, F7 to accept")
	Panel:SetSize(ScrW() / 4.8,ScrH() / 36)
	Panel:SetPos(10, 25)
	Panel:SetFont("TeamRequestFont1")
	Panel.Paint = function( self, w, h ) end
	
end

function DecilineRequest()
	if IsValid(RequestFrame) and RequestFrame:IsVisible() then
		RequestFrame:SetVisible(false)
		net.Start( "SendTeamRequestBTS" )
			net.WriteBool( false )
		net.SendToServer()
		print("sent team request decline to server")
		answeredcall = nil
	end
end

function AcceptRequest()
	if IsValid(RequestFrame) and RequestFrame:IsVisible() then
		RequestFrame:SetVisible(false)
		net.Start( "SendTeamRequestBTS" )
			net.WriteBool( true )
		net.SendToServer()
		print("sent team request approval to server")
		answeredcall = nil
	end
end
