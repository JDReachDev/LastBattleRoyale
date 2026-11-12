// Client: safe zone rendering + loot outlines (halos) and light beams over loot.

LBR = LBR or {}

local cvQuality = GetConVar( "lbr_zone_quality" )
local cvOutline = GetConVar( "lbr_outline" )
local cvHaloDist = CreateClientConVar( "lbr_outline_distance", "1500", true, false, "Max distance of loot outlines and beams (lower = more FPS)" )
local cvBeam = CreateClientConVar( "lbr_loot_beam", "1", true, false, "Small light beam going up from loot (1/0), same distance as the outline" )

------------------------------------------------------------------------
// Zone
------------------------------------------------------------------------

local cvViewDist = CreateClientConVar( "lbr_zone_view_distance", "9000", true, false, "How far the zone wall is visible" )

local colSafe = Color( 0, 255, 180, 125 )
local colEnd = Color( 255, 0, 0, 50 )
local zoneCol = Color( 0, 255, 180, 125 )

local function updateZoneColor()
	local t = LBR.GetZoneDanger()
	zoneCol.r = Lerp( t, colSafe.r, colEnd.r )
	zoneCol.g = Lerp( t, colSafe.g, colEnd.g )
	zoneCol.b = Lerp( t, colSafe.b, colEnd.b )
	zoneCol.a = Lerp( t, colSafe.a, colEnd.a )
	return zoneCol
end
LBR.GetZoneColor = updateZoneColor

------------------------------------------------------------------------
// Zone wall
// Before: two spheres as big as the zone. The far side went past the map draw
// distance (the white "hole" in the sky), the inside tinted the whole sky and the
// sphere cut through the hills. Now: a simple cylinder, brightest at your eye height
// and fading up and down from there, drawn only near the player (fading out with
// distance). No ground traces: it looks the same on every map.
------------------------------------------------------------------------

// Triangle pattern: big triangles (4 per texture repeat) with thick white lines on
// black, drawn additive so only the lines glow in the zone color. Dense patterns
// blur into a flat color through the mipmaps: keep the cells big.
// The PNG material is used directly: copying its texture into a CreateMaterial one
// (SetTexture) left the white placeholder, so the wall was a flat bright color.
// Vertex color + vertex alpha + additive + no cull are set through $flags.
local matWall = Material( "lastbattleroyale/zone_pattern.png", "noclamp smooth mips" )
if matWall:IsError() then
	matWall = CreateMaterial( "LBR_ZoneWall3", "UnlitGeneric", {
		["$basetexture"] = "color/white", ["$vertexcolor"] = 1, ["$vertexalpha"] = 1,
		["$additive"] = 1, ["$nocull"] = 1,
	} )
else
	// 16 vertexcolor, 32 vertexalpha, 128 additive, 8192 nocull
	matWall:SetInt( "$flags", bit.bor( matWall:GetInt( "$flags" ) or 0, 16, 32, 128, 8192 ) )
	matWall:Recompute()
end
local matFill = CreateMaterial( "LBR_ZoneFill", "UnlitGeneric", {
	["$basetexture"] = "color/white", ["$vertexcolor"] = 1, ["$vertexalpha"] = 1,
	["$translucent"] = 1, ["$nocull"] = 1,
} )
local matGlow = CreateMaterial( "LBR_ZoneGlow", "UnlitGeneric", {
	["$basetexture"] = "color/white", ["$vertexcolor"] = 1, ["$vertexalpha"] = 1,
	["$additive"] = 1, ["$nocull"] = 1,
} )

local WALL_UP = 2000       // fades to nothing this far above your eyes
local WALL_DOWN = 1400     // and this far below them
local GLOW = 160           // half height of the bright band at your eyes
local TEX_SCALE = 1400     // world units per texture repeat
local segmentsByQuality = { [1] = 40, [2] = 64, [3] = 96 }

// wall rows: height from your eyes, alpha (0..1). Strongest at your height,
// fading up and down
local rows = {
	{ -WALL_DOWN, 0 },
	{ -WALL_DOWN * 0.35, 0.35 },
	{ 0, 1 },
	{ WALL_UP * 0.3, 0.35 },
	{ WALL_UP, 0 },
}

local cols = {} // reused every frame

local function buildColumns( center, radius, eye, viewDist, segs )
	// power of two segment count for the whole circle
	local segLen = ( viewDist * 2 ) / segs
	local n = 32
	while n < 8192 and ( 2 * math.pi * radius ) / n > segLen do n = n * 2 end
	local step = 2 * math.pi / n

	local first, last
	if radius * 2 <= viewDist or n <= segs then
		first, last = 0, n
	else
		local span = math.min( math.pi, viewDist / radius )
		local ang = math.atan2( eye.y - center.y, eye.x - center.x )
		first = math.floor( ( ang - span ) / step )
		last = math.ceil( ( ang + span ) / step )
	end

	local fadeStart = viewDist * 0.5
	local count = 0
	for i = first, last do
		local a = i * step
		local x = center.x + math.cos( a ) * radius
		local y = center.y + math.sin( a ) * radius
		local dx, dy = x - eye.x, y - eye.y
		local d = math.sqrt( dx * dx + dy * dy )
		count = count + 1
		local c = cols[count] or {}
		cols[count] = c
		c.x, c.y = x, y
		c.u = i * step * radius / TEX_SCALE
		c.fade = 1 - math.Clamp( ( d - fadeStart ) / ( viewDist - fadeStart ), 0, 1 )
	end
	return count
end

local function vert( x, y, z, u, v, col, a )
	mesh.Position( Vector( x, y, z ) )
	mesh.TexCoord( 0, u, v )
	mesh.Color( col.r, col.g, col.b, a )
	mesh.AdvanceVertex()
end

local function drawWall( count, col, alphaMul, scroll, eyeZ )
	local quads = 0
	for i = 1, count - 1 do
		if cols[i].fade > 0 or cols[i + 1].fade > 0 then quads = quads + #rows - 1 end
	end
	if quads == 0 then return end
	mesh.Begin( MATERIAL_QUADS, quads )
	for i = 1, count - 1 do
		local c1, c2 = cols[i], cols[i + 1]
		if c1.fade > 0 or c2.fade > 0 then
			for r = 1, #rows - 1 do
				local h1, a1 = rows[r][1], rows[r][2]
				local h2, a2 = rows[r + 1][1], rows[r + 1][2]
				vert( c1.x, c1.y, eyeZ + h1, c1.u, ( eyeZ + h1 ) / TEX_SCALE + scroll, col, a1 * c1.fade * alphaMul )
				vert( c1.x, c1.y, eyeZ + h2, c1.u, ( eyeZ + h2 ) / TEX_SCALE + scroll, col, a2 * c1.fade * alphaMul )
				vert( c2.x, c2.y, eyeZ + h2, c2.u, ( eyeZ + h2 ) / TEX_SCALE + scroll, col, a2 * c2.fade * alphaMul )
				vert( c2.x, c2.y, eyeZ + h1, c2.u, ( eyeZ + h1 ) / TEX_SCALE + scroll, col, a1 * c2.fade * alphaMul )
			end
		end
	end
	mesh.End()
end

// bright band at your eye height, fading up and down
local function drawEyeGlow( count, col, alphaMul, eyeZ )
	local pulse = 0.75 + math.sin( CurTime() * 3 ) * 0.25
	mesh.Begin( MATERIAL_QUADS, ( count - 1 ) * 2 )
	for i = 1, count - 1 do
		local c1, c2 = cols[i], cols[i + 1]
		local a1, a2 = 255 * c1.fade * alphaMul * pulse, 255 * c2.fade * alphaMul * pulse
		vert( c1.x, c1.y, eyeZ - GLOW, 0, 0, col, 0 )
		vert( c1.x, c1.y, eyeZ, 0, 0, col, a1 )
		vert( c2.x, c2.y, eyeZ, 0, 0, col, a2 )
		vert( c2.x, c2.y, eyeZ - GLOW, 0, 0, col, 0 )
		vert( c1.x, c1.y, eyeZ, 0, 0, col, a1 )
		vert( c1.x, c1.y, eyeZ + GLOW, 0, 0, col, 0 )
		vert( c2.x, c2.y, eyeZ + GLOW, 0, 0, col, 0 )
		vert( c2.x, c2.y, eyeZ, 0, 0, col, a2 )
	end
	mesh.End()
end

hook.Add( "PostDrawTranslucentRenderables", "LBR_DrawZone", function( depth, skybox )
	// the hook also runs for the skybox and depth passes: drawing there doubled the cost
	if depth or skybox or LBR.MapRendering then return end
	if not LBR.IsZoneActive() then return end
	local q = math.min( cvQuality:GetInt(), 3 )
	if q <= 0 then return end
	local radius = LBR.GetZoneRadius()
	if radius <= 0 then return end

	local eye = EyePos()
	local viewDist = math.max( cvViewDist:GetFloat(), 1000 )
	local count = buildColumns( LBR.GetZonePos(), radius, eye, viewDist, segmentsByQuality[q] )
	if count < 2 then return end

	local col = updateZoneColor()
	// light tint + glowing triangle lines (the old values made a solid wall)
	render.SetMaterial( matFill )
	drawWall( count, col, 22, 0, eye.z )
	if q >= 2 then
		render.SetMaterial( matWall )
		drawWall( count, col, 160, CurTime() * 0.03, eye.z )
	end
	render.SetMaterial( matGlow )
	drawEyeGlow( count, col, q >= 3 and 0.8 or 0.6, eye.z )
end )

------------------------------------------------------------------------
// Storm effect while outside the zone: colored fog and washed out colors
------------------------------------------------------------------------

local storm = 0 // 0 = inside, 1 = fully outside (smoothed)

local function viewPos()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return nil end
	if lp:GetObserverMode() ~= OBS_MODE_NONE then
		local t = lp:GetObserverTarget()
		if IsValid( t ) then return t:GetPos() end
	end
	return lp:GetPos()
end

hook.Add( "Think", "LBR_ZoneStorm", function()
	local target = 0
	if LBR.IsZoneActive() and cvQuality:GetInt() > 0 and not ( LBR.Editor and LBR.Editor.active ) then
		local pos = viewPos()
		if pos and not LBR.IsPosInZone( pos ) then target = 1 end
	end
	storm = math.Approach( storm, target, FrameTime() * 1.5 )
end )

local function stormFog( scale )
	if storm <= 0 or LBR.MapRendering then return end
	render.FogMode( MATERIAL_FOG_LINEAR )
	render.FogStart( 0 )
	render.FogEnd( Lerp( storm, 30000, 1800 ) * ( scale or 1 ) )
	render.FogMaxDensity( 0.85 * storm )
	render.FogColor( zoneCol.r * 0.35, zoneCol.g * 0.35, zoneCol.b * 0.35 )
	return true
end

hook.Add( "SetupWorldFog", "LBR_ZoneStorm", function() return stormFog( 1 ) end )
hook.Add( "SetupSkyboxFog", "LBR_ZoneStorm", function( scale ) return stormFog( scale ) end )

local cm = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}
hook.Add( "RenderScreenspaceEffects", "LBR_ZoneStorm", function()
	if storm <= 0 then return end
	cm["$pp_colour_colour"] = 1 - 0.45 * storm
	cm["$pp_colour_contrast"] = 1 - 0.1 * storm
	cm["$pp_colour_brightness"] = -0.04 * storm
	DrawColorModify( cm )
end )

// zone damage: the default red damage flash mixed with the zone fog looked
// purple. Outside the zone the flash is drawn on the screen edges in the zone color.
hook.Add( "HUDShouldDraw", "LBR_ZoneHurt", function( name )
	if name == "CHudDamageIndicator" and storm > 0.3 then return false end
end )

local matGradL = Material( "gui/gradient" )
local matGradU = Material( "gui/gradient_up" )
local matGradD = Material( "gui/gradient_down" )
local lastLife, hurtFlash = 0, 0
hook.Add( "HUDPaint", "LBR_ZoneHurt", function()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	local life = lp:Alive() and ( lp:Health() + lp:Armor() ) or 0
	if life < lastLife and storm > 0.3 then hurtFlash = 1 end
	lastLife = life
	if hurtFlash <= 0 then return end
	hurtFlash = math.max( hurtFlash - FrameTime() * 2.5, 0 )

	local w, h = ScrW(), ScrH()
	local size = math.floor( math.min( w, h ) * 0.22 )
	surface.SetDrawColor( zoneCol.r, zoneCol.g, zoneCol.b, 150 * hurtFlash )
	surface.SetMaterial( matGradL )
	surface.DrawTexturedRect( 0, 0, size, h )
	surface.DrawTexturedRectUV( w - size, 0, size, h, 1, 0, 0, 1 )
	surface.SetMaterial( matGradD )
	surface.DrawTexturedRect( 0, 0, w, size )
	surface.SetMaterial( matGradU )
	surface.DrawTexturedRect( 0, h - size, w, size )
end )

------------------------------------------------------------------------
// Loot outlines
// Before: 7 ents.FindByClass("x_*") over every entity of the map and a halo
// on every item of the map, every frame. Now: candidate list kept by
// OnEntityCreated, filtered 4 times per second by distance.
------------------------------------------------------------------------

local candidates = {}
local haloEnts = {}
local nextScan = 0
local haloColor = Color( 50, 250, 180 )

local function track( ent )
	if IsValid( ent ) and ( LBR.IsLootClass( ent:GetClass() ) or ent:GetClass() == "lbr_ammo_box" ) then
		candidates[ent] = true
	end
end

hook.Add( "OnEntityCreated", "LBR_TrackLoot", function( ent )
	// the class is not always ready on the same frame
	timer.Simple( 0, function() track( ent ) end )
end )

hook.Add( "InitPostEntity", "LBR_TrackLootInit", function()
	for _, ent in ipairs( ents.GetAll() ) do track( ent ) end
end )
for _, ent in ipairs( ents.GetAll() ) do track( ent ) end // lua refresh

local function rebuildHalos()
	haloEnts = {}
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	local eye = EyePos()
	local maxd = cvHaloDist:GetFloat()
	maxd = maxd * maxd
	for ent in pairs( candidates ) do
		if not IsValid( ent ) then
			candidates[ent] = nil
		elseif not IsValid( ent:GetOwner() ) and not ent:IsDormant() and not ent:GetNoDraw()
			and ent:GetPos():DistToSqr( eye ) < maxd then
			haloEnts[#haloEnts + 1] = ent
		end
	end
end

local function scanLoot()
	if CurTime() > nextScan then
		nextScan = CurTime() + 0.25
		rebuildHalos()
	end
end

hook.Add( "PreDrawHalos", "AddPropHalos", function()
	if cvOutline:GetInt() ~= 1 then return end
	if LBR.MapRendering or ( LBR.Editor and LBR.Editor.active ) then return end
	scanLoot()
	if #haloEnts > 0 then
		halo.Add( haloEnts, haloColor, 2, 2, 1 )
	end
end )

// light beam going up from the loot: soft, fading to the top, and fading out near
// the outline distance (same items as the outline, nothing farther)
local matBeam = Material( "sprites/light_glow02_add" )
local BEAM_HEIGHT, BEAM_WIDTH = 110, 7
hook.Add( "PostDrawTranslucentRenderables", "LBR_LootBeams", function( depth, skybox )
	if depth or skybox then return end
	if cvBeam:GetInt() ~= 1 then return end
	if LBR.MapRendering or ( LBR.Editor and LBR.Editor.active ) then return end
	scanLoot()
	if #haloEnts == 0 then return end
	local eye = EyePos()
	local maxd = math.max( cvHaloDist:GetFloat(), 1 )
	local pulse = 0.85 + math.sin( CurTime() * 2.5 ) * 0.15
	render.SetMaterial( matBeam )
	for _, ent in ipairs( haloEnts ) do
		if IsValid( ent ) and not IsValid( ent:GetOwner() ) then
			local base = ent:WorldSpaceCenter()
			// fade in the last 30% of the distance
			local f = math.Clamp( ( 1 - base:Distance( eye ) / maxd ) / 0.3, 0, 1 ) * pulse
			if f > 0 then
				// additive sprite: the color itself is dimmed (alpha alone may not fade it)
				local function col( k ) k = k * f * 0.7 return Color( haloColor.r * k, haloColor.g * k, haloColor.b * k, 255 * k ) end
				render.StartBeam( 3 )
				render.AddBeam( base, BEAM_WIDTH, 0.5, col( 1 ) )
				render.AddBeam( base + Vector( 0, 0, BEAM_HEIGHT * 0.4 ), BEAM_WIDTH, 0.5, col( 0.6 ) )
				render.AddBeam( base + Vector( 0, 0, BEAM_HEIGHT ), BEAM_WIDTH, 0.5, col( 0 ) )
				render.EndBeam()
			end
		end
	end
end )
