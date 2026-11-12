// Inventory: equipment slots (the weapons you switch between with the mouse
// wheel and the number keys) + backpack slots (carried, not in the weapon bar).
// 5 + 3 by default, set with lbr_inv_equipment (1-6) and lbr_inv_backpack (0-6);
// a change is applied outside a match (lobby), never in the middle of one.
// Weapons, medkits, adrenaline and grenades all take a slot. Melee / fists
// from the class are the "hands": always there, outside the slots.
// The server owns the layout and sends it as a NW2 string of entity indexes.

LBR = LBR or {}

LBR.INV_EQUIP_MAX = 6
LBR.INV_BAG_MAX = 6

if not ConVarExists( "lbr_inv_equipment" ) then
	CreateConVar( "lbr_inv_equipment", "5", { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED }, "Equipment slots (weapons in hand, keys 1-N), 1 to 6" )
end
if not ConVarExists( "lbr_inv_backpack" ) then
	CreateConVar( "lbr_inv_backpack", "3", { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED }, "Backpack slots, 0 to 6" )
end

local function setSlots( equip, bag )
	LBR.INV_EQUIP = math.Clamp( math.floor( tonumber( equip ) or 5 ), 1, LBR.INV_EQUIP_MAX )
	LBR.INV_BAG = math.Clamp( math.floor( tonumber( bag ) or 3 ), 0, LBR.INV_BAG_MAX )
	LBR.INV_SLOTS = LBR.INV_EQUIP + LBR.INV_BAG
end
setSlots( LBR.INV_EQUIP or 5, LBR.INV_BAG or 3 )

if SERVER then
	// the slot counts in use, sent to everyone; changed only outside a match
	local function apply()
		if GetGlobalInt( "state", 1 ) == STATE_LIVE then return end
		local e = GetConVar( "lbr_inv_equipment" ):GetInt()
		local b = GetConVar( "lbr_inv_backpack" ):GetInt()
		setSlots( e, b )
		if GetGlobalInt( "LBR_InvEquip", 0 ) ~= LBR.INV_EQUIP then SetGlobalInt( "LBR_InvEquip", LBR.INV_EQUIP ) end
		if GetGlobalInt( "LBR_InvBag", -1 ) ~= LBR.INV_BAG then SetGlobalInt( "LBR_InvBag", LBR.INV_BAG ) end
	end
	apply()
	timer.Create( "LBR_InvSlots", 1, 0, apply )
else
	hook.Add( "Think", "LBR_InvSlots", function()
		local e = GetGlobalInt( "LBR_InvEquip", 0 )
		if e > 0 then setSlots( e, GetGlobalInt( "LBR_InvBag", 3 ) ) end
	end )
end

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
