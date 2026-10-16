// client-side file
 
include( "cl_scoreboard.lua" )
include( "classes.lua" )
include( "shared.lua" )

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
	gotzonepos = GetGlobalVector( "Zone_Pos" )
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
	print("Updated teamers:")
	PrintTable(TEAMERSTAB)
	print("")
end)




-- hook.Add( "PostDrawOpaqueRenderables", "DrawingPropsBehindWallsHook", function()
	-- render.ClearStencil()
	-- render.SetStencilEnable( true )
	-- render.SetStencilFailOperation( STENCILOPERATION_KEEP )
	-- render.SetStencilZFailOperation( STENCILOPERATION_ZERO	)
	-- render.SetStencilPassOperation( STENCILOPERATION_REPLACE )
	-- render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_ALWAYS )
	-- render.SetStencilReferenceValue( 1 )
	-- for key, obje in pairs(ents.FindByClass( "cw_*" )) do if not IsValid(obje.Owner) then 
		-- obje:SetModelScale(1.05)
		-- obje:DrawModel()
		-- obje:SetModelScale(1)
	-- end end
	-- render.SetStencilReferenceValue( 2 )
	-- for key, obje in pairs(ents.FindByClass( "cw_*" )) do if not IsValid(obje.Owner) then 
		-- obje:DrawModel()
	-- end end
	-- render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_EQUAL )
	-- render.SetStencilPassOperation( STENCILOPERATION_REPLACE )
	-- render.SetStencilReferenceValue( 1 )
	-- render.SetColorMaterial()
	-- render.DrawScreenQuad()
	-- render.SetStencilEnable( false )
-- end)

		
hook.Add( "PreDrawHalos", "AddPropHalos", function()
	if GetConVar("lst_objoutline"):GetInt() == 1 then
		local estss1 = {}
		local estss2 = {}
		local estss3 = {}
		local estss4 = {}
		local estss5 = {}
		local estss6 = {}
		local estss7 = {}
		local estFull = {}
		estss1 = ents.FindByClass( "khr_*" )
		estss2 = ents.FindByClass( "cw_*" )
		estss3 = ents.FindByClass( "weapon_*" )
		estss4 = ents.FindByClass( "sg_*" )
		estss5 = ents.FindByClass( "kevlar_*" )
		estss6 = ents.FindByClass( "suit_*" )
		estss7 = ents.FindByClass( "rust_*" )
		table.Add( estFull, estss1 )
		table.Add( estFull, estss2 )
		table.Add( estFull, estss3 )
		table.Add( estFull, estss4 )
		table.Add( estFull, estss5 )
		table.Add( estFull, estss6 )
		table.Add( estFull, estss7 )
		local wHalos = {}
		for k,v in pairs(estFull) do if not IsValid(v.Owner) then 
			table.insert(wHalos, v)
		end end
		-- for k,v in pairs(ents.FindByClass( "cw_*" )) do if not IsValid(v.Owner) then 
			-- table.insert(wHalos, v)
		-- end end
		-- for k,v in pairs(ents.FindByClass( "weapon_*" )) do if not IsValid(v.Owner) then 
			-- table.insert(wHalos, v)
		-- end end
		-- for k,v in pairs(ents.FindByClass( "sg_*" )) do if not IsValid(v.Owner) then 
			-- table.insert(wHalos, v)
		-- end end
		-- for k,v in pairs(ents.FindByClass( "kevlar_*" )) do if not IsValid(v.Owner) then 
			-- table.insert(wHalos, v)
		-- end end
		-- for k,v in pairs(ents.FindByClass( "suit_*" )) do if not IsValid(v.Owner) then 
			-- table.insert(wHalos, v)
		-- end end
		-- for k,v in pairs(ents.FindByClass( "rust_*" )) do if not IsValid(v.Owner) then 
			-- table.insert(wHalos, v)
		-- end end
		halo.Add( wHalos, Color( 50, 250, 180 ), 3, 3, 1 )
	end
end )

hook.Add( "HUDShouldDraw", "hide hud", function( name )
     if ( name == "CHudHealth" or name == "CHudBattery" or name == "CHudAmmo" or name == "CHudSecondaryAmmo") then
         return false
     end
    
end )
	
hook.Add( "HUDPaint", "HUDPaint_DrawABox", function()

		if 20 >= LocalPlayer():Health() then
			surface.SetDrawColor( 0, 23, 32, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, 300, 20 )
			surface.SetDrawColor( 255, 100, 100, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, LocalPlayer():Health()*3, 20 )
			draw.DrawText( LocalPlayer():Health(), "Hud2", (ScrW()/2), ScrH()-53, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		elseif 50>= LocalPlayer():Health() then
			surface.SetDrawColor( 0, 23, 32, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, 300, 20 )
			surface.SetDrawColor( 225, 225, 100, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, LocalPlayer():Health()*3, 20 )
			draw.DrawText( LocalPlayer():Health(), "Hud2", (ScrW()/2), ScrH()-53, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		elseif LocalPlayer():Health() >= 100 then
			surface.SetDrawColor( 0, 23, 32, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, 300, 20 )
			surface.SetDrawColor( 200, 255, 200, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, 300, 20 )
			draw.DrawText( LocalPlayer():Health(), "Hud2", (ScrW()/2), ScrH()-53, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		else
			surface.SetDrawColor( 0, 23, 32, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, 300, 20 )
			surface.SetDrawColor( 200, 255, 200, 128 )
			surface.DrawRect( (ScrW()/2)-150, ScrH()-55, LocalPlayer():Health()*3, 20 )
			draw.DrawText( LocalPlayer():Health(), "Hud2", (ScrW()/2), ScrH()-53, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end

			
			
		surface.SetDrawColor( 0, 23, 32, 128 )
		surface.DrawRect( (ScrW()/2)-150, ScrH()-30, 300, 20 )
		surface.SetDrawColor( 200, 200, 255, 128 )
		surface.DrawRect( (ScrW()/2)-150, ScrH()-30, LocalPlayer():Armor()*3, 20 )
		draw.DrawText( LocalPlayer():Armor(), "Hud2", (ScrW()/2), ScrH()-28, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		
		local clip = 0
		local ammo = 0
		local wepo = LocalPlayer():GetActiveWeapon()
		if (wepo:IsValid()) then
			clip = wepo:Clip1()	
			ammo = LocalPlayer():GetAmmoCount( wepo:GetPrimaryAmmoType())
		end
			if (clip != -1) then
				if (ammo + clip) == 0 then 
				
				else
					draw.DrawText(clip, "Hud1", (ScrW()/2)+210, ScrH()-36, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT )
					surface.SetDrawColor( 255, 255, 255, 128 )
					surface.DrawRect( (ScrW()/2)+213, ScrH()-30, 1, 20 )
					draw.DrawText(ammo, "Hud2", (ScrW()/2)+218, ScrH()-27, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT )
				end
			end	
end )

local spherecolor = Color( 0, 0, 0, 0 )

hook.Add( "PostDrawTranslucentRenderables", "test", function()
	if GetConVar("lst_zonequality"):GetInt() == 3 then
	
		local m = Material("OC1Y8P0.jpg")
		render.SetMaterial(m)
		if GetGlobalInt("Zone_Radius") < 1750 then
			if spherecolor["r"] < 256 and spherecolor["g"] > 0 and spherecolor["b"] > 0 then
				spherecolor = Color( spherecolor["r"] + 0.5, spherecolor["g"] - 0.5, spherecolor["b"] - 0.5, 50 )
			end
		else
		spherecolor = Color( 0, 255, 180, 125 )
		end
		render.DrawSphere( GetGlobalVector("Zone_Pos"), -GetGlobalInt("Zone_Radius"), 30, 30, spherecolor )
		render.DrawSphere( GetGlobalVector("Zone_Pos"), GetGlobalInt("Zone_Radius")+1, 30, 30, spherecolor )
		
	elseif GetConVar("lst_zonequality"):GetInt() == 2 then
	
		if GetGlobalInt("Zone_Radius") < 1750 then
			if spherecolor["r"] < 256 and spherecolor["g"] > 0 and spherecolor["b"] > 0 then
				spherecolor = Color( spherecolor["r"] + 0.5, spherecolor["g"] - 0.5, spherecolor["b"] - 0.5, 50 )
			end
		else
		spherecolor = Color( 0, 255, 180, 125 )
		end
		render.DrawSphere( GetGlobalVector("Zone_Pos"), -GetGlobalInt("Zone_Radius"), 25, 25, spherecolor )
		render.DrawSphere( GetGlobalVector("Zone_Pos"), GetGlobalInt("Zone_Radius")+1, 25, 25, spherecolor )
		
	elseif 	GetConVar("lst_zonequality"):GetInt() == 1 then
	
		if GetGlobalInt("Zone_Radius") < 1750 then
			if spherecolor["r"] < 256 and spherecolor["g"] > 0 and spherecolor["b"] > 0 then
				spherecolor = Color( spherecolor["r"] + 0.5, spherecolor["g"] - 0.5, spherecolor["b"] - 0.5, 50 )
			end
		else
		spherecolor = Color( 0, 255, 180, 125 )
		end
		render.DrawSphere( GetGlobalVector("Zone_Pos"), -GetGlobalInt("Zone_Radius"), 15, 15, spherecolor )
		render.DrawSphere( GetGlobalVector("Zone_Pos"), GetGlobalInt("Zone_Radius")+1, 15, 15, spherecolor )
		
	elseif 	GetConVar("lst_zonequality"):GetInt() == 0 then	
	
	end
	
end )


function TeamMatesText()
	local dis
	if gotzonepos then
		dis = math.Round(LocalPlayer():GetPos():Distance(gotzonepos))
	end
	if candrawend and dis then
		local pos = GetGlobalInt( "Zone_Pos")
		pos = pos:ToScreen()
			

		surface.DrawCircle( pos.x, pos.y, 3, 255, 0, 0, 30 )
		surface.DrawCircle( pos.x, pos.y, 6, 255, 0, 0, 20 )
		surface.DrawCircle( pos.x, pos.y, 9, 255, 0, 0, 10 )
		draw.DrawText( "Safe Center", "EndPosFont1", pos.x, pos.y - 23, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		draw.DrawText( tostring(dis), "EndPosFont1", pos.x, pos.y + 8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		
	end
	if gotzonepos then
		local radius = GetGlobalInt( "Zone_Radius")
		local text
		local color
		if dis > (radius - 1250) then
			text = "Far!!"
			color = Color(255,0,00,50)
		elseif dis < 2000 then
			text = "End"
			color = Color(0,220,0,50)
		elseif dis < 10000 then
			text = "Near"
			color = Color(175,255,0,50)
		else
			text = "Far"
			color = Color(175,175,0,50)
		end
		
		
				
		draw.RoundedBox( 8, ScrW() -210, (ScrH()-100), 160, 88, Color(10,10,10,50) )
		draw.DrawText( "INFO", "WarningFont1", ScrW() -130, (ScrH()-100)+5, color_white, TEXT_ALIGN_CENTER )
		draw.DrawText( "Safe Radius: " .. radius, "WarningFont1", ScrW() -200, (ScrH()-100)+25, color_white, TEXT_ALIGN_LEFT )
		draw.DrawText( "Your Position:", "WarningFont1", ScrW() -200, (ScrH()-100)+55, color_white, TEXT_ALIGN_LEFT )
		local width = 50
		local height = 30
		local x = (ScrW() / 2) - (width / 2)
		local y = ScrH() - (height)		local width = 50
		draw.RoundedBox( 8, ScrW() -110, (ScrH()-100)+49, width, height, color )
		draw.DrawText( text, "WarningFont1", ScrW() -85, (ScrH()-100) + 49, color_white, TEXT_ALIGN_CENTER )
		draw.DrawText( tostring(dis), "EndPosFont1",  ScrW() -85, (ScrH()-100) + 65, color_white, TEXT_ALIGN_CENTER )
	end
	for k,v in pairs(player.GetAll()) do
		if v:IsBot() == false then
			if v != LocalPlayer() and v:Team() == TEAM_CONT then
				if v:SteamID64() == TEAMERSTAB[1] or v:SteamID64() == TEAMERSTAB[2] or v:SteamID64() == TEAMERSTAB[3] then
					if v:GetPos():Distance(LocalPlayer():GetPos()) < 4000 then
						local pos = (v:GetPos() + Vector(0,0,62)):ToScreen()
						draw.DrawText( v:Nick(), "TargetID", pos.x, pos.y, team.GetColor( TEAM_CONT ), TEXT_ALIGN_CENTER )
					end
				end
			end
		end
	end
	if #TEAMERSTAB > 0 then
		local cnt = 0
		local dist = 30
		// draw.RoundedBox( number cornerRadius, number x, number y, number width, number height, table color )
		draw.RoundedBox( 0, 0, (cnt) * dist, 190, 30, Color(0,0,0,230) )
		draw.DrawText( "Team-mates", "TeamListFont1", 40, (cnt) * dist, Color(255,255,255,200), TEXT_ALIGN_LEFT  )
		for k,v in pairs(TEAMERSTAB) do
			local pl = player.GetBySteamID64( v )
			if pl != false then
				cnt = cnt + 1
				draw.RoundedBox( 0, 0, (cnt) * dist, 190, 30, Color(100,100,100,200) )
				draw.DrawText( string.sub( pl:Nick(), 0, 16 ), "TeamListFont1", 5, (cnt) * dist, Color(255,255,255,200), TEXT_ALIGN_LEFT  )
			end
		end
	end
end
hook.Add( "HUDPaint", "drawteammatestext", TeamMatesText )

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
