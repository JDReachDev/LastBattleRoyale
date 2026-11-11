// client-side file
 
include( "cl_ui.lua" )
include( "cl_scoreboard.lua" )
include( "classes.lua" )
include( "shared.lua" )
include( "cl_zone.lua" )
include( "cl_hud.lua" )
include( "cl_editor.lua" )
include( "cl_perf.lua" )
include( "cl_menus.lua" )
include( "cl_prompt.lua" )
include( "cl_loot.lua" )

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


local function changeClassCommand(ply,command,args)
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
end
concommand.Add( "lbr_changeclass", changeClassCommand )
concommand.Add( "lst_changeclass", changeClassCommand ) // old name

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

// Class menu (F3), squad menu (F4) and the squad invite popup: cl_menus.lua
