// Inventory, server side (see sh_inventory.lua): keeps the slot layout of every
// player, refuses pickups when all the slots are full, swaps and drops from the
// TAB menu.

util.AddNetworkString( "LBR_InvMove" )
util.AddNetworkString( "LBR_InvDrop" )
util.AddNetworkString( "LBR_InvUnload" )

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
function LBR.DropWeapon( ply, wep )
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
	end
	ply:StripWeapon( class )
	if wasActive then
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
	if ply:HasWeapon( wep:GetClass() ) then return true end
	if counted( ply ) < LBR.INV_SLOTS then return true end
	if ( ply.LBR_InvFullMsg or 0 ) < CurTime() then
		ply.LBR_InvFullMsg = CurTime() + 2
		LBR.Notify( ply, "Inventory full: drop something first (Q, or right click in TAB)", "bad", 2.5 )
	end
	return false
end

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

// right click > Unload ammo: the magazine and all the reserve of that caliber go
// in a box on the ground, anyone with a weapon of the same group takes it with E
net.Receive( "LBR_InvUnload", function( _, ply )
	local s = net.ReadUInt( 4 )
	if not ply:Alive() or ( ply.LBR_UnloadNext or 0 ) > CurTime() then return end
	ply.LBR_UnloadNext = CurTime() + 0.5
	LBR.InvSync( ply )
	local w = layout( ply )[s]
	if not IsValid( w ) or w:GetOwner() ~= ply then return end
	local id = w:GetPrimaryAmmoType()
	if id < 0 or w:GetMaxClip1() <= 0 then
		LBR.Notify( ply, "This weapon has no ammo to unload", "bad", 2 )
		return
	end
	local total = math.max( w:Clip1(), 0 ) + ply:GetAmmoCount( id )
	if total <= 0 then
		LBR.Notify( ply, "No ammo to unload", "bad", 2 )
		return
	end
	local box = ents.Create( "lbr_ammo_box" )
	if not IsValid( box ) then return end
	w:SetClip1( 0 )
	ply:SetAmmo( 0, id )
	box:SetPos( ply:GetShootPos() + ply:GetAimVector() * 20 )
	box:SetAngles( Angle( 0, ply:EyeAngles().y, 0 ) )
	box:SetAmmoID( id )
	box:SetAmount( total )
	box:Spawn()
	local phys = box:GetPhysicsObject()
	if IsValid( phys ) then phys:SetVelocity( ply:GetVelocity() + ply:GetAimVector() * 250 ) end
	ply:EmitSound( "items/ammo_pickup.wav", 60, 80 )
	LBR.Notify( ply, "Unloaded " .. total .. " " .. box:GroupName(), "event", 2 )
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
