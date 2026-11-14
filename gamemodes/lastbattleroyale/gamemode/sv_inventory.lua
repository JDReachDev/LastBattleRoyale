// Inventory, server side (see sh_inventory.lua): keeps the slot layout of every
// player, refuses pickups when all the slots are full, swaps and drops from the
// TAB menu.

util.AddNetworkString( "LBR_InvMove" )
util.AddNetworkString( "LBR_InvDrop" )
util.AddNetworkString( "LBR_InvUnload" )
util.AddNetworkString( "LBR_InvSwap" )

local function layout( ply )
	ply.LBR_Inv = ply.LBR_Inv or {}
	return ply.LBR_Inv
end

local function send( ply )
	local inv = layout( ply )
	local t = {}
	for s = 1, LBR.INV_SLOTS do
		t[s] = IsValid( inv[s] ) and inv[s]:EntIndex() or 0
	end
	ply:SetNW2String( "LBR_Inv", table.concat( t, "," ) )
end

local function counted( ply )
	local n = 0
	for _, w in ipairs( ply:GetWeapons() ) do
		if not LBR.InvIsHands( w ) then n = n + 1 end
	end
	return n
end

// make the layout match the weapons the player really has:
// lost weapons leave their slot, new ones go to the first free equipment slot,
// then to the backpack; with no room left they are dropped
function LBR.InvSync( ply )
	if not IsValid( ply ) then return end
	local inv = layout( ply )
	local changed = false
	local known = {}
	// slots removed by a smaller lbr_inv_* setting: their weapons get a new place below
	for s, w in pairs( inv ) do
		if s > LBR.INV_SLOTS then
			inv[s] = nil
			changed = true
		end
	end
	for s = 1, LBR.INV_SLOTS do
		local w = inv[s]
		if w ~= nil and ( not IsValid( w ) or w:GetOwner() ~= ply or LBR.InvIsHands( w ) ) then
			inv[s] = nil
			changed = true
		elseif w then
			known[w] = true
		end
	end
	for _, w in ipairs( ply:GetWeapons() ) do
		if not known[w] and not LBR.InvIsHands( w ) then
			local free
			for s = 1, LBR.INV_SLOTS do
				if not IsValid( inv[s] ) then free = s break end
			end
			if free then
				inv[free] = w
				changed = true
			elseif ply:Alive() then
				// over the limit (supply drop, class loadout...): drop it
				LBR.DropWeapon( ply, w )
				LBR.Notify( ply, "Inventory full: " .. ( w.PrintName or w:GetClass() ) .. " dropped", "bad", 3 )
			end
		end
	end
	// the slot count changed: send the layout again with the new length
	if ply.LBR_InvSent ~= LBR.INV_SLOTS then
		ply.LBR_InvSent = LBR.INV_SLOTS
		changed = true
	end
	if changed or ply:GetNW2String( "LBR_Inv", "" ) == "" then send( ply ) end
	LBR.InvCheckActive( ply )
end

// the weapon in your hands is in the backpack (moved there, or picked up with
// the equipment full): take the first equipment weapon, else the hands
function LBR.InvCheckActive( ply )
	if not ply:Alive() then return end
	local inv = layout( ply )
	local act = ply:GetActiveWeapon()
	if not IsValid( act ) then return end
	local inBag = false
	for s = LBR.INV_EQUIP + 1, LBR.INV_SLOTS do
		if inv[s] == act then inBag = true end
	end
	if inBag then LBR.InvSelectBest( ply, act ) end
end

// first weapon of the equipment, else the hands
function LBR.InvSelectBest( ply, except )
	local inv = layout( ply )
	local pick
	for s = 1, LBR.INV_EQUIP do
		if IsValid( inv[s] ) and inv[s] ~= except and inv[s]:GetOwner() == ply then pick = inv[s] break end
	end
	if not pick then
		for _, w in ipairs( ply:GetWeapons() ) do
			if LBR.InvIsHands( w ) then pick = w break end
		end
	end
	if IsValid( pick ) then ply:SelectWeapon( pick:GetClass() ) end
end

local function syncSoon( ply )
	timer.Create( "LBR_InvSync_" .. ply:EntIndex(), 0, 1, function() LBR.InvSync( ply ) end )
end

// drops a weapon on the ground in front of the player (the Q drop)
// noSelect: do not pick the next weapon (the swap puts the new one in hand)
function LBR.DropWeapon( ply, wep, noSelect )
	if not IsValid( ply ) or not IsValid( wep ) or wep:GetOwner() ~= ply then return false end
	local class = wep:GetClass()
	if cantdropweapons and intab and intab( class, cantdropweapons ) then return false end
	local wasActive = ply:GetActiveWeapon() == wep
	local ent = ents.Create( class )
	if IsValid( ent ) then
		ent:SetPos( ply:GetShootPos() + ply:GetAimVector() * 10 )
		ent:SetAngles( ply:EyeAngles() )
		ent:Spawn()
		ent:PhysWake()
		local phys = ent:GetPhysicsObject()
		if IsValid( phys ) then phys:SetVelocity( ply:GetVelocity() + ply:GetAimVector() * 500 ) end
		ent:SetClip1( wep:Clip1() )
		ent.kanadelootable = true
		// you do not take it back at once while E is still held (swap, Q next to it)
		ent.LBR_DropBy, ent.LBR_DropTime = ply, CurTime()
	end
	// grenades, molotovs, mines: no magazine, the count is the reserve ammo. The
	// dropped one gives its default ammo to whoever takes it: take the same from
	// the reserve, so dropping and taking it back does not make new ones
	// The ammo taken goes with the dropped one (LBR_Charges, given back exactly on
	// pickup, see init.lua): a medkit with 2 charges left is 2 charges on the
	// ground, not 0 and not a full new one
	// One kit at a time: with more left (3 adrenaline shots, 2 medkits) the item
	// stays in the hands with the rest (it was stripped, the rest was lost from view)
	if wep:GetMaxClip1() <= 0 then
		local id = wep:GetPrimaryAmmoType()
		if id and id >= 0 then
			local full = weapons.Get( class )
			local give = math.max( tonumber( full and full.Primary and full.Primary.DefaultClip ) or 1, 1 )
			local moved = math.min( give, ply:GetAmmoCount( id ) )
			ply:RemoveAmmo( moved, id )
			if IsValid( ent ) then
				ent.LBR_Charges = moved
				if moved <= 0 then ent:Remove() end // empty: nothing to drop
			end
			if ply:GetAmmoCount( id ) > 0 then
				syncSoon( ply )
				return true
			end
		end
	end
	ply:StripWeapon( class )
	if wasActive and not noSelect then
		// go to the first weapon left in the equipment, else the hands
		timer.Simple( 0, function()
			if not IsValid( ply ) or not ply:Alive() then return end
			LBR.InvSync( ply )
			LBR.InvSelectBest( ply )
		end )
	end
	syncSoon( ply )
	return true
end

hook.Add( "WeaponEquip", "LBR_Inventory", function( wep, ply )
	if IsValid( ply ) then syncSoon( ply ) end
end )

hook.Add( "PlayerSpawn", "LBR_Inventory", function( ply )
	ply.LBR_Inv = {}
	ply:SetNW2String( "LBR_Inv", "" )
	syncSoon( ply )
end )

hook.Add( "PlayerDeath", "LBR_Inventory", function( ply )
	ply.LBR_Inv = {}
	ply:SetNW2String( "LBR_Inv", "" )
end )

// grenades thrown, items used up... checked twice a second
timer.Create( "LBR_InvSync", 0.5, 0, function()
	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() then LBR.InvSync( ply ) end
	end
end )

// pickup limit: all the slots (a weapon you already have only gives ammo)
function LBR.InvCanPickup( ply, wep )
	if LBR.InvIsHands( wep ) then return true end
	if ply.LBR_SwapEnt == wep then return true end // the swap made room for it
	if wep.LBR_DropBy == ply and CurTime() - ( wep.LBR_DropTime or 0 ) < 1 then return false end
	if ply:HasWeapon( wep:GetClass() ) then return true end
	if counted( ply ) < LBR.INV_SLOTS then return true end
	if ( ply.LBR_InvFullMsg or 0 ) < CurTime() then
		ply.LBR_InvFullMsg = CurTime() + 2
		LBR.Notify( ply, "Inventory full: hold E to swap it with the weapon in hand", "bad", 2.5 )
	end
	return false
end

// inventory full, E held on a weapon on the ground (LBR.SWAP_TIME, the client
// counts it and shows the bar): the weapon in hand is dropped, that one goes in
// the same slot and in hand
net.Receive( "LBR_InvSwap", function( _, ply )
	local ent = net.ReadEntity()
	if not ply:Alive() or ply:Team() ~= TEAM_CONT or not ply:KeyDown( IN_USE ) then return end
	if ( ply.LBR_SwapNext or 0 ) > CurTime() then return end
	ply.LBR_SwapNext = CurTime() + 0.5
	if not IsValid( ent ) or not ent:IsWeapon() or IsValid( ent:GetOwner() ) or not ent.kanadelootable then return end
	if ply:GetShootPos():Distance( ent:NearestPoint( ply:GetShootPos() ) ) > 130 then return end
	if ply:HasWeapon( ent:GetClass() ) then return end
	LBR.InvSync( ply )
	if counted( ply ) < LBR.INV_SLOTS then return end // room: the normal pickup does it
	local act = ply:GetActiveWeapon()
	if not IsValid( act ) or LBR.InvIsHands( act ) then
		LBR.Notify( ply, "Hold the weapon you want to swap", "bad", 2 )
		return
	end
	local inv = layout( ply )
	local slot
	for s = 1, LBR.INV_SLOTS do
		if inv[s] == act then slot = s end
	end
	if not slot then return end
	if cantdropweapons and intab and intab( act:GetClass(), cantdropweapons ) then
		LBR.Notify( ply, "You can not drop this", "bad", 2 )
		return
	end
	// 1) the new weapon first, while the old one is still in hand: dropping first
	// left the player with no weapon for a moment and the game could put another
	// one in hand (a CW 2.0 weapon then refuses any switch while it is deploying)
	local class = ent:GetClass()
	ply.LBR_SwapEnt = ent
	local ok = ply:PickupWeapon( ent )
	ply.LBR_SwapEnt = nil
	local new = ply:GetWeapon( class )
	if not ok or not IsValid( new ) then return end
	// 2) it takes the slot of the old one (before any sync sees one weapon too many)
	inv[slot] = new
	// 3) the old one on the ground, the new one in hand right away
	LBR.DropWeapon( ply, act, true )
	send( ply )
	ply:SelectWeapon( class )
	// 4) until it really is in hand: a CW 2.0 weapon put in hand meanwhile has its
	// deploy / holster wait cleared so it lets go at once
	timer.Create( "LBR_SwapSelect_" .. ply:EntIndex(), 0.1, 20, function()
		if not IsValid( ply ) or not ply:Alive() or not IsValid( new ) or new:GetOwner() ~= ply then
			timer.Remove( "LBR_SwapSelect_" .. ply:EntIndex() )
			return
		end
		local cur = ply:GetActiveWeapon()
		if cur == new then
			timer.Remove( "LBR_SwapSelect_" .. ply:EntIndex() )
			return
		end
		if IsValid( cur ) and cur.CW20Weapon then
			cur.GlobalDelay, cur.HolsterWait = 0, 0
		end
		ply:SelectWeapon( class )
	end )
end )

// swap two slots (drag and drop in TAB)
net.Receive( "LBR_InvMove", function( _, ply )
	local a, b = net.ReadUInt( 4 ), net.ReadUInt( 4 )
	if a < 1 or b < 1 or a > LBR.INV_SLOTS or b > LBR.INV_SLOTS or a == b then return end
	LBR.InvSync( ply )
	local inv = layout( ply )
	inv[a], inv[b] = inv[b], inv[a]
	send( ply )
	LBR.InvCheckActive( ply )
end )

// right click > Unload: the rounds in the weapon go back in its magazine store
// (sh_clips.lua): 15 rounds of an M4 (30) = 0.5 magazine
net.Receive( "LBR_InvUnload", function( _, ply )
	local s = net.ReadUInt( 4 )
	if not ply:Alive() or ( ply.LBR_UnloadNext or 0 ) > CurTime() then return end
	ply.LBR_UnloadNext = CurTime() + 0.5
	LBR.InvSync( ply )
	local w = layout( ply )[s]
	if not IsValid( w ) or w:GetOwner() ~= ply then return end
	if not LBR.UsesMagazines( w ) or w:Clip1() <= 0 then
		LBR.Notify( ply, "This weapon has no rounds to unload", "bad", 2 )
		return
	end
	local color = LBR.ClipColorOf( w )
	LBR.ClipSync( ply )
	// only what fits under the limit of that color, the rest stays in the weapon
	local size = math.max( w:GetMaxClip1(), 1 )
	local rounds = math.min( w:Clip1(), math.floor( LBR.ClipRoom( ply, color ) * size + 0.0001 ) )
	if rounds <= 0 then
		LBR.Notify( ply, "Your " .. LBR.TierById[color].name .. " magazines are full (x" .. LBR.ClipMax( color ) .. ")", "bad", 2 )
		return
	end
	local n = rounds / size
	w:SetClip1( w:Clip1() - rounds )
	LBR.ClipAdd( ply, color, n )
	LBR.ClipSync( ply )
	ply:EmitSound( "items/ammo_pickup.wav", 60, 80 )
	local t = LBR.TierById[color]
	LBR.Notify( ply, "Unloaded: +" .. LBR.ClipText( n ) .. " " .. ( t and t.name or "" ) .. " magazine", "event", 2 )
end )

net.Receive( "LBR_InvDrop", function( _, ply )
	local s = net.ReadUInt( 4 )
	if not ply:Alive() then return end
	LBR.InvSync( ply )
	local w = layout( ply )[s]
	if IsValid( w ) then
		if not LBR.DropWeapon( ply, w ) then
			LBR.Notify( ply, "You can not drop this", "bad", 2 )
		end
	end
end )
