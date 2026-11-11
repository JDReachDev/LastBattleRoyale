// Client: safe zone rendering + loot outlines (halos).

LBR = LBR or {}

local cvQuality = GetConVar( "lst_zonequality" )
local cvOutline = GetConVar( "lst_objoutline" )
local cvHaloDist = CreateClientConVar( "lbr_outline_distance", "1500", true, false, "Max distance of loot outlines (lower = more FPS)" )

------------------------------------------------------------------------
// Zone
------------------------------------------------------------------------

local zoneMat = Material( "oc1y8p0.jpg" )
local colSafe = Color( 0, 255, 180, 125 )
local colEnd = Color( 255, 0, 0, 50 )
local zoneCol = Color( 0, 255, 180, 125 )
local segments = { [1] = 15, [2] = 25, [3] = 30 }

local function updateZoneColor()
	local t = LBR.GetZoneDanger()
	zoneCol.r = Lerp( t, colSafe.r, colEnd.r )
	zoneCol.g = Lerp( t, colSafe.g, colEnd.g )
	zoneCol.b = Lerp( t, colSafe.b, colEnd.b )
	zoneCol.a = Lerp( t, colSafe.a, colEnd.a )
	return zoneCol
end
LBR.GetZoneColor = updateZoneColor

hook.Add( "PostDrawTranslucentRenderables", "LBR_DrawZone", function( depth, skybox )
	// the hook also runs for the skybox and depth passes: drawing there doubled the cost
	if depth or skybox then return end
	if not LBR.IsZoneActive() then return end
	local q = cvQuality:GetInt()
	if q <= 0 then return end
	local radius = LBR.GetZoneRadius()
	if radius <= 0 then return end

	local seg = segments[math.min( q, 3 )]
	local pos = LBR.GetZonePos()
	local col = updateZoneColor()
	if q >= 3 then
		render.SetMaterial( zoneMat )
	else
		render.SetColorMaterial()
	end
	render.DrawSphere( pos, -radius, seg, seg, col ) // inside faces
	render.DrawSphere( pos, radius + 1, seg, seg, col ) // outside faces
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
	if IsValid( ent ) and LBR.IsLootClass( ent:GetClass() ) then
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

hook.Add( "PreDrawHalos", "AddPropHalos", function()
	if cvOutline:GetInt() ~= 1 then return end
	if LBR.Editor and LBR.Editor.active then return end
	if CurTime() > nextScan then
		nextScan = CurTime() + 0.25
		rebuildHalos()
	end
	if #haloEnts > 0 then
		halo.Add( haloEnts, haloColor, 2, 2, 1 )
	end
end )
