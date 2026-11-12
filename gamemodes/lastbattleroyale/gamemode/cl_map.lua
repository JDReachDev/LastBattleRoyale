// Map (M, or the MAP button in the TAB menu): the map seen from above with you,
// your squad and the safe zone.
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

local rt, rtMat
local builtSig // map area the texture was rendered for
local needBuild = false

------------------------------------------------------------------------
// Map area
------------------------------------------------------------------------

local function getBounds()
	local mins = GetGlobalVector( "LBR_MapMins", vector_origin )
	local maxs = GetGlobalVector( "LBR_MapMaxs", vector_origin )
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

	local halfX, halfY = ( maxs.x - mins.x ) / 2, ( maxs.y - mins.y ) / 2
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
		// a rectangle squeezed into the square texture, stretched back when drawn
		ortho = { left = -halfX, right = halfX, top = -halfY, bottom = halfY },
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

function Map.Toggle( state )
	if state == nil then state = not Map.open end
	Map.open = state
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
	local maxW, maxH = sw - S( 120 ), sh - S( 160 )
	local scale = math.min( maxW / spanX, maxH / spanY )
	local mw, mh = math.floor( spanX * scale ), math.floor( spanY * scale )
	if not mins then mw, mh = math.floor( maxH ), math.floor( maxH ) end
	mw = math.max( mw, S( 420 ) ) // room for the title and the legend
	local mx, my = math.floor( ( sw - mw ) / 2 ), math.floor( ( sh - mh ) / 2 ) + S( 10 )
	local pad = S( 26 )

	// frame
	UI.Box( mx - pad, my - S( 58 ), mw + pad * 2, mh + S( 58 ) + S( 40 ), C.bg )
	UI.Box( mx - pad, my - S( 58 ), mw + pad * 2, S( 3 ), C.accent )
	label( "MAP", "LBR_UI_Head", mx, my - S( 50 ), C.text, TEXT_ALIGN_LEFT )
	label( string.upper( game.GetMap() ), "LBR_UI_Tiny", mx + mw, my - S( 44 ), C.dim, TEXT_ALIGN_RIGHT )
	label( "M  close", "LBR_UI_Tiny", mx + mw, my + mh + S( 14 ), C.dim, TEXT_ALIGN_RIGHT )

	if not mins then
		label( "No map for this map yet: it has no configured points", "LBR_UI_Text", sw / 2, sh / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
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

	surface.SetDrawColor( 255, 255, 255 )
	surface.SetMaterial( rtMat )
	surface.DrawTexturedRect( ix, my, imgW, mh )

	render.SetScissorRect( ix, my, ix + imgW, my + mh, true )

	// grid: square cells, GRID of them on the long side
	local cols = math.Clamp( math.Round( GRID * spanX / math.max( spanX, spanY ) ), 1, GRID )
	local rows = math.Clamp( math.Round( GRID * spanY / math.max( spanX, spanY ) ), 1, GRID )
	surface.SetDrawColor( colGrid )
	for i = 1, cols - 1 do surface.DrawRect( ix + math.floor( imgW * i / cols ), my, 1, mh ) end
	for i = 1, rows - 1 do surface.DrawRect( ix, my + math.floor( mh * i / rows ), imgW, 1 ) end

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

	// you (or the player you are spectating)
	local me = lp
	if lp:GetObserverMode() ~= OBS_MODE_NONE and IsValid( lp:GetObserverTarget() ) and lp:GetObserverTarget():IsPlayer() then
		me = lp:GetObserverTarget()
	end
	if me:Alive() then
		local p = me:GetPos()
		local px, py = toMap( p.x, p.y )
		local pulse = 0.5 + math.sin( CurTime() * 4 ) * 0.5
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
end

hook.Add( "HUDPaint", "LBR_Map", function()
	if not Map.open then return end
	if LBR.Editor and LBR.Editor.active then return end
	drawMap()
end )
