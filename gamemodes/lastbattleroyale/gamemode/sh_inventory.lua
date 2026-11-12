// Inventory: 5 equipment slots (the weapons you switch between with the mouse
// wheel and 1-5) + 3 backpack slots (carried, not in the weapon bar).
// Weapons, medkits, adrenaline and grenades all take a slot. Melee / fists
// from the class are the "hands": always there, outside the 8 slots.
// The server owns the layout and sends it as a NW2 string of entity indexes.

LBR = LBR or {}

LBR.INV_EQUIP = 5
LBR.INV_BAG = 3
LBR.INV_SLOTS = LBR.INV_EQUIP + LBR.INV_BAG

// always available, outside the inventory
LBR.InvHands = {
	weapon_crowbar = true,
	weapon_stunstick = true,
	weapon_fists = true,
	cw_extrema_ratio_official = true,
	// admin / sandbox tools
	weapon_physgun = true,
	weapon_physcannon = true,
	gmod_tool = true,
	gmod_camera = true,
}

function LBR.InvIsHands( wep )
	if not IsValid( wep ) then return false end
	return LBR.InvHands[wep:GetClass()] == true
end

// slot -> weapon entity (or nil), from the networked string
function LBR.InvGet( ply )
	local out = {}
	local str = ply:GetNW2String( "LBR_Inv", "" )
	local i = 0
	for idx in string.gmatch( str, "[^,]+" ) do
		i = i + 1
		local n = tonumber( idx ) or 0
		if n > 0 then
			local w = Entity( n )
			if IsValid( w ) and w:IsWeapon() and w:GetOwner() == ply then out[i] = w end
		end
	end
	return out
end

// weapons you can switch to: hands first, then the equipment slots in order
function LBR.InvEquipList( ply )
	local list = {}
	for _, w in ipairs( ply:GetWeapons() ) do
		if LBR.InvIsHands( w ) then list[#list + 1] = w end
	end
	local inv = LBR.InvGet( ply )
	for s = 1, LBR.INV_EQUIP do
		if IsValid( inv[s] ) then list[#list + 1] = inv[s] end
	end
	return list
end

function LBR.InvSlotOf( ply, wep )
	for s, w in pairs( LBR.InvGet( ply ) ) do
		if w == wep then return s end
	end
end

// backpack weapons can not be taken in hand (move them to the equipment in TAB)
hook.Add( "PlayerSwitchWeapon", "LBR_Inventory", function( ply, old, new )
	if not IsValid( new ) then return end
	local s = LBR.InvSlotOf( ply, new )
	if s and s > LBR.INV_EQUIP then return true end
end )
