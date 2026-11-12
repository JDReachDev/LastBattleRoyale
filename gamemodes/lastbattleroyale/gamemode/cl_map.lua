// Map (M, or the MAP button in the TAB menu): the map seen from above with you,
// your squad, the safe zone, supply drops, the nuke target, where teammates fell and
// the squad markers (left click on the map sets yours, right click removes it; they
// also show on the compass and on screen).
//
// The picture is rendered only once (the first time the map is opened, and again
// only if the map area changes) into a texture: an orthographic camera above the
// sky, with the sky cut away by the near plane. Opening the map after that only
// draws that texture, so it costs nothing.
// The map area (sv_map.lua) comes from the configured points of the map.

LBR = LBR or {}
local UI = LBR.UI
local S = UI.S
local C = UI.col

local Map = LBR.Map or {}
LBR.Map = Map
Map.open = Map.open or false

local RT_SIZE = 2048
local GRID = 8 // cells on the long side; the short side gets as many as fit (square cells)
local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H" }

local colMe = Color( 255, 255, 255 )
local colMate = Color( 255, 210, 70 )
local colShadow = Color( 0, 0, 0, 220 )
local colGrid = Color( 255, 255, 255, 28 )
local colPing = Color( 90, 200, 255 )
local colDrop = Color( 255, 150, 40 )
local colNuke = Color( 255, 60, 50 )
local colDead = Color( 175, 180, 190 )

local function units2m( u ) return math.Round( u * 0.01905 ) end
local function fmtTime( t )
	t = math.max( math.ceil( t ), 0 )
	return string.format( "%d:%02d", math.floor( t / 60 ), t % 60 )
end

local rt, rtMat
local builtSig // map area the texture was rendered for
local needBuild = false

------------------------------------------------------------------------
// Map area
------------------------------------------------------------------------

// In the map editor the area is the one of the points being placed (saved or not),
// found by the server exactly like the one of the saved config (ground scan from
// above, sv_map.lua): the client sends the box of the points and a sample of them
// when they change, the server answers with the area.
local edMins, edMaxs, edNext, edSent = nil, nil, 0, nil

net.Receive( "LBR_Editor_Bounds", function()
	edMins, edMaxs = net.ReadVector(), net.ReadVector()
end )

local function editorBounds()
	local ED = LBR.Editor
	if not ( Map.edMode and ED and ED.active and ED.cfg ) then return nil end
	if CurTime() > edNext then
		edNext = CurTime() + 0.5
		local mins, maxs
		local points = {}
		for _, cat in ipairs( LBR.MapCategories ) do
			// same categories as the server (no lobby, nuke targets or sky supply drops)
			if cat.key == "playerspawns" or cat.key == "weaponspawns" or cat.key == "vehiclepositions"
				or cat.key == "flying_vehiclespawns" or cat.key == "endpositions" then
				for _, p in ipairs( LBR.GetCategoryList( ED.cfg, cat ) ) do
					points[#points + 1] = p
					if not mins then
						mins, maxs = Vector( p ), Vector( p )
					else
						mins.x, mins.y, mins.z = math.min( mins.x, p.x ), math.min( mins.y, p.y ), math.min( mins.z, p.z )
						maxs.x, maxs.y, maxs.z = math.max( maxs.x, p.x ), math.max( maxs.y, p.y ), math.max( maxs.z, p.z )
					end
				end
			end
		end
		if not mins then
			edMins, edMaxs, edSent = nil, nil, nil
		else
			local sig = string.format( "%d %d %d %d %d %d %d", mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z, #points )
			if sig ~= edSent then
				edSent = sig
				local step = math.max( 1, math.floor( #points / 64 ) )
				local sample = {}
				for i = 1, #points, step do
					if #sample < 64 then sample[#sample + 1] = points[i] end
				end
				net.Start( "LBR_Editor_Bounds" )
					net.WriteVector( mins )
					net.WriteVector( maxs )
					net.WriteUInt( #sample, 7 )
					for _, p in ipairs( sample ) do net.WriteVector( p ) end
				net.SendToServer()
			end
		end
	end
	return edMins, edMaxs
end

local function getBounds()
	local mins, maxs = editorBounds()
	if not mins then
		mins = GetGlobalVector( "LBR_MapMins", vector_origin )
		maxs = GetGlobalVector( "LBR_MapMaxs", vector_origin )
	end
	if maxs.x - mins.x < 100 or maxs.y - mins.y < 100 then return nil end
	return mins, maxs
end

local function boundsSig( mins, maxs )
	return string.format( "%d %d %d %d %d", mins.x, mins.y, maxs.x, maxs.y, maxs.z )
end

------------------------------------------------------------------------
// Render from above (once)
------------------------------------------------------------------------

local function build()
	local mins, maxs = getBounds()
	if not mins then return end

	if not rt then
		// own depth buffer: the texture is bigger than the screen
		rt = GetRenderTargetEx( "LBR_MapRT", RT_SIZE, RT_SIZE, RT_SIZE_NO_CHANGE,
			MATERIAL_RT_DEPTH_SEPARATE, bit.bor( 4, 8 ), 0, IMAGE_FORMAT_RGB888 )
		rtMat = CreateMaterial( "LBR_MapMat", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(), ["$vertexcolor"] = 1, ["$vertexalpha"] = 1,
		} )
	end

	// square view around the map area; the map rectangle is cut out of it when drawn
	local half = math.max( maxs.x - mins.x, maxs.y - mins.y ) / 2
	local skyZ = maxs.z
	// above the sky (outside the map the engine draws everything, no visibility culling);
	// the near plane starts just under the sky ceiling so the sky does not cover the map
	local camZ = skyZ + 1024
	local origin = Vector( ( mins.x + maxs.x ) / 2, ( mins.y + maxs.y ) / 2, camZ )

	LBR.MapRendering = true
	render.PushRenderTarget( rt )
	render.Clear( 18, 22, 30, 255, true, true )
	render.RenderView( {
		origin = origin,
		angles = Angle( 90, 90, 0 ), // looking down, north (+y) up, east (+x) right
		x = 0, y = 0, w = RT_SIZE, h = RT_SIZE,
		aspect = 1,
		ortho = { left = -half, right = half, top = -half, bottom = half },
		znear = camZ - skyZ + 24,
		zfar = camZ - mins.z + 4000,
		drawhud = false, drawviewmodel = false, drawmonitors = false,
		dopostprocess = false, bloomtone = false,
	} )
	render.PopRenderTarget()
	LBR.MapRendering = false

	builtSig = boundsSig( mins, maxs )
end

// render outside the main view, right after a frame
hook.Add( "PostRender", "LBR_MapBuild", function()
	if not needBuild then return end
	needBuild = false
	local ok, err = pcall( build )
	LBR.MapRendering = false
	if not ok then ErrorNoHalt( "[LBR] map render failed: " .. tostring( err ) .. "\n" ) end
end )

// while rendering the map: no fog, no sky, no zone wall (see cl_zone.lua)
hook.Add( "SetupWorldFog", "LBR_MapNoFog", function()
	if not LBR.MapRendering then return end
	render.FogMode( MATERIAL_FOG_NONE )
	return true
end )
hook.Add( "PreDrawSkyBox", "LBR_MapNoSky", function()
	if LBR.MapRendering then return true end
end )

concommand.Add( "lbr_map_rebuild", function() builtSig = nil end )

------------------------------------------------------------------------
// Open / close
------------------------------------------------------------------------

// in the map editor the map shows the editor points: a transparent panel over the
// screen takes the mouse wheel (category filter) and the clicks
local function editorCapture( on )
	if on then
		if IsValid( Map.edPanel ) then return end
		local p = vgui.Create( "DPanel" )
		p:SetPos( 0, 0 )
		p:SetSize( ScrW(), ScrH() )
		p:SetMouseInputEnabled( true )
		p:SetKeyboardInputEnabled( false )
		p.Paint = function() end
		p.OnMouseWheeled = function( _, d ) Map.EdFilter( ( Map.edFilter or 0 ) - d ) end
		p.OnMousePressed = function( _, code ) Map.EdClick( code ) end
		Map.edPanel = p
	elseif IsValid( Map.edPanel ) then
		Map.edPanel:Remove()
		Map.edPanel = nil
	end
end

// the mouse cursor is on while the map is open (to place the squad marker)
function Map.Toggle( state )
	if state == nil then state = not Map.open end
	if state == Map.open then return end
	Map.open = state
	Map.edMode = state and LBR.Editor and LBR.Editor.active or false
	// the map opens on the category chosen in the editor (unless it shows all of them)
	if Map.edMode and ( Map.edFilter or 0 ) > 0 then Map.edFilter = LBR.Editor.cat or Map.edFilter end
	gui.EnableScreenClicker( state )
	editorCapture( state and Map.edMode )
end

// editor map: 0 = every category, 1-8 = only that one
function Map.EdFilter( f )
	local n = #LBR.MapCategories + 1
	Map.edFilter = ( ( math.floor( f ) % n ) + n ) % n
	// same category in the editor and on the map (0 = all categories keeps the editor one)
	local ED = LBR.Editor
	if ED and ED.active and Map.edFilter > 0 then ED.cat = Map.edFilter end
	surface.PlaySound( "buttons/lightswitch2.wav" )
end

concommand.Add( "lbr_map", function() Map.Toggle() end )

local typing = false
hook.Add( "StartChat", "LBR_MapTyping", function() typing = true end )
hook.Add( "FinishChat", "LBR_MapTyping", function() typing = false end )

local keyWasDown = false
hook.Add( "Think", "LBR_MapKey", function()
	local down = input.IsKeyDown( KEY_M )
	if down and not keyWasDown and not typing and not gui.IsGameUIVisible() and not gui.IsConsoleVisible()
		and not IsValid( vgui.GetKeyboardFocus() ) then
		Map.Toggle()
	end
	keyWasDown = down

	if Map.open then
		// opened in the editor and the editor closed, or the other way round
		if Map.edMode ~= ( LBR.Editor and LBR.Editor.active or false ) then
			Map.Toggle( false )
		elseif not vgui.CursorVisible() and not gui.IsGameUIVisible() then
			gui.EnableScreenClicker( true ) // the TAB menu turned it off when it closed
		end
	end
end )

------------------------------------------------------------------------
// Squad positions (a far teammate is dormant: his position comes from sv_map.lua)
------------------------------------------------------------------------

local matePos = {} // steamid64 -> { x, y, yaw, t }

net.Receive( "LBR_MatePos", function()
	local n = net.ReadUInt( 3 )
	local now = CurTime()
	for i = 1, n do
		local sid = net.ReadString()
		local x, y = net.ReadFloat(), net.ReadFloat()
		local yaw = net.ReadInt( 10 )
		matePos[sid] = { x = x, y = y, yaw = yaw, t = now }
	end
end )

// supply drops still to open, squad markers, where teammates fell
local drops = {}       // { { x, y }, ... }
Map.pings = {}         // steamid64 -> Vector
local deaths = {}      // steamid64 -> { x, y }

net.Receive( "LBR_MapDrops", function()
	drops = {}
	for i = 1, net.ReadUInt( 5 ) do
		drops[i] = { x = net.ReadFloat(), y = net.ReadFloat() }
	end
end )

net.Receive( "LBR_MapPing", function()
	local sid = net.ReadString()
	if net.ReadBool() then
		Map.pings[sid] = net.ReadVector()
		surface.PlaySound( "buttons/blip1.wav" )
	else
		Map.pings[sid] = nil
	end
end )

net.Receive( "LBR_MateDeath", function()
	local sid = net.ReadString()
	deaths[sid] = { x = net.ReadFloat(), y = net.ReadFloat() }
end )

// a new round phase clears markers and fallen teammates
local lastState
hook.Add( "Think", "LBR_MapState", function()
	local st = GetGlobalInt( "state" )
	if st ~= lastState then
		lastState = st
		Map.pings, deaths = {}, {}
	end
end )

local function inSquad( sid )
	for _, s in ipairs( TEAMERSTAB or {} ) do
		if s == sid then return true end
	end
	return false
end

// markers to show: yours and your squad's ( { pos, col, nick, mine } )
function Map.GetPings()
	local out = {}
	local lp = LocalPlayer()
	if not IsValid( lp ) then return out end
	local mySid = lp:SteamID64()
	for sid, pos in pairs( Map.pings ) do
		local mine = sid == mySid
		if mine or inSquad( sid ) then
			local pl = player.GetBySteamID64( sid )
			out[#out + 1] = { pos = pos, col = mine and colPing or colMate, nick = IsValid( pl ) and pl:Nick() or "", mine = mine }
		end
	end
	return out
end

local function sendPing( x, y )
	net.Start( "LBR_MapPing" )
		net.WriteBool( x ~= nil )
		if x then
			net.WriteFloat( x )
			net.WriteFloat( y )
		end
	net.SendToServer()
end

// click on the map: left sets your marker, right removes it
hook.Add( "GUIMousePressed", "LBR_MapPing", function( code )
	local L = Map.open and not Map.edMode and Map.layout
	if not L then return end
	if code == MOUSE_RIGHT then
		sendPing()
	elseif code == MOUSE_LEFT then
		local cx, cy = gui.MousePos()
		if cx < L.x or cx > L.x + L.w or cy < L.y or cy > L.y + L.h then return end
		sendPing( L.mins.x + ( cx - L.x ) / L.w * ( L.maxs.x - L.mins.x ),
			L.maxs.y - ( cy - L.y ) / L.h * ( L.maxs.y - L.mins.y ) )
	end
end )

local function mateInfo( sid, lp )
	local pl = player.GetBySteamID64( sid )
	if IsValid( pl ) then
		if pl == lp or not pl:Alive() or pl:Team() ~= 2 then return nil end
		if not pl:IsDormant() then
			local p = pl:GetPos()
			return p.x, p.y, pl:EyeAngles().y, pl:Nick()
		end
	end
	local d = matePos[sid]
	if d and CurTime() - d.t < 1.5 then
		return d.x, d.y, d.yaw, IsValid( pl ) and pl:Nick() or ""
	end
end

------------------------------------------------------------------------
// Drawing
------------------------------------------------------------------------

// convex polygon, drawn with both windings so it shows whatever the point order
local function polyBoth( poly )
	draw.NoTexture()
	surface.DrawPoly( poly )
	local rev = {}
	for i = #poly, 1, -1 do rev[#rev + 1] = poly[i] end
	surface.DrawPoly( rev )
end

local function arrow( x, y, yaw, size, col )
	local r = math.rad( yaw )
	local dx, dy = math.cos( r ), -math.sin( r ) // world +y is screen up
	local px, py = -dy, dx
	local back = size * 0.6
	surface.SetDrawColor( col )
	polyBoth( {
		{ x = x + dx * size, y = y + dy * size },
		{ x = x - dx * back + px * size * 0.65, y = y - dy * back + py * size * 0.65 },
		{ x = x - dx * back - px * size * 0.65, y = y - dy * back - py * size * 0.65 },
	} )
end

local function circle( x, y, r, col, segs )
	segs = segs or 24
	local poly = {}
	for i = 1, segs do
		local a = ( i / segs ) * math.pi * 2
		poly[i] = { x = x + math.cos( a ) * r, y = y + math.sin( a ) * r }
	end
	surface.SetDrawColor( col )
	polyBoth( poly )
end

local function ring( x, y, r, col, thick )
	local segs = math.Clamp( math.floor( r / 3 ), 48, 256 )
	surface.SetDrawColor( col )
	for t = 0, thick - 1 do
		local rr = r - t
		local lx, ly = x + rr, y
		for i = 1, segs do
			local a = ( i / segs ) * math.pi * 2
			local nx, ny = x + math.cos( a ) * rr, y + math.sin( a ) * rr
			surface.DrawLine( lx, ly, nx, ny )
			lx, ly = nx, ny
		end
	end
end

local function label( str, font, x, y, col, ax, ay )
	draw.SimpleTextOutlined( str, font, x, y, col, ax or TEXT_ALIGN_CENTER, ay or TEXT_ALIGN_TOP, 1, colShadow )
end

// thick segment from (x1, y1) to (x2, y2)
local function segment( x1, y1, x2, y2, thick )
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt( dx * dx + dy * dy )
	if len < 0.5 then return end
	local px, py = -dy / len * thick / 2, dx / len * thick / 2
	polyBoth( {
		{ x = x1 + px, y = y1 + py }, { x = x2 + px, y = y2 + py },
		{ x = x2 - px, y = y2 - py }, { x = x1 - px, y = y1 - py },
	} )
end

local function dashed( x1, y1, x2, y2, col, thick )
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt( dx * dx + dy * dy )
	if len < 1 then return end
	dx, dy = dx / len, dy / len
	local dash, gap = S( 9 ), S( 6 )
	surface.SetDrawColor( col )
	for d = 0, len, dash + gap do
		local e = math.min( d + dash, len )
		segment( x1 + dx * d, y1 + dy * d, x1 + dx * e, y1 + dy * e, thick )
	end
end

local function xMark( x, y, size, col, thick )
	surface.SetDrawColor( col )
	segment( x - size, y - size, x + size, y + size, thick )
	segment( x - size, y + size, x + size, y - size, thick )
end

// supply crate: orange box with a dark border
local function crate( x, y, size )
	surface.SetDrawColor( colShadow )
	surface.DrawRect( x - size - 2, y - size - 2, size * 2 + 4, size * 2 + 4 )
	surface.SetDrawColor( colDrop )
	surface.DrawRect( x - size, y - size, size * 2, size * 2 )
	surface.SetDrawColor( 120, 60, 10, 255 )
	surface.DrawRect( x - size, y - 1, size * 2, 2 )
end

// marker pin: the tip is on the point
local function pin( x, y, size, col )
	local hy = y - size * 2
	surface.SetDrawColor( colShadow )
	polyBoth( { { x = x, y = y + 2 }, { x = x - size - 2, y = hy }, { x = x + size + 2, y = hy } } )
	circle( x, hy, size + 2, colShadow, 16 )
	surface.SetDrawColor( col )
	polyBoth( { { x = x, y = y }, { x = x - size, y = hy }, { x = x + size, y = hy } } )
	circle( x, hy, size, col, 16 )
	circle( x, hy, size * 0.4, colShadow, 10 )
end

// Everything in the rectangle except the zone circle: the circle is written into the
// stencil buffer first (no color), then the tint and stripes are drawn where it is not.
local function drawStorm( x, y, w, h, zx, zy, zr, zc )
	render.ClearStencil()
	render.SetStencilEnable( true )
	render.SetStencilWriteMask( 255 )
	render.SetStencilTestMask( 255 )
	render.SetStencilReferenceValue( 1 )
	render.SetStencilFailOperation( STENCIL_KEEP )
	render.SetStencilZFailOperation( STENCIL_KEEP )

	if zr > 1 then
		render.SetStencilCompareFunction( STENCIL_ALWAYS )
		render.SetStencilPassOperation( STENCIL_REPLACE )
		render.OverrideColorWriteEnable( true, false )
		circle( zx, zy, zr, color_white, math.Clamp( math.floor( zr / 4 ), 48, 256 ) )
		render.OverrideColorWriteEnable( false )
	end

	render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
	render.SetStencilPassOperation( STENCIL_KEEP )

	surface.SetDrawColor( 0, 0, 0, 90 )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( zc.r, zc.g, zc.b, 45 )
	surface.DrawRect( x, y, w, h )

	// diagonal stripes, bottom left to top right
	local gap, thick = S( 26 ), S( 9 )
	surface.SetDrawColor( zc.r, zc.g, zc.b, 110 )
	for sx = x - h, x + w, gap do
		polyBoth( {
			{ x = sx, y = y + h },
			{ x = sx + h, y = y },
			{ x = sx + h + thick, y = y },
			{ x = sx + thick, y = y + h },
		} )
	end

	render.SetStencilEnable( false )
end

------------------------------------------------------------------------
// Map editor (F8, then M): the points of the config seen from above
------------------------------------------------------------------------

local colHover = Color( 255, 255, 255 )

local function drawEditorPoints( ED, toMap, scale, lp )
	local f = Map.edFilter or 0
	local cx, cy = gui.MousePos()
	local hov, hovD = nil, S( 10 ) ^ 2
	for ci, cat in ipairs( LBR.MapCategories ) do
		if f == 0 or f == ci then
			local col = cat.color
			local pts = LBR.GetCategoryList( ED.cfg, cat )
			// zone centers: the start circle of the zone
			if cat.hull == "zone" and ( ED.cfg.zone_radius or 0 ) > 0 then
				for _, p in ipairs( pts ) do
					local px, py = toMap( p.x, p.y )
					ring( px, py, ED.cfg.zone_radius * scale, Color( col.r, col.g, col.b, f == ci and 160 or 70 ), 2 )
				end
			end
			local sz = f == 0 and S( 3 ) or S( 4 )
			for i, p in ipairs( pts ) do
				local px, py = toMap( p.x, p.y )
				surface.SetDrawColor( 0, 0, 0, 230 )
				surface.DrawRect( px - sz - 1, py - sz - 1, sz * 2 + 2, sz * 2 + 2 )
				surface.SetDrawColor( col )
				surface.DrawRect( px - sz, py - sz, sz * 2, sz * 2 )
				local d = ( px - cx ) ^ 2 + ( py - cy ) ^ 2
				if d < hovD then hovD, hov = d, { ci = ci, i = i, x = px, y = py, p = p } end
			end
		end
	end

	// you
	local p = lp:GetPos()
	local px, py = toMap( p.x, p.y )
	arrow( px, py, lp:EyeAngles().y, S( 13 ) + 2, colShadow )
	arrow( px, py, lp:EyeAngles().y, S( 13 ), colMe )

	Map.edHover = hov
	if hov then
		local cat = LBR.MapCategories[hov.ci]
		local sz = S( 6 )
		surface.SetDrawColor( colHover )
		surface.DrawOutlinedRect( hov.x - sz, hov.y - sz, sz * 2, sz * 2, 2 )
		local t = cat.name .. " #" .. hov.i .. "   z " .. math.Round( hov.p.z )
		surface.SetFont( "LBR_UI_Tiny" )
		local tw, th = surface.GetTextSize( t )
		UI.Box( hov.x + S( 10 ), hov.y - th / 2 - S( 3 ), tw + S( 12 ), th + S( 6 ), C.bg )
		label( t, "LBR_UI_Tiny", hov.x + S( 16 ), hov.y - th / 2, cat.color, TEXT_ALIGN_LEFT )
	end
end

// categories with their counts, left of the map (inside it when there is no room);
// a click on a row shows only that category
local function drawEditorLegend( ED, fx, fy, fh )
	local f = Map.edFilter or 0
	local rowH, w = S( 26 ), S( 220 )
	local rows = { { f = 0, name = "All categories", col = C.text } }
	local total = 0
	for ci, cat in ipairs( LBR.MapCategories ) do
		local n = #LBR.GetCategoryList( ED.cfg, cat )
		total = total + n
		rows[#rows + 1] = { f = ci, name = cat.name, col = cat.color, n = n }
	end
	rows[1].n = total
	local h = #rows * rowH + S( 16 )
	local x = fx - w - S( 12 )
	if x < S( 10 ) then x = fx + S( 10 ) end
	local y = fy + math.max( math.floor( ( fh - h ) / 2 ), 0 )
	UI.Box( x, y, w, h, C.bg )
	UI.Box( x, y, w, S( 3 ), C.accent )
	Map.edRows = {}
	local ry = y + S( 10 )
	for _, r in ipairs( rows ) do
		local cur = r.f == f
		UI.Box( x + S( 6 ), ry, w - S( 12 ), rowH - S( 3 ), cur and Color( r.col.r, r.col.g, r.col.b, 50 ) or C.row )
		surface.SetDrawColor( r.col )
		surface.DrawRect( x + S( 14 ), ry + ( rowH - S( 3 ) ) / 2 - S( 4 ), S( 8 ), S( 8 ) )
		label( r.f .. "  " .. r.name, "LBR_UI_Tiny", x + S( 30 ), ry + ( rowH - S( 3 ) ) / 2, cur and colHover or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		label( tostring( r.n ), "LBR_UI_Tiny", x + w - S( 14 ), ry + ( rowH - S( 3 ) ) / 2, r.n > 0 and colHover or C.locked, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		Map.edRows[#Map.edRows + 1] = { f = r.f, x = x, y = ry, w = w, h = rowH }
		ry = ry + rowH
	end
end

// editor map clicks: legend row = filter, left = fly there (to the point under the
// cursor, else above the ground), right = remove the point under the cursor
function Map.EdClick( code )
	local ED = LBR.Editor
	if not ( ED and ED.active and ED.cfg ) then return end
	local cx, cy = gui.MousePos()
	for _, r in ipairs( Map.edRows or {} ) do
		if cx >= r.x and cx <= r.x + r.w and cy >= r.y and cy <= r.y + r.h then
			Map.EdFilter( r.f )
			return
		end
	end
	local L = Map.layout
	if not L then return end
	local hov = Map.edHover
	if code == MOUSE_RIGHT then
		if hov and ED.RemovePoint then ED.RemovePoint( hov.ci, hov.i ) end
		return
	end
	if code ~= MOUSE_LEFT then return end
	if cx < L.x or cx > L.x + L.w or cy < L.y or cy > L.y + L.h then return end
	local target
	if hov then
		target = hov.p + Vector( 0, 0, 80 )
	else
		local x = L.mins.x + ( cx - L.x ) / L.w * ( L.maxs.x - L.mins.x )
		local y = L.maxs.y - ( cy - L.y ) / L.h * ( L.maxs.y - L.mins.y )
		// down from the sky to the first ground (skipping sky / nodraw brushes)
		local z, ground = L.maxs.z, nil
		for _ = 1, 6 do
			local tr = util.TraceLine( { start = Vector( x, y, z ), endpos = Vector( x, y, L.mins.z ), mask = MASK_SOLID_BRUSHONLY } )
			if tr.StartSolid then
				z = z - 256
			elseif not tr.Hit then
				break
			elseif tr.HitSky or tr.HitNoDraw then
				z = tr.HitPos.z - 16
			else
				ground = tr.HitPos.z
				break
			end
		end
		target = Vector( x, y, ground and ground + 120 or L.maxs.z - 200 )
	end
	net.Start( "LBR_Editor_Goto" )
		net.WriteVector( target )
	net.SendToServer()
	Map.Toggle( false )
end

local function drawMap()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	local sw, sh = ScrW(), ScrH()
	local mins, maxs = getBounds()

	surface.SetDrawColor( 0, 0, 0, 170 )
	surface.DrawRect( 0, 0, sw, sh )

	// map rectangle with the map's own proportions, as big as the screen allows
	local spanX = mins and maxs.x - mins.x or 1
	local spanY = mins and maxs.y - mins.y or 1
	// kept clear of the HUD corners (health, weapon, squad, zone info): either between
	// the left and right HUD columns with the full height, or between the top and bottom
	// HUD rows with the full width, whichever gives the bigger map
	local pad, head, foot = S( 26 ), S( 58 ), S( 40 )
	local colW, topH, botH = S( 440 ), S( 200 ), S( 130 )
	local aW, aH = sw - colW * 2 - pad * 2, sh - S( 40 ) - head - foot
	local bW, bH = sw - S( 40 ) - pad * 2, sh - topH - botH - head - foot
	local aScale = math.min( aW / spanX, aH / spanY )
	local bScale = math.min( bW / spanX, bH / spanY )
	local scale = math.max( aScale, bScale )
	local mw, mh = math.floor( spanX * scale ), math.floor( spanY * scale )
	if not mins then mw, mh = math.floor( aH ), math.floor( aH ) end
	mw = math.max( mw, S( 720 ) ) // room for the title, the legend and the help
	local mx = math.floor( ( sw - mw ) / 2 )
	local my
	if aScale >= bScale or not mins then
		my = math.floor( ( sh - mh - head - foot ) / 2 ) + head
	else
		my = topH + math.floor( ( sh - topH - botH - mh - head - foot ) / 2 ) + head
	end

	// frame
	UI.Box( mx - pad, my - S( 58 ), mw + pad * 2, mh + S( 58 ) + S( 40 ), C.bg )
	UI.Box( mx - pad, my - S( 58 ), mw + pad * 2, S( 3 ), C.accent )
	local ED = Map.edMode and LBR.Editor
	if ED and not ED.cfg then ED = nil end
	label( ED and "MAP EDITOR" or "MAP", "LBR_UI_Head", mx, my - S( 50 ), ED and C.accent or C.text, TEXT_ALIGN_LEFT )
	label( string.upper( game.GetMap() ), "LBR_UI_Tiny", mx + mw, my - S( 44 ), C.dim, TEXT_ALIGN_RIGHT )
	label( ED and "WHEEL / 0-8  categories      LEFT CLICK  fly there      RIGHT CLICK  remove point      M  close"
		or "LEFT CLICK  marker      RIGHT CLICK  remove      M  close", "LBR_UI_Tiny", mx + mw, my + mh + S( 14 ), C.dim, TEXT_ALIGN_RIGHT )
	Map.layout = nil
	Map.edHover = nil
	Map.edRows = nil
	if ED then
		local f = Map.edFilter or 0
		local cat = LBR.MapCategories[f]
		local t = cat and ( cat.name .. "  (" .. #LBR.GetCategoryList( ED.cfg, cat ) .. ")" ) or "ALL CATEGORIES"
		label( t, "LBR_UI_Text", mx + mw / 2, my - S( 47 ), cat and cat.color or C.text, TEXT_ALIGN_CENTER )
	elseif LBR.IsZoneActive() then
		local zc = LBR.GetZoneColor and LBR.GetZoneColor() or Color( 0, 255, 180 )
		local wait = LBR.GetZoneStartsIn()
		local t = wait > 0 and ( "ZONE STARTS IN  " .. fmtTime( wait ) )
			or LBR.GetZoneRadius() > 0 and ( "ZONE CLOSING  " .. fmtTime( LBR.GetZoneTimeLeft() ) ) or "ZONE CLOSED"
		label( t, "LBR_UI_Text", mx + mw / 2, my - S( 47 ), Color( zc.r, zc.g, zc.b, 255 ), TEXT_ALIGN_CENTER )
	end

	if not mins then
		label( ED and "Place some points to draw the map" or "No map for this map yet: it has no configured points",
			"LBR_UI_Text", sw / 2, sh / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		return
	end

	if builtSig ~= boundsSig( mins, maxs ) then
		needBuild = true
		label( "Drawing the map...", "LBR_UI_Text", sw / 2, sh / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		return
	end

	// the frame can be wider than the map (very tall maps): center the map in it
	local imgW = math.floor( spanX * scale )
	local ix = mx + math.floor( ( mw - imgW ) / 2 )
	local function toMap( x, y )
		return ix + ( x - mins.x ) / spanX * imgW, my + ( maxs.y - y ) / spanY * mh
	end
	Map.layout = { x = ix, y = my, w = imgW, h = mh, mins = mins, maxs = maxs }

	// you (or the player you are spectating)
	local me = lp
	if lp:GetObserverMode() ~= OBS_MODE_NONE and IsValid( lp:GetObserverTarget() ) and lp:GetObserverTarget():IsPlayer() then
		me = lp:GetObserverTarget()
	end

	surface.SetDrawColor( 255, 255, 255 )
	surface.SetMaterial( rtMat )
	// the texture is a square around the map area: cut out the map rectangle
	local half = math.max( spanX, spanY ) / 2
	local u0, v0 = 0.5 - spanX / 4 / half, 0.5 - spanY / 4 / half
	surface.DrawTexturedRectUV( ix, my, imgW, mh, u0, v0, 1 - u0, 1 - v0 )

	render.SetScissorRect( ix, my, ix + imgW, my + mh, true )

	// outside the safe zone: darker, tinted with the zone color, diagonal stripes
	if LBR.IsZoneActive() then
		local zp = LBR.GetZonePos()
		local zx, zy = toMap( zp.x, zp.y )
		drawStorm( ix, my, imgW, mh, zx, zy, LBR.GetZoneRadius() * scale,
			LBR.GetZoneColor and LBR.GetZoneColor() or Color( 0, 255, 180 ) )
	end

	// grid: square cells, GRID of them on the long side
	local cols = math.Clamp( math.Round( GRID * spanX / math.max( spanX, spanY ) ), 1, GRID )
	local rows = math.Clamp( math.Round( GRID * spanY / math.max( spanX, spanY ) ), 1, GRID )
	surface.SetDrawColor( colGrid )
	for i = 1, cols - 1 do surface.DrawRect( ix + math.floor( imgW * i / cols ), my, 1, mh ) end
	for i = 1, rows - 1 do surface.DrawRect( ix, my + math.floor( mh * i / rows ), imgW, 1 ) end

	if ED then
		drawEditorPoints( ED, toMap, scale, lp )
		render.SetScissorRect( 0, 0, 0, 0, false )
		drawEditorLegend( ED, mx - pad, my - S( 58 ), mh + S( 98 ) )
		return
	end

	// zone
	if LBR.IsZoneActive() then
		local zp = LBR.GetZonePos()
		local zx, zy = toMap( zp.x, zp.y )
		local zr = LBR.GetZoneRadius() * scale
		local zc = LBR.GetZoneColor and LBR.GetZoneColor() or Color( 0, 255, 180 )
		if zr > 1 then
			ring( zx, zy, zr, Color( zc.r, zc.g, zc.b, 255 ), S( 3 ) )
		end
		circle( zx, zy, S( 4 ), Color( zc.r, zc.g, zc.b, 255 ), 12 )

		// outside the zone: dashed line to the nearest point of its edge
		local zr = LBR.GetZoneRadius()
		if me:Alive() and zr > 0 then
			local p = me:GetPos()
			local dx, dy = p.x - zp.x, p.y - zp.y
			local d = math.sqrt( dx * dx + dy * dy )
			if d > zr then
				local ex, ey = toMap( zp.x + dx / d * zr, zp.y + dy / d * zr )
				local px, py = toMap( p.x, p.y )
				dashed( px, py, ex, ey, colShadow, S( 4 ) + 2 )
				dashed( px, py, ex, ey, Color( 255, 255, 255, 230 ), S( 4 ) )
				circle( ex, ey, S( 5 ), Color( 255, 255, 255, 230 ), 12 )
			end
		end
	end

	local pulse = 0.5 + math.sin( CurTime() * 4 ) * 0.5

	// nuke target
	if CurTime() < GetGlobalFloat( "LBR_NukeUntil", 0 ) then
		local np = GetGlobalVector( "LBR_NukePos", vector_origin )
		local nx, ny = toMap( np.x, np.y )
		local nr = GetGlobalFloat( "LBR_NukeRadius", 3500 ) * scale
		circle( nx, ny, nr, Color( colNuke.r, colNuke.g, colNuke.b, 40 + pulse * 50 ), 48 )
		ring( nx, ny, nr, colNuke, 2 )
		xMark( nx, ny, S( 7 ), colNuke, S( 3 ) )
		label( "NUKE", "LBR_UI_Tiny", nx, ny + S( 10 ), colNuke )
	end

	// supply drops
	for _, d in ipairs( drops ) do
		local px, py = toMap( d.x, d.y )
		circle( px, py, S( 10 ) + pulse * S( 8 ), Color( colDrop.r, colDrop.g, colDrop.b, 70 * ( 1 - pulse ) ), 20 )
		crate( px, py, S( 6 ) )
	end

	// where teammates fell
	for sid, d in pairs( deaths ) do
		if inSquad( sid ) and not mateInfo( sid, lp ) then
			local px, py = toMap( d.x, d.y )
			xMark( px, py, S( 6 ), colShadow, S( 4 ) + 2 )
			xMark( px, py, S( 6 ), colDead, S( 4 ) )
		end
	end

	// squad markers
	for _, pg in ipairs( Map.GetPings() ) do
		local px, py = toMap( pg.pos.x, pg.pos.y )
		pin( px, py, S( 8 ), pg.col )
		if not pg.mine then label( string.sub( pg.nick, 1, 16 ), "LBR_UI_Tiny", px, py + S( 3 ), pg.col ) end
	end

	// squad
	for _, sid in ipairs( TEAMERSTAB or {} ) do
		local x, y, yaw, nick = mateInfo( sid, lp )
		if x then
			local px, py = toMap( x, y )
			arrow( px, py, yaw, S( 10 ) + 2, colShadow )
			arrow( px, py, yaw, S( 10 ), colMate )
			label( string.sub( nick, 1, 16 ), "LBR_UI_Tiny", px, py + S( 10 ), colMate )
		end
	end

	// you
	if me:Alive() then
		local p = me:GetPos()
		local px, py = toMap( p.x, p.y )
		circle( px, py, S( 14 ) + pulse * S( 6 ), Color( 255, 255, 255, 40 * ( 1 - pulse ) + 15 ), 24 )
		arrow( px, py, me:EyeAngles().y, S( 13 ) + 2, colShadow )
		arrow( px, py, me:EyeAngles().y, S( 13 ), colMe )
	end

	render.SetScissorRect( 0, 0, 0, 0, false )

	// grid labels
	for i = 1, cols do
		label( LETTERS[i], "LBR_UI_Tiny", ix + ( i - 0.5 ) * imgW / cols, my - S( 14 ), C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	for i = 1, rows do
		label( tostring( i ), "LBR_UI_Tiny", ix - S( 13 ), my + ( i - 0.5 ) * mh / rows, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	// legend
	local ly = my + mh + S( 14 )
	arrow( mx + S( 8 ), ly + S( 7 ), 90, S( 8 ), colMe )
	label( "You", "LBR_UI_Tiny", mx + S( 20 ), ly, C.text, TEXT_ALIGN_LEFT )
	arrow( mx + S( 70 ), ly + S( 7 ), 90, S( 8 ), colMate )
	label( "Squad", "LBR_UI_Tiny", mx + S( 82 ), ly, C.text, TEXT_ALIGN_LEFT )
	local zc = LBR.GetZoneColor and LBR.GetZoneColor() or Color( 0, 255, 180 )
	ring( mx + S( 148 ), ly + S( 7 ), S( 6 ), Color( zc.r, zc.g, zc.b, 255 ), 2 )
	label( "Safe zone", "LBR_UI_Tiny", mx + S( 160 ), ly, C.text, TEXT_ALIGN_LEFT )
	crate( mx + S( 238 ), ly + S( 7 ), S( 5 ) )
	label( "Supply", "LBR_UI_Tiny", mx + S( 250 ), ly, C.text, TEXT_ALIGN_LEFT )
	pin( mx + S( 307 ), ly + S( 13 ), S( 5 ), colPing )
	label( "Marker", "LBR_UI_Tiny", mx + S( 318 ), ly, C.text, TEXT_ALIGN_LEFT )
end

// drawn after everything else (HUD, weapon crosshairs, weapon selection, chat), so
// the map is on top of the whole HUD; not over the pause menu or the console
hook.Add( "DrawOverlay", "LBR_Map", function()
	if not Map.open then return end
	if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return end
	drawMap()
end )

// squad markers on screen (when the map is closed): pin and distance
hook.Add( "HUDPaint", "LBR_MapPings", function()
	if Map.open then return end
	local eye = EyePos()
	for _, pg in ipairs( Map.GetPings() ) do
		local sp = ( pg.pos + Vector( 0, 0, 60 ) ):ToScreen()
		if sp.visible then
			local x = math.Clamp( sp.x, S( 20 ), ScrW() - S( 20 ) )
			local y = math.Clamp( sp.y, S( 40 ), ScrH() - S( 20 ) )
			pin( x, y, S( 7 ), pg.col )
			label( units2m( eye:Distance( pg.pos ) ) .. "m", "LBR_UI_Tiny", x, y + S( 3 ), pg.col )
		end
	end
end )

// no crosshair while the map is open
hook.Add( "HUDShouldDraw", "LBR_MapCrosshair", function( name )
	if Map.open and name == "CHudCrosshair" then return false end
end )
