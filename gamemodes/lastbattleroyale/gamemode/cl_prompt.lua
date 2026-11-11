// Interaction prompt: "[E] PICK UP  M4A1" under the crosshair when you look at
// something you can use (ground weapons, armor, ghillie, attachments, ammo,
// medkits, supply drops, vehicles).

LBR = LBR or {}

local scale = 1
local function S( v ) return math.Round( v * scale ) end
hook.Add( "OnScreenSizeChanged", "LBR_PromptScale", function() scale = math.Clamp( ScrH() / 1080, 0.6, 2 ) end )
scale = math.Clamp( ScrH() / 1080, 0.6, 2 )

local USE_RANGE = 90        // max distance from the eyes to the entity surface
local CONE = 0.93           // how close to the crosshair (dot product) for small loot
local SCAN_INTERVAL = 0.08

local colGold = Color( 255, 210, 70 )
local colText = Color( 236, 239, 245 )
local colBg = Color( 10, 14, 24, 190 )

// Entities that do something on E but are not found by the generic rules
local SPECIAL = {
	ent_supplydrop_fix = { "OPEN", "Supply Drop" },
}

local function niceName( ent )
	local name = ent.PrintName
	if ( not name or name == "" ) and ent:IsWeapon() then
		local t = weapons.Get( ent:GetClass() )
		name = t and t.PrintName
	end
	if not name or name == "" then name = ent:GetClass() end
	if string.sub( name, 1, 1 ) == "#" then name = language.GetPhrase( string.sub( name, 2 ) ) end
	return name
end

// returns action, name or nil
local function describe( lp, ent )
	if not IsValid( ent ) or ent == lp or ent:IsPlayer() then return end
	local class = ent:GetClass()

	if SPECIAL[class] then return SPECIAL[class][1], SPECIAL[class][2] end

	if ent:IsWeapon() then
		if IsValid( ent:GetOwner() ) then return end
		if lp:HasWeapon( class ) then return "TAKE AMMO", niceName( ent ) end
		return "PICK UP", niceName( ent )
	end

	if ent:IsVehicle() or LBR.IsVehicleClass( class ) then
		if ent:IsVehicle() and IsValid( ent:GetDriver() ) then return end
		return "ENTER", niceName( ent )
	end

	if LBR.IsLootClass( class ) then
		return "USE", niceName( ent )
	end
end

local function canPrompt( lp )
	if not lp:Alive() or lp:Team() ~= TEAM_CONT then return false end
	if lp:InVehicle() or IsValid( lp:GetVehicle() ) then return false end
	if LBR.Editor and LBR.Editor.active then return false end
	if IsValid( lp:GetObserverTarget() ) then return false end
	return true
end

local target, action, label
local nextScan = 0

local function scan( lp )
	target, action, label = nil, nil, nil
	local eye = lp:EyePos()
	local aim = lp:GetAimVector()

	// 1) what the crosshair is on (vehicles, crates, props)
	local tr = util.TraceLine( {
		start = eye,
		endpos = eye + aim * USE_RANGE,
		filter = lp,
		mask = MASK_SHOT
	} )
	if IsValid( tr.Entity ) then
		local a, n = describe( lp, tr.Entity )
		if a then target, action, label = tr.Entity, a, n return end
	end

	// 2) small loot near the crosshair (weapons on the ground are hard to aim at)
	local best, bestDot
	for _, ent in ipairs( ents.FindInSphere( eye, USE_RANGE + 40 ) ) do
		if ent ~= lp and not ent:IsPlayer() and not ent:IsVehicle() then
			local center = ent:WorldSpaceCenter()
			local dir = center - eye
			local dist = dir:Length()
			if dist > 0 then
				local dot = aim:Dot( dir / dist )
				local near = ent:NearestPoint( eye ):Distance( eye )
				if dot > CONE and near <= USE_RANGE and ( not bestDot or dot > bestDot ) then
					local a = describe( lp, ent )
					if a then
						// not behind a wall
						local vis = util.TraceLine( { start = eye, endpos = center, filter = { lp, ent }, mask = MASK_SOLID_BRUSHONLY } )
						if not vis.Hit then best, bestDot = ent, dot end
					end
				end
			end
		end
	end
	if best then
		target = best
		action, label = describe( lp, best )
	end
end

local alpha = 0
local shownAction, shownLabel

hook.Add( "HUDPaint", "LBR_InteractPrompt", function()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end

	if not canPrompt( lp ) then
		target = nil
	elseif CurTime() >= nextScan then
		nextScan = CurTime() + SCAN_INTERVAL
		scan( lp )
	end

	local show = IsValid( target ) and action ~= nil
	alpha = math.Approach( alpha, show and 1 or 0, FrameTime() * 8 )
	if show then shownAction, shownLabel = action, label end
	if alpha <= 0 or not shownAction then return end

	local key = string.upper( input.LookupBinding( "+use" ) or "E" )
	local act = shownAction
	local name = shownLabel or ""
	if #name > 32 then name = string.sub( name, 1, 30 ) .. "..." end

	surface.SetFont( "LBR_HUD_Small" )
	local aw = surface.GetTextSize( act )
	local nw = surface.GetTextSize( name )
	surface.SetFont( "LBR_HUD_Med" )
	local kw, kh = surface.GetTextSize( key )

	local pad = S( 10 )
	local boxW = math.max( kw + S( 14 ), S( 30 ) )
	local h = math.max( kh + S( 8 ), S( 34 ) )
	local w = boxW + pad + aw + ( name ~= "" and ( S( 8 ) + nw ) or 0 ) + pad * 1.5
	local x = math.floor( ScrW() / 2 - w / 2 )
	local y = math.floor( ScrH() / 2 + S( 70 ) )

	local a = alpha * 255
	surface.SetDrawColor( colBg.r, colBg.g, colBg.b, colBg.a * alpha )
	surface.DrawRect( x, y, w, h )

	// key box
	local kx, ky = x + S( 4 ), y + S( 4 )
	surface.SetDrawColor( colGold.r, colGold.g, colGold.b, a )
	surface.DrawRect( kx, ky, boxW, h - S( 8 ) )
	draw.SimpleText( key, "LBR_HUD_Med", kx + boxW / 2, y + h / 2, Color( 20, 20, 20, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

	local tx = kx + boxW + pad
	draw.SimpleText( act, "LBR_HUD_Small", tx, y + h / 2, Color( colText.r, colText.g, colText.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	if name ~= "" then
		draw.SimpleText( name, "LBR_HUD_Small", tx + aw + S( 8 ), y + h / 2, Color( colGold.r, colGold.g, colGold.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end
end )
