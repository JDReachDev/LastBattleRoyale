// Events of the gamemode itself, made only with Half-Life 2 effects and sounds
// (no HBOMBS needed):
//   LBR.Nuke( pos )      nuclear strike on a nuke target (lbr_event_nuke): announced,
//                        marked on the map, siren, then the blast after NUKE_DELAY s
//   LBR.Implosion( pos ) implosion at the zone center when the zone closes
//                        (lbr_event_implosion): pulls everyone in, then the blast
// LBR.StopEvents() cancels what is still pending (round restart).

LBR = LBR or {}

local NUKE_DELAY = 20       // seconds from the warning to the blast
local NUKE_RADIUS = 3500    // red area on the map (67 m): inside it you die near the center
local NUKE_LETHAL = 0.6     // part of the radius where the blast always kills
local IMPLOSION_DELAY = 6
local IMPLOSION_RADIUS = 10000

local pending = {}

local function later( id, delay, fn )
	pending[#pending + 1] = id
	timer.Create( id, delay, 1, fn )
end

function LBR.StopEvents()
	for _, id in ipairs( pending ) do timer.Remove( id ) end
	pending = {}
	SetGlobalFloat( "LBR_NukeUntil", 0 )
	BroadcastLua( 'if LBR and LBR.StopSiren then LBR.StopSiren() end' )
end

// played by the clients (LBR.Siren, cl_hud) for len seconds, then stopped: the HBOMBS
// siren the gamemode used when the client had that addon was a looping wav, never ending
function LBR.PlaySiren( len )
	BroadcastLua( 'if LBR and LBR.Siren then LBR.Siren(' .. ( len or 6 ) .. ') end' )
end

// ground under a point placed in the air (the blast happens on the ground): the nuke
// targets of the old configs are high in the sky (the HBOMBS bomb fell from there),
// thousands of units above the ground. Sky and nodraw brushes on the way are skipped.
local function groundOf( pos )
	local start = pos + Vector( 0, 0, 40 )
	for _ = 1, 6 do
		local tr = util.TraceLine( { start = start, endpos = start - Vector( 0, 0, 32768 ), mask = MASK_SOLID_BRUSHONLY } )
		if tr.StartSolid then
			start = start - Vector( 0, 0, 64 )
		elseif not tr.Hit then
			return pos
		elseif tr.HitSky or tr.HitNoDraw then
			start = tr.HitPos - Vector( 0, 0, 16 )
		else
			return tr.HitPos + Vector( 0, 0, 16 )
		end
	end
	return pos
end

// flash and shake for everyone near, the boom for everyone on the map
local function blastFeedback( pos, radius, shake )
	for _, ply in ipairs( player.GetAll() ) do
		local d = ply:GetPos():Distance( pos )
		if d < radius * 3 then
			local a = math.Clamp( 255 * ( 1 - d / ( radius * 3 ) ), 40, 255 )
			ply:ScreenFade( SCREENFADE.IN, Color( 255, 245, 225, a ), 1.5, 0.3 )
		end
	end
	util.ScreenShake( pos, shake, 5, 5, radius * 3 )
	BroadcastLua( 'surface.PlaySound("ambient/explosions/explode_6.wav")' )
	sound.Play( "ambient/explosions/explode_9.wav", pos, 140, 70, 1 )
end

local function bigExplosion( pos, spread )
	local fx = EffectData()
	fx:SetOrigin( pos )
	fx:SetScale( 4 )
	fx:SetMagnitude( 4 )
	util.Effect( "HelicopterMegaBomb", fx, true, true )
	for i = 1, 10 do
		local a = math.rad( i * 36 )
		local p = groundOf( pos + Vector( math.cos( a ) * spread, math.sin( a ) * spread, 200 ) )
		timer.Simple( i * 0.06, function()
			local e = EffectData()
			e:SetOrigin( p )
			util.Effect( i % 2 == 0 and "HelicopterMegaBomb" or "Explosion", e, true, true )
		end )
	end
end

local function hurt( ply, pos, amount )
	local dmg = DamageInfo()
	dmg:SetDamage( amount )
	dmg:SetDamageType( DMG_BLAST )
	dmg:SetAttacker( game.GetWorld() )
	dmg:SetInflictor( game.GetWorld() )
	dmg:SetDamagePosition( pos )
	dmg:SetDamageForce( ( ply:GetPos() - pos ):GetNormalized() * 20000 )
	ply:TakeDamageInfo( dmg )
end

// under cover from a blast at pos: a roof of the map over the head (not the sky)
// and the map between the blast and the player (eyes and body). A bunker, a
// building or a tunnel saves you; a tree, a car or a crate does not (map only)
local function sheltered( ply, pos )
	local eye, mid = ply:EyePos(), ply:WorldSpaceCenter()
	local up = util.TraceLine( { start = eye, endpos = eye + Vector( 0, 0, 2000 ), mask = MASK_SOLID_BRUSHONLY } )
	if not up.Hit or up.HitSky then return false end
	local from = pos + Vector( 0, 0, 64 )
	for _, p in ipairs( { eye, mid } ) do
		if not util.TraceLine( { start = from, endpos = p, mask = MASK_SOLID_BRUSHONLY } ).Hit then return false end
	end
	return true
end
LBR.BlastSheltered = sheltered

function LBR.Nuke( target )
	local pos = groundOf( target )
	LBR.Chat( nil, "Nuclear airstrike inbound! Leave the red area on the map (M) or get under cover (bunker, building)" )
	LBR.Notify( nil, "Nuclear airstrike in " .. NUKE_DELAY .. " s! Leave the red area (M) or get under cover", "bad", 6 )
	SetGlobalVector( "LBR_NukePos", pos )
	SetGlobalFloat( "LBR_NukeRadius", NUKE_RADIUS )
	SetGlobalFloat( "LBR_NukeUntil", CurTime() + NUKE_DELAY + 15 )
	for i = 0, NUKE_DELAY - 5, 5 do
		later( "LBR_NukeSiren" .. i, math.max( i, 0.01 ), function() LBR.PlaySiren( 5 ) end )
	end
	later( "LBR_NukeBlast", NUKE_DELAY, function()
		bigExplosion( pos, 500 )
		blastFeedback( pos, NUKE_RADIUS, 25 )
		// in the open: inside the lethal part you die, further out less and less.
		// Under cover (bunker, building, tunnel: sheltered above) only a knock
		for _, ply in ipairs( player.GetAll() ) do
			if ply:Alive() then
				local d = ply:GetPos():Distance( pos )
				local lethal = NUKE_RADIUS * NUKE_LETHAL
				if d <= NUKE_RADIUS and sheltered( ply, pos ) then
					hurt( ply, pos, d <= lethal and 25 or 10 )
				elseif d <= lethal then
					hurt( ply, pos, 1000 )
				elseif d <= NUKE_RADIUS then
					hurt( ply, pos, Lerp( ( d - lethal ) / ( NUKE_RADIUS - lethal ), 150, 30 ) )
				end
			end
		end
		// vehicles, props: the engine blast (it stops at the walls of the map, so it
		// does not reach the players under cover either)
		util.BlastDamage( game.GetWorld(), game.GetWorld(), pos, NUKE_RADIUS * NUKE_LETHAL, 400 )
	end )
end

function LBR.Implosion( center )
	local pos = groundOf( center )
	LBR.Chat( nil, "The zone collapses: implosion!" )
	LBR.Notify( nil, "Implosion!", "bad", 5 )
	BroadcastLua( 'surface.PlaySound("weapons/physcannon/superphys_launch4.wav")' )
	util.ScreenShake( pos, 8, 3, IMPLOSION_DELAY, IMPLOSION_RADIUS )
	// everyone is pulled to the center
	local steps = IMPLOSION_DELAY * 10
	pending[#pending + 1] = "LBR_ImplosionPull"
	timer.Create( "LBR_ImplosionPull", 0.1, steps, function()
		for _, ply in ipairs( player.GetAll() ) do
			if ply:Alive() and ply:GetPos():Distance( pos ) < IMPLOSION_RADIUS then
				local dir = pos - ply:GetPos()
				dir.z = 0
				ply:SetVelocity( dir:GetNormalized() * 40 + Vector( 0, 0, 6 ) )
			end
		end
	end )
	later( "LBR_ImplosionBlast", IMPLOSION_DELAY, function()
		bigExplosion( pos, 700 )
		blastFeedback( pos, IMPLOSION_RADIUS / 3, 30 )
		for _, ply in ipairs( player.GetAll() ) do
			if ply:Alive() and ply:GetPos():Distance( pos ) <= IMPLOSION_RADIUS then
				hurt( ply, pos, 500 )
			end
		end
	end )
end
