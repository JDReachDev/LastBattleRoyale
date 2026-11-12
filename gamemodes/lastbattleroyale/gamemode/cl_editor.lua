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
//   M              map from above with the points (wheel / 0-8: all or one category,
//                  left click: fly there, right click: remove a point), see cl_map.lua

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
local colErr = Color( 255, 90, 80 )
local colWarn = Color( 255, 200, 80 )
local colOk = Color( 120, 255, 150 )

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
	LBR.UI.Query( "You have unsaved changes.", "Close map editor",
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

// remove point idx of category ci (right click on the editor map)
function ED.RemovePoint( ci, idx )
	local l = list( cats[ci] )
	local pos = l[idx]
	if not pos then return end
	table.remove( l, idx )
	table.insert( ED.undo, { op = "remove", cat = ci, pos = pos, idx = idx } )
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
		// on the map: 0 = every category, 1-8 = only that one
		if LBR.Map and LBR.Map.open and slot <= #cats then LBR.Map.EdFilter( slot ) end
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
	if depth or skybox or not ED.active or not ED.cfg or LBR.MapRendering then return end
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

// same look as the menus (cl_ui.lua): dark flat panels, gold accent, white text
local function line( txt, font, x, y, col )
	draw.SimpleText( txt, font, x, y, col or colWhite )
	return y + draw.GetFontHeight( font ) + LBR.UI.S( 2 )
end

// key chip: [KEY] label
local function keyHint( key, label, x, y )
	local UI, S = LBR.UI, LBR.UI.S
	surface.SetFont( "LBR_UI_Tiny" )
	local kw = math.max( surface.GetTextSize( key ) + S( 12 ), S( 22 ) )
	local h = S( 20 )
	UI.Box( x, y, kw, h, Color( 255, 255, 255, 30 ) )
	surface.SetDrawColor( 255, 255, 255, 70 )
	surface.DrawOutlinedRect( x, y, kw, h )
	UI.Text( key, "LBR_UI_Tiny", x + kw / 2, y + h / 2, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	surface.SetFont( "LBR_UI_Small" )
	local lw = surface.GetTextSize( label )
	UI.Text( label, "LBR_UI_Small", x + kw + S( 6 ), y + h / 2, UI.col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	return kw + S( 6 ) + lw
end

hook.Add( "HUDPaint", "LBR_EditorHUD", function()
	if not ED.active or not ED.cfg then return end
	local UI, S, C = LBR.UI, LBR.UI.S, LBR.UI.col

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
	local small = draw.GetFontHeight( "LBR_UI_Small" ) + S( 2 )
	local rowH = S( 24 )
	local x, y, w = S( 20 ), S( 20 ), S( 360 )
	local h = S( 24 ) + draw.GetFontHeight( "LBR_UI_Head" ) + small + S( 10 ) + #cats * rowH + S( 8 ) + small * 3 + S( 6 )
		+ ( #( ED.errors or {} ) + #( ED.warnings or {} ) + ( #( ED.errors or {} ) == 0 and 1 or 0 ) ) * small + S( 8 )
	UI.Box( x, y, w, h, C.bg )
	UI.Box( x, y, w, S( 3 ), C.accent )
	x = x + S( 14 )
	y = y + S( 12 )
	y = line( "MAP EDITOR  -  " .. game.GetMap() .. ( ED.dirty and "  *" or "" ), "LBR_UI_Head", x, y, C.accent )
	y = line( "Source: " .. ( ED.source or "?" ) .. ( ED.dirty and "   (unsaved changes, Q > Save)" or "" ), "LBR_UI_Small", x, y, ED.dirty and colWarn or C.dim )
	y = y + S( 10 )
	for i, cat in ipairs( cats ) do
		local n = #LBR.GetCategoryList( ED.cfg, cat )
		local cur = i == ED.cat
		local rw = w - S( 28 )
		UI.Box( x - S( 4 ), y, rw + S( 8 ), rowH - S( 2 ), cur and Color( cat.color.r, cat.color.g, cat.color.b, 45 ) or C.row )
		if cur then UI.Accent( x - S( 4 ), y, rowH - S( 2 ), cat.color ) end
		surface.SetDrawColor( cat.color )
		surface.DrawRect( x + S( 6 ), y + ( rowH - S( 2 ) ) / 2 - S( 4 ), S( 8 ), S( 8 ) )
		UI.Text( i .. "  " .. cat.name, cur and "LBR_UI_Text" or "LBR_UI_Small", x + S( 22 ), y + ( rowH - S( 2 ) ) / 2, cur and colWhite or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		UI.Text( tostring( n ), "LBR_UI_Text", x + rw - S( 4 ), y + ( rowH - S( 2 ) ) / 2, n > 0 and colWhite or C.locked, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		y = y + rowH
	end
	y = y + S( 8 )
	local cat = curCat()
	y = line( cat.desc, "LBR_UI_Small", x, y, cat.color )
	y = line( "Mode [R]: " .. ( isEyeMode() and "at your position" or "where you aim" ) .. "   Zone radius: " .. ( ED.cfg.zone_radius or 0 ), "LBR_UI_Small", x, y, C.text )
	y = line( "Loot to spawn: " .. LBR.CountWeapons( ED.cfg ) .. "   Lootable spots: " .. #LBR.GetCategoryList( ED.cfg, cats[3] ), "LBR_UI_Small", x, y, C.text )
	y = y + S( 6 )
	for _, e in ipairs( ED.errors or {} ) do y = line( "X  " .. e, "LBR_UI_Small", x, y, colErr ) end
	for _, wn in ipairs( ED.warnings or {} ) do y = line( "!  " .. wn, "LBR_UI_Small", x, y, colWarn ) end
	if #( ED.errors or {} ) == 0 then line( "Map is playable", "LBR_UI_Small", x, y, colOk ) end

	// controls
	local help = {
		{ { "LMB", "add" }, { "RMB", "remove" }, { "1-8 / WHEEL", "category" } },
		{ { "R", "aim / position" }, { "E", "next point" }, { "Z", "undo" }, { "M", "map" } },
		{ { "Q", "menu (save)" }, { "F8", "exit" }, { "SHIFT", "fly fast" } },
	}
	local lineH = S( 26 )
	local bw, bh = S( 560 ), #help * lineH + S( 14 )
	local bx, by = ScrW() / 2 - bw / 2, ScrH() - S( 20 ) - bh
	UI.Box( bx, by, bw, bh, C.bg )
	UI.Box( bx, by, bw, S( 2 ), C.accent )
	for li, row in ipairs( help ) do
		local cx = bx + S( 16 )
		for _, k in ipairs( row ) do
			cx = cx + keyHint( k[1], k[2], cx, by + S( 9 ) + ( li - 1 ) * lineH ) + S( 18 )
		end
	end

	// crosshair
	local cx, cy = ScrW() / 2, ScrH() / 2
	surface.SetDrawColor( cat.color )
	surface.DrawRect( cx - S( 8 ), cy - 1, S( 16 ), 2 )
	surface.DrawRect( cx - 1, cy - S( 8 ), 2, S( 16 ) )
	if ED.hoverIdx then
		local t = cat.name .. " #" .. ED.hoverIdx .. "  (RMB to remove)"
		surface.SetFont( "LBR_UI_Small" )
		local tw, th = surface.GetTextSize( t )
		UI.Box( cx - tw / 2 - S( 8 ), cy + S( 14 ), tw + S( 16 ), th + S( 6 ), C.bg )
		UI.Text( t, "LBR_UI_Small", cx, cy + S( 17 ), colWhite, TEXT_ALIGN_CENTER )
	end

	if ED.status and CurTime() < ( ED.statusTime or 0 ) then
		surface.SetFont( "LBR_UI_Head" )
		local tw, th = surface.GetTextSize( ED.status )
		local sw, sh = tw + S( 40 ), th + S( 14 )
		local sx, sy = cx - sw / 2, ScrH() * 0.2 - sh / 2
		local sc = ED.statusCol or colWhite
		UI.Box( sx, sy, sw, sh, C.bg )
		UI.Box( sx, sy, S( 4 ), sh, sc )
		UI.Text( ED.status, "LBR_UI_Head", sx + S( 20 ), sy + sh / 2, colWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end
end )

------------------------------------------------------------------------
// Menu (Q)
------------------------------------------------------------------------

// dark text fields like the rest of the menus
local function styleEntry( te )
	local C = LBR.UI.col
	te:SetFont( "LBR_UI_Small" )
	te.Paint = function( self, w, h )
		LBR.UI.Box( 0, 0, w, h, Color( 0, 0, 0, 120 ) )
		surface.SetDrawColor( 255, 255, 255, self:HasFocus() and 70 or 25 )
		surface.DrawOutlinedRect( 0, 0, w, h )
		self:DrawTextEntryText( C.text, C.accent, C.text )
	end
end

local function openImport()
	local UI, S, C = LBR.UI, LBR.UI.S, LBR.UI.col
	local fr = UI.Frame( S( 560 ), S( 480 ), "Import map config", "Paste the content of a .txt / JSON file" )
	fr:SetKeyboardInputEnabled( true )
	local te = vgui.Create( "DTextEntry", fr )
	te:Dock( FILL )
	te:SetMultiline( true )
	styleEntry( te )
	local btn = UI.Button( fr, "IMPORT (replaces the current points, then Save to keep it)", C.good, function()
		local cfg, map = LBR.MapConfigFromJSON( te:GetValue() )
		if not cfg then
			LBR.UI.Query( "Invalid config: " .. tostring( map ), "Import", "OK" )
			return
		end
		ED.cfg = cfg
		ED.undo = {}
		markDirty()
		ED.Status( "Imported" .. ( map and map ~= game.GetMap() and ( " (made for " .. map .. "!)" ) or "" ), map and map ~= game.GetMap() and colWarn or colOk )
		fr:Close()
		if IsValid( ED.menu ) then ED.menu:Remove() ED.OpenMenu() end
	end )
	btn:Dock( BOTTOM )
	btn:DockMargin( 0, S( 10 ), 0, 0 )
	btn:SetTall( S( 32 ) )
end

function ED.OpenMenu()
	if IsValid( ED.menu ) then ED.menu:Remove() end
	local UI, S, C = LBR.UI, LBR.UI.S, LBR.UI.col
	local fr = UI.Frame( S( 480 ), S( 720 ), "Map editor", game.GetMap() .. ( ED.dirty and "  -  unsaved changes" or "" ) )
	fr:SetKeyboardInputEnabled( true ) // text fields
	ED.menu = fr

	local scroll = UI.Scroll( fr )
	scroll:Dock( FILL )

	local function button( txt, fn, col )
		local b = UI.Button( scroll, txt, col or C.dim, fn )
		b:Dock( TOP )
		b:DockMargin( 0, S( 3 ), S( 8 ), S( 3 ) )
		b:SetTall( S( 30 ) )
		return b
	end
	local function label( txt )
		return UI.Section( scroll, txt ):DockMargin( 0, S( 12 ), S( 8 ), S( 4 ) )
	end

	label( "Map" )
	button( "Save to server (data/" .. LBR.MapFileName() .. ")", function() ED.Save() end, C.good )
	button( "Undo", function() ED.Undo() end )
	button( "Clear current category (" .. curCat().name .. ")", function()
		LBR.UI.Query( "Remove all " .. #list() .. " points of " .. curCat().name .. "? (Undo works)", "Clear", "Yes", function() ED.ClearCategory() end, "No" )
	end )
	local cb = scroll:Add( "DCheckBoxLabel" )
	cb:Dock( TOP )
	cb:DockMargin( S( 2 ), S( 8 ), S( 8 ), S( 2 ) )
	cb:SetText( "Show all categories (off = only the selected one)" )
	cb:SetFont( "LBR_UI_Small" )
	cb:SetTextColor( C.text )
	cb:SetValue( ED.showAll )
	cb.OnChange = function( _, v ) ED.showAll = v end

	label( "Zone" )
	local zr = scroll:Add( "DNumSlider" )
	zr:Dock( TOP )
	zr:DockMargin( S( 2 ), 0, S( 8 ), 0 )
	zr:SetText( "Start radius" )
	zr.Label:SetFont( "LBR_UI_Small" )
	zr.Label:SetTextColor( C.text )
	zr:GetTextArea():SetTextColor( C.text )
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
		row:DockMargin( 0, S( 1 ), S( 8 ), S( 1 ) )
		row:SetTall( S( 28 ) )
		row.Paint = function( self, w, h ) UI.Box( 0, 0, w, h, C.row ) end
		local l = vgui.Create( "DLabel", row )
		l:Dock( LEFT )
		l:DockMargin( S( 10 ), 0, 0, 0 )
		l:SetWide( S( 220 ) )
		l:SetFont( "LBR_UI_Small" )
		l:SetTextColor( C.text )
		l:SetText( name )
		local wang = vgui.Create( "DNumberWang", row )
		wang:Dock( RIGHT )
		wang:DockMargin( 0, S( 3 ), S( 4 ), S( 3 ) )
		wang:SetWide( S( 90 ) )
		wang:SetMinMax( 0, 1000 )
		wang:SetValue( ED.cfg.weaponsc[i] or 0 )
		styleEntry( wang )
		wang.OnValueChanged = function( _, v )
			ED.cfg.weaponsc[i] = math.Clamp( math.floor( tonumber( v ) or 0 ), 0, 1000 )
			markDirty()
		end
	end

	button( "Loot and vehicles: which weapons / items / vehicles spawn...", function()
		if LBR.OpenLootEditor then LBR.OpenLootEditor() end
	end, C.accent ):DockMargin( 0, S( 8 ), S( 8 ), S( 3 ) )

	label( "Player models (one per line)" )
	local pm = scroll:Add( "DTextEntry" )
	pm:Dock( TOP )
	pm:DockMargin( 0, 0, S( 8 ), 0 )
	pm:SetTall( S( 110 ) )
	pm:SetMultiline( true )
	styleEntry( pm )
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
	end, C.blue )
	button( "Import config (paste)", openImport, C.blue )
	button( "Reload from server (discard changes)", function()
		net.Start( "LBR_Editor_Reload" )
		net.SendToServer()
	end )
	button( "Reset: delete the saved file", function()
		LBR.UI.Query( "Delete data/" .. LBR.MapFileName() .. " on the server?\nBuilt-in maps go back to the original config, other maps become unconfigured.", "Reset", "Delete", function()
			net.Start( "LBR_Editor_Delete" )
			net.SendToServer()
		end, "Cancel" )
	end, C.bad )

	button( "Close editor (F8)", function()
		fr:Close()
		ED.RequestClose()
	end ):DockMargin( 0, S( 16 ), S( 8 ), S( 3 ) )
end

concommand.Add( "lbr_editor_menu", function() if ED.active then ED.OpenMenu() end end )
