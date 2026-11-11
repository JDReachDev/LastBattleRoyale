// Server performance: loot far from a player is not sent to that player.
//
// On big open maps (gm_fork, gm_valley...) the engine visibility (PVS) sees almost
// the whole map, so every loot item of the round was networked to every client and
// drawn every frame, with its dynamic shadow. Now:
// - unowned loot farther than lbr_cull_loot_distance from a player is not transmitted
//   to him (it goes dormant on his client: no drawing, no updates);
// - loot lying on the ground has no dynamic shadow.
// As soon as a weapon is picked up it is sent to everyone again.

LBR = LBR or {}

local cvLootDist = CreateConVar( "lbr_cull_loot_distance", "4000", FCVAR_ARCHIVE, "Loot farther than this from a player is not sent to him (0 = off)" )

local loot = {}  // ent -> true
local hiddenFor = {} // ent -> { [ply] = true }

local function track( ent )
	if not IsValid( ent ) or ent:IsPlayer() then return end
	if not LBR.IsLootClass( ent:GetClass() ) then return end
	loot[ent] = true
end

hook.Add( "OnEntityCreated", "LBR_PerfTrackLoot", function( ent )
	timer.Simple( 0, function() track( ent ) end )
end )
for _, ent in ipairs( ents.GetAll() ) do track( ent ) end // lua refresh

local function showToAll( ent )
	local hidden = hiddenFor[ent]
	if not hidden then return end
	for ply in pairs( hidden ) do
		if IsValid( ply ) then ent:SetPreventTransmit( ply, false ) end
	end
	hiddenFor[ent] = nil
end

local function setShadow( ent, on )
	if ent.LBR_NoShadow == not on then return end
	ent.LBR_NoShadow = not on
	ent:DrawShadow( on )
end

// a picked up weapon must be visible to everyone right away
hook.Add( "WeaponEquip", "LBR_PerfUncull", function( wep )
	if loot[wep] then
		showToAll( wep )
		setShadow( wep, true )
	end
end )

hook.Add( "EntityRemoved", "LBR_PerfForget", function( ent )
	loot[ent] = nil
	hiddenFor[ent] = nil
end )

local function viewPos( ply )
	if ply:GetObserverMode() ~= OBS_MODE_NONE then
		local t = ply:GetObserverTarget()
		if IsValid( t ) then return t:GetPos() end
	end
	return ply:GetPos()
end

local function update()
	local maxd = cvLootDist:GetFloat()
	local players = player.GetHumans()
	local positions = {}
	for i = 1, #players do positions[i] = viewPos( players[i] ) end
	maxd = maxd * maxd

	for ent in pairs( loot ) do
		if not IsValid( ent ) then
			loot[ent] = nil
			hiddenFor[ent] = nil
		elseif IsValid( ent:GetOwner() ) or IsValid( ent:GetParent() ) or maxd <= 0 then
			// held, parented or culling disabled: always sent
			showToAll( ent )
			if IsValid( ent:GetOwner() ) then setShadow( ent, true ) end
		else
			setShadow( ent, false )
			local pos = ent:GetPos()
			local hidden = hiddenFor[ent]
			for i = 1, #players do
				local ply = players[i]
				local far = pos:DistToSqr( positions[i] ) > maxd and not ply.LBR_Editing
				local isHidden = hidden and hidden[ply] or false
				if far ~= isHidden then
					ent:SetPreventTransmit( ply, far )
					if far then
						hidden = hidden or {}
						hiddenFor[ent] = hidden
						hidden[ply] = true
					else
						hidden[ply] = nil
					end
				end
			end
		end
	end
end

timer.Create( "LBR_PerfCull", 0.5, 0, update )

hook.Add( "PlayerDisconnected", "LBR_PerfCleanup", function( ply )
	for _, hidden in pairs( hiddenFor ) do hidden[ply] = nil end
end )

// debug: how much is being culled
concommand.Add( "lbr_cull_stats", function( ply )
	if IsValid( ply ) and not ply:IsAdmin() then return end
	local n, h = 0, 0
	for ent in pairs( loot ) do
		if IsValid( ent ) then
			n = n + 1
			if hiddenFor[ent] then for _ in pairs( hiddenFor[ent] ) do h = h + 1 end end
		end
	end
	local msg = "[LBR] loot tracked: " .. n .. ", hidden (item x player): " .. h
	if IsValid( ply ) then ply:PrintMessage( HUD_PRINTCONSOLE, msg ) else print( msg ) end
end )
