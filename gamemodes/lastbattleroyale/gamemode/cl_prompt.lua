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

local function wepName( w )
	if not IsValid( w ) then return "" end
	local n = w.GetPrintName and w:GetPrintName() or w.PrintName or w:GetClass()
	if isstring( n ) and string.sub( n, 1, 1 ) == "#" then n = language.GetPhrase( string.sub( n, 2 ) ) end
	return n
end

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

// CW 2.0 ammo boxes draw a sign over them in the opaque pass: leaves and other
// see-through things behind it are drawn on top of it. Only the model here, the
// E prompt shows what the sign said.
local function cwAmmoModelOnly( ent )
	if IsValid( ent ) and string.sub( ent:GetClass(), 1, 8 ) == "cw_ammo_" then
		ent.Draw = function( self ) self:DrawModel() end
	end
end
hook.Add( "OnEntityCreated", "LBR_CWAmmoNoSign", function( ent )
	timer.Simple( 0, function() cwAmmoModelOnly( ent ) end ) // the class is not always ready on the same frame
end )
for _, ent in ipairs( ents.GetAll() ) do cwAmmoModelOnly( ent ) end // lua refresh

// returns action, name, name color (nil = gold), progress 0..1 (nil = none) or nil
local function describe( lp, ent )
	if not IsValid( ent ) or ent == lp or ent:IsPlayer() then return end
	local class = ent:GetClass()

	if class == "ent_supplydrop_fix" then
		local p = ent.OpenProgress and ent:OpenProgress()
		if p then
			local who = ent:GetOpener()
			return who == lp and "OPENING" or "BEING OPENED", "Supply Drop", nil, p
		end
		return "OPEN", "Supply Drop"
	end

	if class == "lbr_ammo_box" then
		// one magazine per press (hold E for more), the last part with the last press
		local t = ent:TierTable()
		local room = LBR.ClipRoom( lp, ent:GetTier() )
		if room < 0.0001 then return "FULL", ent:Label() .. "  (you: x" .. LBR.ClipText( LBR.ClipMax( ent:GetTier() ) ) .. ")", t and t.color end
		return "TAKE x" .. LBR.ClipText( math.min( ent:NextTake(), room ) ), ent:Label(), t and t.color
	end

	if ent.LBR_AmmoKit then
		// E opens the menu of the colors
		return "CHOOSE MAGAZINES", niceName( ent ) .. "  (" .. ent:LeftText() .. " green)"
	end

	// CW 2.0 ammo boxes (frag grenades...): their floating sign is off (below), the
	// prompt says what is left
	if string.sub( class, 1, 8 ) == "cw_ammo_" and ent.dt and ent.dt.ammoCharge then
		return "USE", niceName( ent ) .. "  (" .. ent.dt.ammoCharge .. " left)"
	end

	if ent.LBR_AttKit then
		local w = lp:GetActiveWeapon()
		return "USE", niceName( ent ) .. ( IsValid( w ) and ( " - " .. wepName( w ) ) or "" ), LBR.TierColor( w )
	end

	if ent:IsWeapon() then
		if IsValid( ent:GetOwner() ) then return end
		local col = LBR.TierColor( ent )
		if lp:HasWeapon( class ) then return "TAKE AMMO", niceName( ent ), col end
		if LBR.InvGet and not LBR.InvIsHands( ent ) then
			local n = 0
			for _, w in ipairs( lp:GetWeapons() ) do
				if not LBR.InvIsHands( w ) then n = n + 1 end
			end
			if n >= LBR.INV_SLOTS then
				// full: hold E to swap with the weapon in hand (bar under the prompt)
				local act = lp:GetActiveWeapon()
				if not IsValid( act ) or LBR.InvIsHands( act ) then return "FULL: HOLD A WEAPON TO SWAP", niceName( ent ), col end
				return "HOLD: SWAP " .. string.upper( wepName( act ) ) .. " FOR", niceName( ent ), col, nil, true
			end
		end
		return "PICK UP", niceName( ent ), col
	end

	if ent:IsVehicle() or LBR.IsVehicleClass( class ) then
		// seats of SCars / WAC: show the name of the car / helicopter
		local parent = ent:GetParent()
		local main = ( IsValid( parent ) and LBR.IsVehicleClass( parent:GetClass() ) ) and parent or ent
		// GetDriver() exists only on the server: check the players instead
		if ent:IsVehicle() then
			for _, p in ipairs( player.GetAll() ) do
				if p ~= lp and p:GetVehicle() == ent then return end
			end
		end
		return "ENTER", niceName( main )
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
	if LBR.KitMenuOpen and LBR.KitMenuOpen() then return false end // the menu is in the way
	return true
end

local target, action, label, labelCol, canSwap
local nextScan = 0
local swapEnt, swapStart, swapSent

local function scan( lp )
	target, action, label, labelCol, canSwap = nil, nil, nil, nil, nil
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
		local a, n, c, _, sw = describe( lp, tr.Entity )
		if a then target, action, label, labelCol, canSwap = tr.Entity, a, n, c, sw return end
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
		local _
		action, label, labelCol, _, canSwap = describe( lp, best )
	end
end

local alpha = 0
local shownAction, shownLabel, shownCol

hook.Add( "HUDPaint", "LBR_InteractPrompt", function()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end

	if not canPrompt( lp ) then
		target = nil
	elseif CurTime() >= nextScan then
		nextScan = CurTime() + SCAN_INTERVAL
		scan( lp )
	end

	// swap: E held on the same weapon for LBR.SWAP_TIME, then the server does it
	// one swap per press: E must be let go before the next one (the dropped weapon
	// lands in front of you)
	if not lp:KeyDown( IN_USE ) then swapSent = false end
	if canSwap and IsValid( target ) and lp:KeyDown( IN_USE ) and not swapSent then
		if swapEnt ~= target then swapEnt, swapStart = target, CurTime() end
		if CurTime() - swapStart >= LBR.SWAP_TIME then
			swapSent = true
			swapEnt = nil
			net.Start( "LBR_InvSwap" )
			net.WriteEntity( target )
			net.SendToServer()
		end
	else
		swapEnt = nil
	end

	local show = IsValid( target ) and action ~= nil
	alpha = math.Approach( alpha, show and 1 or 0, FrameTime() * 8 )
	if show then shownAction, shownLabel, shownCol = action, label, labelCol end
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
		local nc = shownCol or colGold
		draw.SimpleText( name, "LBR_HUD_Small", tx + aw + S( 8 ), y + h / 2, Color( nc.r, nc.g, nc.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end
	if shownCol then
		surface.SetDrawColor( shownCol.r, shownCol.g, shownCol.b, a )
		surface.DrawRect( x, y + h - S( 2 ), w, S( 2 ) )
	end

	// opening bar (supply drop): progress read live from the entity; swap bar
	local p = IsValid( target ) and target.OpenProgress and target:OpenProgress()
	if swapEnt and swapEnt == target then p = math.min( ( CurTime() - swapStart ) / LBR.SWAP_TIME, 1 ) end
	if p then
		local by = y + h + S( 4 )
		surface.SetDrawColor( colBg.r, colBg.g, colBg.b, colBg.a * alpha )
		surface.DrawRect( x, by, w, S( 8 ) )
		surface.SetDrawColor( colGold.r, colGold.g, colGold.b, a )
		surface.DrawRect( x + S( 2 ), by + S( 2 ), math.floor( ( w - S( 4 ) ) * p ), S( 4 ) )
	end
end )
