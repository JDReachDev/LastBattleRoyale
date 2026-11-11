// Client performance: vehicles (SCars, WAC helicopters) are heavy to draw and on big
// open maps they were always drawn, even across the whole map. Parked vehicles
// farther than lbr_cull_vehicle_distance are hidden. Moving vehicles are always drawn.

LBR = LBR or {}

local cvVehDist = CreateClientConVar( "lbr_cull_vehicle_distance", "8000", true, false, "Parked vehicles farther than this are not drawn (0 = off)" )

local vehicles = {} // ent -> true
local nextUpdate = 0

local function track( ent )
	if IsValid( ent ) and LBR.IsVehicleClass( ent:GetClass() ) then
		vehicles[ent] = true
	end
end

hook.Add( "OnEntityCreated", "LBR_PerfTrackVehicles", function( ent )
	timer.Simple( 0, function() track( ent ) end )
end )
hook.Add( "InitPostEntity", "LBR_PerfTrackVehiclesInit", function()
	for _, ent in ipairs( ents.GetAll() ) do track( ent ) end
end )
for _, ent in ipairs( ents.GetAll() ) do track( ent ) end // lua refresh

local function setCulled( ent, culled )
	if culled then
		// never touch entities the addon hides on purpose
		if ent.LBR_Culled or ent:GetNoDraw() then return end
		ent.LBR_Culled = true
		ent:SetNoDraw( true )
	elseif ent.LBR_Culled then
		ent.LBR_Culled = nil
		ent:SetNoDraw( false )
	end
end

hook.Add( "Think", "LBR_PerfCullVehicles", function()
	if CurTime() < nextUpdate then return end
	nextUpdate = CurTime() + 0.5

	local maxd = cvVehDist:GetFloat()
	local editing = LBR.Editor and LBR.Editor.active
	local eye = EyePos()
	maxd = maxd * maxd

	for ent in pairs( vehicles ) do
		if not IsValid( ent ) then
			vehicles[ent] = nil
		elseif maxd <= 0 or editing then
			setCulled( ent, false )
		else
			local far = ent:GetPos():DistToSqr( eye ) > maxd and ent:GetVelocity():LengthSqr() < 2500
			setCulled( ent, far )
		end
	end
end )
