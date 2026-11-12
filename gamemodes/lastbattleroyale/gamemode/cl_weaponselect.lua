// Weapon selection made for the gamemode (replaces the Half-Life 2 menu).
//  - mouse wheel: switch to the next / previous weapon right away
//  - 1-6: switch to the weapon in that slot (press again to cycle the slot)
//  - a strip of cards at the bottom shows your weapons for a few seconds after a
//    switch or a pickup, with the slot number, name and ammo

LBR = LBR or {}

local scale = 1
local function S( v ) return math.Round( v * scale ) end
local function updateScale() scale = math.Clamp( ScrH() / 1080, 0.6, 2 ) end
updateScale()
hook.Add( "OnScreenSizeChanged", "LBR_WeaponSelectScale", updateScale )

local SHOW_TIME = 2.2
local FADE_TIME = 0.4

local colGold = Color( 255, 210, 70 )
local colText = Color( 236, 239, 245 )
local colDim = Color( 150, 158, 175 )
local colWarn = Color( 255, 80, 70 )

local showUntil = 0
local pending // weapon we asked to switch to (highlighted before the switch finishes)
local pendingUntil = 0
local nextRetry = 0

local function weaponList( ply )
	local list = {}
	for _, w in ipairs( ply:GetWeapons() ) do
		if IsValid( w ) then list[#list + 1] = w end
	end
	table.sort( list, function( a, b )
		local sa, sb = a:GetSlot(), b:GetSlot()
		if sa ~= sb then return sa < sb end
		local pa, pb = a:GetSlotPos(), b:GetSlotPos()
		if pa ~= pb then return pa < pb end
		return a:GetClass() < b:GetClass()
	end )
	return list
end

local function canSelect( ply )
	if not IsValid( ply ) or not ply:Alive() then return false end
	if ply:InVehicle() then return false end
	if ply:GetObserverMode() ~= OBS_MODE_NONE then return false end
	if LBR.Editor and LBR.Editor.active then return false end
	return true
end

local function requestSwitch( wep )
	input.SelectWeapon( wep )
	// CW 2.0 keeps switching to the weapon chosen when the holster animation
	// started: point it to the new choice (here and on the server)
	local act = LocalPlayer():GetActiveWeapon()
	if IsValid( act ) and act.CW20Weapon and IsValid( act.SwitchWep ) and act.SwitchWep ~= wep then
		act.SwitchWep = wep
		RunConsoleCommand( "lbr_switchweapon", tostring( wep:EntIndex() ) )
	end
end

local function selectWeapon( wep )
	if not IsValid( wep ) then return end
	pending = wep
	pendingUntil = CurTime() + 3
	showUntil = CurTime() + SHOW_TIME
	if wep ~= LocalPlayer():GetActiveWeapon() then
		requestSwitch( wep )
		LocalPlayer():EmitSound( "common/wpn_moveselect.wav", 0, 100, 0.25, CHAN_STATIC )
	end
end

local function currentWeapon( ply )
	if IsValid( pending ) and pending:GetOwner() == ply then return pending end
	return ply:GetActiveWeapon()
end

// CW 2.0 uses the mouse wheel and the number keys in its customization menu (C):
// leave them alone then
local function weaponIsCustomizing( wep )
	if not IsValid( wep ) then return false end
	if wep.dt and CW_CUSTOMIZE and wep.dt.State == CW_CUSTOMIZE then return true end
	return false
end

hook.Add( "PlayerBindPress", "LBR_WeaponSelect", function( ply, bind, pressed )
	if not pressed or not canSelect( ply ) then return end

	local isNext = string.find( bind, "invnext", 1, true )
	local isPrev = string.find( bind, "invprev", 1, true )
	local slot = tonumber( string.match( bind, "^slot(%d)$" ) or "" )
	if not isNext and not isPrev and not slot then return end
	if weaponIsCustomizing( ply:GetActiveWeapon() ) then
		// CW 2.0 uses 1-9 to mount attachments and blocks the weapon switch itself
		local w = ply:GetActiveWeapon()
		if slot and not ( istable( w.Attachments ) and w.Attachments[slot] ) then return true end
		return
	end

	local list = weaponList( ply )
	if #list == 0 then return true end
	local cur = currentWeapon( ply )
	local idx = 0
	for i, w in ipairs( list ) do
		if w == cur then idx = i break end
	end

	if isNext or isPrev then
		local dir = isNext and 1 or -1
		if idx == 0 then idx = isNext and 0 or 1 end
		selectWeapon( list[( ( idx - 1 + dir ) % #list ) + 1] )
		return true
	end

	// number keys: weapons in that slot, cycling
	if slot < 1 or slot > 6 then return true end
	local inSlot = {}
	for _, w in ipairs( list ) do
		if w:GetSlot() == slot - 1 then inSlot[#inSlot + 1] = w end
	end
	if #inSlot == 0 then
		showUntil = CurTime() + SHOW_TIME
		return true
	end
	local pick = inSlot[1]
	for i, w in ipairs( inSlot ) do
		if w == cur then pick = inSlot[( i % #inSlot ) + 1] break end
	end
	selectWeapon( pick )
	return true
end )

hook.Add( "HUDShouldDraw", "LBR_WeaponSelect", function( name )
	if name == "CHudWeaponSelection" then return false end
end )

// show the strip when a weapon is picked up or dropped
local lastCount = 0
hook.Add( "Think", "LBR_WeaponSelectWatch", function()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	local n = #lp:GetWeapons()
	if n ~= lastCount then
		if n > lastCount and canSelect( lp ) then showUntil = CurTime() + SHOW_TIME end
		lastCount = n
	end
	if IsValid( pending ) and pending == lp:GetActiveWeapon() then pending = nil end
	if pending and CurTime() > pendingUntil then pending = nil end // switch refused (reload...)
	// a switch asked while the weapon is still being drawn (or holstered) is
	// refused by CW 2.0: ask again until it happens
	if IsValid( pending ) and pending ~= lp:GetActiveWeapon() and pending:GetOwner() == lp and CurTime() > nextRetry then
		nextRetry = CurTime() + 0.1
		requestSwitch( pending )
	end
end )

local function shortName( wep )
	local name = wep.GetPrintName and wep:GetPrintName() or wep:GetClass()
	if string.sub( name, 1, 1 ) == "#" then name = language.GetPhrase( string.sub( name, 2 ) ) end
	return string.upper( name )
end

local function fit( str, font, w )
	surface.SetFont( font )
	if surface.GetTextSize( str ) <= w then return str end
	while #str > 1 and surface.GetTextSize( str .. "..." ) > w do str = string.sub( str, 1, -2 ) end
	return str .. "..."
end

hook.Add( "HUDPaint", "LBR_WeaponSelect", function()
	local lp = LocalPlayer()
	if not canSelect( lp ) then return end
	local left = showUntil - CurTime()
	if left <= 0 then return end
	local alpha = math.Clamp( left / FADE_TIME, 0, 1 )

	local list = weaponList( lp )
	if #list == 0 then return end
	local cur = currentWeapon( lp )

	local cw, ch, gap = S( 150 ), S( 58 ), S( 6 )
	local maxCards = math.max( 1, math.floor( ( ScrW() - S( 40 ) ) / ( cw + gap ) ) )
	local n = math.min( #list, maxCards )
	local total = n * cw + ( n - 1 ) * gap
	local x = math.floor( ( ScrW() - total ) / 2 )
	local y = ScrH() - S( 200 )

	for i = 1, n do
		local w = list[i]
		local active = w == cur
		local cx = x + ( i - 1 ) * ( cw + gap )
		local cy = active and y - S( 6 ) or y

		surface.SetDrawColor( 10, 14, 24, ( active and 215 or 150 ) * alpha )
		surface.DrawRect( cx, cy, cw, ch )
		if active then
			surface.SetDrawColor( colGold.r, colGold.g, colGold.b, 255 * alpha )
			surface.DrawRect( cx, cy + ch - S( 3 ), cw, S( 3 ) )
		end

		// slot number
		local a = ( active and 255 or 170 ) * alpha
		draw.SimpleText( tostring( w:GetSlot() + 1 ), "LBR_HUD_Tiny", cx + S( 8 ), cy + S( 6 ), Color( colDim.r, colDim.g, colDim.b, a ) )

		// name
		local nameCol = active and colGold or colText
		draw.SimpleText( fit( shortName( w ), "LBR_HUD_Small", cw - S( 16 ) ), "LBR_HUD_Small", cx + S( 8 ), cy + S( 22 ), Color( nameCol.r, nameCol.g, nameCol.b, a ) )

		// ammo
		local clip = w:Clip1()
		local ammoType = w:GetPrimaryAmmoType()
		local reserve = ammoType >= 0 and lp:GetAmmoCount( ammoType ) or 0
		local txt
		if clip >= 0 then txt = clip .. " / " .. reserve
		elseif ammoType >= 0 then txt = tostring( reserve ) end
		if txt then
			local empty = clip == 0 and reserve == 0 or ( clip < 0 and reserve == 0 )
			local c = empty and colWarn or colDim
			draw.SimpleText( txt, "LBR_HUD_Tiny", cx + cw - S( 8 ), cy + S( 6 ), Color( c.r, c.g, c.b, a ), TEXT_ALIGN_RIGHT )
		end
	end
end )
