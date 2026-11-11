// Client: in-game map editor.
//
// F8 (or console "lbr_editor")  open / close (admins only, between rounds)
// Fly around in noclip and place every point of the map config:
//   Left click     add a point (where you aim, or at your position for sky points)
//   Right click    remove the highlighted point
//   1-8 / wheel    change category
//   R              toggle "place at aim" / "place at my position"
//   E              fly to the next point of the category
//   Z (undo bind)  undo
//   Q              editor menu: save, zone radius, loot amounts, player models, import/export...

LBR = LBR or {}

local ED = LBR.Editor or {}
LBR.Editor = ED
ED.active = ED.active or false
ED.cat = ED.cat or 1
ED.undo = ED.undo or {}
ED.showAll = ED.showAll ~= false
ED.eyeMode = ED.eyeMode or {}
ED.gotoIndex = ED.gotoIndex or {}

local cats = LBR.MapCategories
local colWhite = Color( 255, 255, 255 )
local colBg = Color( 10, 14, 24, 215 )
local colErr = Color( 255, 90, 80 )
local colWarn = Color( 255, 200, 80 )
local colOk = Color( 120, 255, 150 )

surface.CreateFont( "LBR_ED_Title", { font = "Roboto", size = 22, weight = 900, antialias = true } )
surface.CreateFont( "LBR_ED_Text",  { font = "Roboto", size = 16, weight = 600, antialias = true } )
surface.CreateFont( "LBR_ED_Small", { font = "Roboto", size = 14, weight = 500, antialias = true } )
surface.CreateFont( "LBR_ED_3D",    { font = "Roboto", size = 15, weight = 800, antialias = true, outline = true } )

local hulls = {
	player = { Vector( -16, -16, 0 ), Vector( 16, 16, 72 ) },
	loot   = { Vector( -8, -8, -4 ), Vector( 8, 8, 8 ) },
	car    = { Vector( -50, -90, 0 ), Vector( 50, 90, 60 ) },
	heli   = { Vector( -150, -150, 0 ), Vector( 150, 150, 110 ) },
	zone   = { Vector( -24, -24, 0 ), Vector( 24, 24, 48 ) },
	small  = { Vector( -16, -16, -16 ), Vector( 16, 16, 16 ) },
}

local function curCat() return cats[ED.cat] end
local function list( cat ) return LBR.GetCategoryList( ED.cfg, cat or curCat(), true ) end
local function isEyeMode( cat )
	cat = cat or curCat()
	local v = ED.eyeMode[cat.key]
	if v == nil then return cat.eye == true end
	return v
end

function ED.Status( msg, col )
	ED.status = msg
	ED.statusCol = col or colWhite
	ED.statusTime = CurTime() + 6
end

local function markDirty()
	ED.dirty = true
	ED.errors, ED.warnings = LBR.ValidateMapConfig( ED.cfg )
end

------------------------------------------------------------------------
// Network
------------------------------------------------------------------------

net.Receive( "LBR_Editor_Open", function()
	local source = net.ReadString()
	local size = net.ReadUInt( 16 )
	local data = net.ReadData( size )
	local cfg = LBR.MapConfigFromJSON( util.Decompress( data ) or "" )
	ED.cfg = cfg or LBR.NewMapConfig()
	ED.source = source
	ED.active = true
	ED.undo = {}
	ED.dirty = false
	ED.errors, ED.warnings = LBR.ValidateMapConfig( ED.cfg )
	ED.Status( source == "none" and "New map: place the points and save (Q)" or ( "Loaded config (" .. source .. ")" ), colOk )
	surface.PlaySound( "buttons/button9.wav" )
end )

net.Receive( "LBR_Editor_Close", function()
	ED.active = false
	if IsValid( ED.menu ) then ED.menu:Remove() end
end )

net.Receive( "LBR_Editor_Msg", function()
	local ok = net.ReadBool()
	local msg = net.ReadString()
	ED.Status( msg, ok and colOk or colErr )
	if ok and string.StartWith( msg, "Saved" ) then ED.dirty = false end
	chat.AddText( ok and colOk or colErr, "[Map editor] ", colWhite, msg )
	surface.PlaySound( ok and "buttons/button14.wav" or "buttons/button10.wav" )
end )

function ED.Save()
	if not ED.cfg then return end
	local data = util.Compress( LBR.MapConfigToJSON( ED.cfg ) )
	if not data or #data > 60000 then
		ED.Status( "Config too big to send", colErr )
		return
	end
	net.Start( "LBR_Editor_Save" )
		net.WriteUInt( #data, 16 )
		net.WriteData( data, #data )
	net.SendToServer()
	ED.Status( "Saving..." )
end

function ED.Toggle()
	net.Start( "LBR_Editor_Toggle" )
	net.SendToServer()
end

// close, asking first when there are unsaved changes
function ED.RequestClose()
	if not ED.dirty then ED.Toggle() return end
	Derma_Query( "You have unsaved changes.", "Close map editor",
		"Save and close", function() ED.Save() timer.Simple( 0.3, ED.Toggle ) end,
		"Close without saving", function() ED.Toggle() end,
		"Cancel" )
end

// F8 opens / closes the editor (the server checks admin rights)
LBR.EditorKey = KEY_F8
local keyWasDown = false
hook.Add( "Think", "LBR_EditorKey", function()
	local down = input.IsKeyDown( LBR.EditorKey )
	if down and not keyWasDown and not gui.IsGameUIVisible() and not gui.IsConsoleVisible() and not IsValid( vgui.GetKeyboardFocus() ) then
		if ED.active then ED.RequestClose() else ED.Toggle() end
	end
	keyWasDown = down
end )

------------------------------------------------------------------------
// Editing
------------------------------------------------------------------------

local function aimTrace()
	local lp = LocalPlayer()
	local start = lp:EyePos()
	return util.TraceLine( {
		start = start,
		endpos = start + lp:EyeAngles():Forward() * 60000,
		filter = lp,
		mask = MASK_SOLID
	} )
end

// where a new point would go, nil if nothing is aimed
function ED.PlacementPos()
	local cat = curCat()
	local pos
	ED.placeOk = true
	if isEyeMode( cat ) then
		pos = LocalPlayer():GetPos()
	else
		local tr = aimTrace()
		if not tr.Hit or tr.HitSky then return nil end
		pos = tr.HitPos + Vector( 0, 0, cat.offset or 0 )
	end
	// player points snap to a spot where a player fits (no more stuck in floor / walls)
	if cat.hull == "player" and not cat.eye then
		pos, ED.placeOk = LBR.FindSafePos( pos, nil, nil, MASK_PLAYERSOLID, LocalPlayer() )
	end
	return pos
end

// point of the current category closest to the crosshair ray
local function findHovered()
	local lp = LocalPlayer()
	local eye = lp:EyePos()
	local dir = lp:EyeAngles():Forward()
	local best, bestIdx, bestDist
	for i, p in ipairs( list() ) do
		local rel = p - eye
		local along = rel:Dot( dir )
		if along > 0 then
			local perp = ( rel - dir * along ):Length()
			local tol = 40 + along * 0.03
			if perp < tol and ( not bestDist or along < bestDist ) then
				best, bestIdx, bestDist = p, i, along
			end
		end
	end
	return bestIdx, best
end

function ED.Add()
	local pos = ED.PlacementPos()
	if not pos then
		ED.Status( "Aim at a surface (or press R to place at your position)", colErr )
		return
	end
	local l = list()
	if #l >= LBR.MaxPointsPerCategory then
		ED.Status( "Too many points in this category", colErr )
		return
	end
	if not ED.placeOk then
		ED.Status( "No room for a player here: move the point away from walls", colErr )
		return
	end
	l[#l + 1] = pos
	table.insert( ED.undo, { op = "add", cat = ED.cat, pos = pos } )
	markDirty()
	surface.PlaySound( "buttons/lightswitch2.wav" )
end

function ED.Remove()
	local idx, pos = findHovered()
	if not idx then return end
	table.remove( list(), idx )
	table.insert( ED.undo, { op = "remove", cat = ED.cat, pos = pos, idx = idx } )
	markDirty()
	surface.PlaySound( "buttons/button15.wav" )
end

function ED.Undo()
	local u = table.remove( ED.undo )
	if not u then
		ED.Status( "Nothing to undo" )
		return
	end
	local l = list( cats[u.cat] )
	if u.op == "add" then
		for i = #l, 1, -1 do
			if l[i] == u.pos then table.remove( l, i ) break end
		end
	elseif u.op == "remove" then
		table.insert( l, math.min( u.idx, #l + 1 ), u.pos )
	elseif u.op == "clear" then
		for i, v in ipairs( u.points ) do l[i] = v end
	end
	ED.cat = u.cat
	markDirty()
	ED.Status( "Undone" )
end

function ED.ClearCategory()
	local l = list()
	if #l == 0 then return end
	table.insert( ED.undo, { op = "clear", cat = ED.cat, points = table.Copy( l ) } )
	for i = #l, 1, -1 do l[i] = nil end
	markDirty()
	ED.Status( "Cleared " .. curCat().name )
end

function ED.GotoNext()
	local l = list()
	if #l == 0 then return end
	local i = ( ( ED.gotoIndex[ED.cat] or 0 ) % #l ) + 1
	ED.gotoIndex[ED.cat] = i
	local target = l[i]
	// stand a bit back and above so the point is in view
	local back = LocalPlayer():EyeAngles():Forward()
	back.z = 0
	back:Normalize()
	net.Start( "LBR_Editor_Goto" )
		net.WriteVector( target - back * 150 + Vector( 0, 0, 60 ) )
	net.SendToServer()
	ED.Status( curCat().name .. " #" .. i .. " / " .. #l )
end

function ED.SetCategory( i )
	ED.cat = ( ( i - 1 ) % #cats ) + 1
	surface.PlaySound( "buttons/lightswitch2.wav" )
end

hook.Add( "PlayerBindPress", "LBR_EditorBinds", function( ply, bind, pressed )
	if not ED.active or not ED.cfg then return end
	if not pressed then
		if string.find( bind, "+attack", 1, true ) then return true end
		return
	end
	if string.find( bind, "+attack2", 1, true ) then ED.Remove() return true end
	if string.find( bind, "+attack", 1, true ) then ED.Add() return true end
	if string.find( bind, "invnext", 1, true ) then ED.SetCategory( ED.cat + 1 ) return true end
	if string.find( bind, "invprev", 1, true ) then ED.SetCategory( ED.cat - 1 ) return true end
	local slot = string.match( bind, "^slot(%d)$" )
	if slot then
		slot = tonumber( slot )
		if slot >= 1 and slot <= #cats then ED.SetCategory( slot ) end
		return true
	end
	if string.find( bind, "+reload", 1, true ) then
		ED.eyeMode[curCat().key] = not isEyeMode()
		ED.Status( isEyeMode() and "Placing at your position" or "Placing where you aim" )
		return true
	end
	if string.find( bind, "+use", 1, true ) then ED.GotoNext() return true end
	if string.find( bind, "+menu", 1, true ) and not string.find( bind, "context", 1, true ) then ED.OpenMenu() return true end
	if string.find( bind, "undo", 1, true ) then ED.Undo() return true end
end )

------------------------------------------------------------------------
// 3D drawing
------------------------------------------------------------------------

local function drawRing( center, radius, col )
	local segs = 96
	local prev
	for i = 0, segs do
		local a = ( i / segs ) * math.pi * 2
		local p = center + Vector( math.cos( a ) * radius, math.sin( a ) * radius, 0 )
		if prev then render.DrawLine( prev, p, col, false ) end
		prev = p
	end
end

hook.Add( "PostDrawTranslucentRenderables", "LBR_EditorDraw", function( depth, skybox )
	if depth or skybox or not ED.active or not ED.cfg then return end
	local eye = EyePos()
	ED.hoverIdx = findHovered()
	render.SetColorMaterial()

	for ci, cat in ipairs( cats ) do
		local current = ci == ED.cat
		if current or ED.showAll then
			local maxd = current and 40000 or 15000
			maxd = maxd * maxd
			local hull = hulls[cat.hull] or hulls.small
			local col = cat.color
			local fill = Color( col.r, col.g, col.b, current and 60 or 25 )
			local line = Color( col.r, col.g, col.b, current and 255 or 120 )
			for i, p in ipairs( LBR.GetCategoryList( ED.cfg, cat ) ) do
				if p:DistToSqr( eye ) < maxd then
					local hovered = current and i == ED.hoverIdx
					render.DrawBox( p, angle_zero, hull[1], hull[2], hovered and Color( 255, 255, 255, 90 ) or fill )
					render.DrawWireframeBox( p, angle_zero, hull[1], hull[2], hovered and colWhite or line, current )
					if current then
						// beam visible through walls to find points from far away
						cam.IgnoreZ( true )
						render.DrawLine( p, p + Vector( 0, 0, 400 ), hovered and colWhite or line, false )
						cam.IgnoreZ( false )
					end
				end
			end
			if current and cat.hull == "zone" then
				local r = ED.cfg.zone_radius or 0
				for _, p in ipairs( LBR.GetCategoryList( ED.cfg, cat ) ) do
					drawRing( p + Vector( 0, 0, 20 ), r, line )
				end
			end
		end
	end

	// preview of the next point
	local pos = ED.PlacementPos()
	if pos then
		local cat = curCat()
		local hull = hulls[cat.hull] or hulls.small
		local a = 120 + math.sin( CurTime() * 6 ) * 80
		local c = ED.placeOk and cat.color or Color( 255, 40, 40 )
		render.DrawWireframeBox( pos, angle_zero, hull[1], hull[2], Color( c.r, c.g, c.b, a ), true )
	end
end )

------------------------------------------------------------------------
// HUD
------------------------------------------------------------------------

local function line( txt, font, x, y, col )
	draw.SimpleTextOutlined( txt, font, x, y, col or colWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color( 0, 0, 0, 200 ) )
	return y + draw.GetFontHeight( font ) + 2
end

hook.Add( "HUDPaint", "LBR_EditorHUD", function()
	if not ED.active or not ED.cfg then return end

	// labels on nearby points of the current category
	local eye = EyePos()
	for i, p in ipairs( list() ) do
		if p:DistToSqr( eye ) < 2500 * 2500 then
			local s = ( p + Vector( 0, 0, 40 ) ):ToScreen()
			if s.visible then
				draw.SimpleTextOutlined( "#" .. i, "LBR_ED_3D", s.x, s.y, i == ED.hoverIdx and colWhite or curCat().color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
			end
		end
	end

	// panel
	local x, y, w = 20, 20, 330
	local h = 150 + #cats * 22 + ( #( ED.errors or {} ) + #( ED.warnings or {} ) ) * 18
	draw.RoundedBox( 8, x, y, w, h, colBg )
	x = x + 14
	y = y + 10
	y = line( "MAP EDITOR  -  " .. game.GetMap() .. ( ED.dirty and "  *" or "" ), "LBR_ED_Title", x, y, Color( 255, 210, 70 ) )
	y = line( "Source: " .. ( ED.source or "?" ) .. ( ED.dirty and "   (unsaved changes, Q > Save)" or "" ), "LBR_ED_Small", x, y, ED.dirty and colWarn or Color( 180, 180, 180 ) )
	y = y + 6
	for i, cat in ipairs( cats ) do
		local n = #LBR.GetCategoryList( ED.cfg, cat )
		local cur = i == ED.cat
		if cur then
			surface.SetDrawColor( cat.color.r, cat.color.g, cat.color.b, 50 )
			surface.DrawRect( x - 6, y - 1, w - 16, 21 )
		end
		surface.SetDrawColor( cat.color )
		surface.DrawRect( x, y + 4, 10, 10 )
		draw.SimpleText( i .. "  " .. cat.name, cur and "LBR_ED_Text" or "LBR_ED_Small", x + 18, y + 1, cur and colWhite or Color( 200, 200, 200 ) )
		draw.SimpleText( tostring( n ), "LBR_ED_Text", x + w - 40, y + 1, n > 0 and colWhite or Color( 130, 130, 130 ), TEXT_ALIGN_RIGHT )
		y = y + 22
	end
	y = y + 4
	local cat = curCat()
	y = line( cat.desc, "LBR_ED_Small", x, y, cat.color )
	y = line( "Mode [R]: " .. ( isEyeMode() and "at your position" or "where you aim" ) .. "   Zone radius: " .. ( ED.cfg.zone_radius or 0 ), "LBR_ED_Small", x, y )
	y = line( "Loot to spawn: " .. LBR.CountWeapons( ED.cfg ) .. "   Lootable spots: " .. #LBR.GetCategoryList( ED.cfg, cats[3] ), "LBR_ED_Small", x, y )
	y = y + 4
	for _, e in ipairs( ED.errors or {} ) do y = line( "X  " .. e, "LBR_ED_Small", x, y, colErr ) end
	for _, wn in ipairs( ED.warnings or {} ) do y = line( "!  " .. wn, "LBR_ED_Small", x, y, colWarn ) end
	if #( ED.errors or {} ) == 0 then line( "Map is playable", "LBR_ED_Small", x, y, colOk ) end

	// controls
	local help = {
		"LMB add   RMB remove   1-8 / wheel category",
		"R aim/position   E next point   Z undo",
		"Q menu (save)   F8 exit   SHIFT fly fast"
	}
	local hy = ScrH() - 20 - #help * 20
	for _, t in ipairs( help ) do
		draw.SimpleTextOutlined( t, "LBR_ED_Text", ScrW() / 2, hy, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black )
		hy = hy + 20
	end

	// crosshair
	local cx, cy = ScrW() / 2, ScrH() / 2
	surface.SetDrawColor( cat.color )
	surface.DrawRect( cx - 8, cy - 1, 16, 2 )
	surface.DrawRect( cx - 1, cy - 8, 2, 16 )
	if ED.hoverIdx then
		draw.SimpleTextOutlined( cat.name .. " #" .. ED.hoverIdx .. "  (RMB to remove)", "LBR_ED_Small", cx, cy + 14, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black )
	end

	if ED.status and CurTime() < ( ED.statusTime or 0 ) then
		draw.SimpleTextOutlined( ED.status, "LBR_ED_Text", cx, ScrH() * 0.2, ED.statusCol or colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
	end
end )

------------------------------------------------------------------------
// Menu (Q)
------------------------------------------------------------------------

local function openImport()
	local fr = vgui.Create( "DFrame" )
	fr:SetSize( 520, 420 )
	fr:Center()
	fr:SetTitle( "Import map config (paste the content of a .txt / JSON file)" )
	fr:MakePopup()
	local te = vgui.Create( "DTextEntry", fr )
	te:Dock( FILL )
	te:SetMultiline( true )
	local btn = vgui.Create( "DButton", fr )
	btn:Dock( BOTTOM )
	btn:SetTall( 30 )
	btn:SetText( "Import (replaces the current points, then Save to keep it)" )
	btn.DoClick = function()
		local cfg, map = LBR.MapConfigFromJSON( te:GetValue() )
		if not cfg then
			Derma_Message( "Invalid config: " .. tostring( map ), "Import", "OK" )
			return
		end
		ED.cfg = cfg
		ED.undo = {}
		markDirty()
		ED.Status( "Imported" .. ( map and map ~= game.GetMap() and ( " (made for " .. map .. "!)" ) or "" ), map and map ~= game.GetMap() and colWarn or colOk )
		fr:Close()
		if IsValid( ED.menu ) then ED.menu:Remove() ED.OpenMenu() end
	end
end

function ED.OpenMenu()
	if IsValid( ED.menu ) then ED.menu:Remove() end
	local fr = vgui.Create( "DFrame" )
	ED.menu = fr
	fr:SetSize( 440, 600 )
	fr:Center()
	fr:SetTitle( "Map editor - " .. game.GetMap() )
	fr:MakePopup()

	local scroll = vgui.Create( "DScrollPanel", fr )
	scroll:Dock( FILL )

	local function button( txt, fn, col )
		local b = scroll:Add( "DButton" )
		b:Dock( TOP )
		b:DockMargin( 4, 2, 4, 2 )
		b:SetTall( 28 )
		b:SetText( txt )
		if col then b:SetTextColor( col ) end
		b.DoClick = fn
		return b
	end
	local function label( txt )
		local l = scroll:Add( "DLabel" )
		l:Dock( TOP )
		l:DockMargin( 6, 10, 4, 2 )
		l:SetText( txt )
		l:SetFont( "LBR_ED_Text" )
		l:SetTextColor( colWhite )
		l:SizeToContents()
		return l
	end

	button( "Save to server (data/" .. LBR.MapFileName() .. ")", function() ED.Save() end, Color( 0, 120, 0 ) )
	button( "Undo", function() ED.Undo() end )
	button( "Clear current category (" .. curCat().name .. ")", function()
		Derma_Query( "Remove all " .. #list() .. " points of " .. curCat().name .. "? (Undo works)", "Clear", "Yes", function() ED.ClearCategory() end, "No" )
	end )
	local cb = scroll:Add( "DCheckBoxLabel" )
	cb:Dock( TOP )
	cb:DockMargin( 6, 6, 4, 2 )
	cb:SetText( "Show all categories (off = only the selected one)" )
	cb:SetValue( ED.showAll )
	cb.OnChange = function( _, v ) ED.showAll = v end

	label( "Zone" )
	local zr = scroll:Add( "DNumSlider" )
	zr:Dock( TOP )
	zr:DockMargin( 6, 0, 4, 0 )
	zr:SetText( "Start radius" )
	zr:SetMinMax( 1000, 150000 )
	zr:SetDecimals( 0 )
	zr:SetValue( ED.cfg.zone_radius or 20000 )
	zr.OnValueChanged = function( _, v )
		ED.cfg.zone_radius = math.floor( v )
		markDirty()
	end

	label( "Loot amount per round" )
	for i, name in ipairs( LBR.WeaponCountNames ) do
		local row = scroll:Add( "DPanel" )
		row:Dock( TOP )
		row:DockMargin( 6, 1, 4, 1 )
		row:SetTall( 24 )
		row.Paint = nil
		local l = vgui.Create( "DLabel", row )
		l:Dock( LEFT )
		l:SetWide( 200 )
		l:SetText( name )
		local wang = vgui.Create( "DNumberWang", row )
		wang:Dock( LEFT )
		wang:SetWide( 80 )
		wang:SetMinMax( 0, 1000 )
		wang:SetValue( ED.cfg.weaponsc[i] or 0 )
		wang.OnValueChanged = function( _, v )
			ED.cfg.weaponsc[i] = math.Clamp( math.floor( tonumber( v ) or 0 ), 0, 1000 )
			markDirty()
		end
	end

	button( "Loot and vehicles: which weapons / items / vehicles spawn...", function()
		if LBR.OpenLootEditor then LBR.OpenLootEditor() end
	end, Color( 150, 110, 0 ) )

	label( "Player models (one per line)" )
	local pm = scroll:Add( "DTextEntry" )
	pm:Dock( TOP )
	pm:DockMargin( 6, 0, 4, 0 )
	pm:SetTall( 110 )
	pm:SetMultiline( true )
	pm:SetValue( table.concat( ED.cfg.playermodels or {}, "\n" ) )
	pm.OnChange = function( self )
		local models = {}
		for _, l in ipairs( string.Explode( "\n", self:GetValue() ) ) do
			l = string.Trim( l )
			if string.match( string.lower( l ), "%.mdl$" ) then models[#models + 1] = l end
		end
		ED.cfg.playermodels = models
		markDirty()
	end

	label( "Share" )
	button( "Copy config to clipboard", function()
		SetClipboardText( LBR.MapConfigToJSON( ED.cfg ) )
		ED.Status( "Copied: paste it into data/" .. LBR.MapFileName() .. " to share it", colOk )
	end )
	button( "Import config (paste)", openImport )
	button( "Reload from server (discard changes)", function()
		net.Start( "LBR_Editor_Reload" )
		net.SendToServer()
	end )
	button( "Reset: delete the saved file", function()
		Derma_Query( "Delete data/" .. LBR.MapFileName() .. " on the server?\nBuilt-in maps go back to the original config, other maps become unconfigured.", "Reset", "Delete", function()
			net.Start( "LBR_Editor_Delete" )
			net.SendToServer()
		end, "Cancel" )
	end, Color( 160, 0, 0 ) )

	label( "" )
	button( "Close editor (F8)", function()
		fr:Close()
		ED.RequestClose()
	end )
end

concommand.Add( "lbr_editor_menu", function() if ED.active then ED.OpenMenu() end end )
