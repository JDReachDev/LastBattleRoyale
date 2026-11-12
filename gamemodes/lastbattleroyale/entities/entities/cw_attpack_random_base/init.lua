AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.NumAtts = 2
ENT.Model = "models/Items/BoxSRounds.mdl"

function ENT:Initialize()
	self:SetModel(self.Model) 
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetUseType(SIMPLE_USE)
	self.NextImpact = 0
	phys = self:GetPhysicsObject()

	if phys and phys:IsValid() then
		phys:Wake()
	end
	
	self:GetPhysicsObject():SetBuoyancyRatio(0)
end

// attachments the player does not have yet for one CW 2.0 weapon
local function missingFor( ply, wep )
	local out = {}
	if not IsValid( wep ) or not wep.CW20Weapon or not istable( wep.Attachments ) then return out end
	for _, cat in pairs( wep.Attachments ) do
		for _, att in pairs( cat.atts or {} ) do
			if CustomizableWeaponry.registeredAttachmentsSKey[att] and not ply.CWAttachments[att] and not table.HasValue( out, att ) then
				out[#out + 1] = att
			end
		end
	end
	return out
end

// gives attachments for the weapon in your hands; if it has none left (or it is
// not a CW 2.0 weapon) for the other CW 2.0 weapons you carry
function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not CustomizableWeaponry then return end
	activator.CWAttachments = activator.CWAttachments or {}

	local weps = { activator:GetActiveWeapon() }
	for _, w in ipairs( activator:GetWeapons() ) do
		if w ~= weps[1] then weps[#weps + 1] = w end
	end

	local give, forWep = {}, nil
	for _, w in ipairs( weps ) do
		local pool = missingFor( activator, w )
		while #pool > 0 and #give < self.NumAtts do
			local att = table.remove( pool, math.random( #pool ) )
			give[#give + 1] = att
			forWep = forWep or w
		end
		if #give >= self.NumAtts then break end
	end

	if #give == 0 then
		LBR.Notify( activator, "No new attachments for your weapons: pick up a CW 2.0 weapon first", "bad", 3 )
		return
	end

	CustomizableWeaponry.giveAttachments( activator, give, true )
	local names = {}
	for _, att in ipairs( give ) do
		local a = CustomizableWeaponry.registeredAttachmentsSKey[att]
		names[#names + 1] = a and ( a.displayNameShort or a.displayName ) or att
	end
	local wname = IsValid( forWep ) and ( forWep.PrintName or forWep:GetClass() ) or "your weapon"
	LBR.Notify( activator, "Attachments: " .. table.concat( names, ", " ) .. "  (C on " .. wname .. " to mount them)", "good", 5 )
	activator:EmitSound( "items/ammo_pickup.wav", 60, 110 )
	self:Remove()
end
