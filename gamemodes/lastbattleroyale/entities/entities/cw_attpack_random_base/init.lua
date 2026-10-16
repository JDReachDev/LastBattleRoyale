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
	self.NextImpact = 0
	phys = self:GetPhysicsObject()

	if phys and phys:IsValid() then
		phys:Wake()
	end
	
	self:GetPhysicsObject():SetBuoyancyRatio(0)
end

function ENT:Use(activator, caller)
	if activator:GetActiveWeapon().Primary == nil then
		activator:PrintMessage(HUD_PRINTCENTER, "You can not get any attachments to this weapon")
		return
	end
	if activator:GetActiveWeapon().Primary.ClipSize == nil then
		activator:PrintMessage(HUD_PRINTCENTER, "You can not get any attachments to this weapon")
		return
	end
	if activator:GetActiveWeapon().Primary.ClipSize < 1 then
		activator:PrintMessage(HUD_PRINTCENTER, "You can not get any attachments to this weapon")
		return
	end
	if activator:GetActiveWeapon().Attachments == nil then
		activator:PrintMessage(HUD_PRINTCENTER, "You can not get any attachments to this weapon")
		return
	end
	if #activator:GetActiveWeapon().Attachments < 1 then
		activator:PrintMessage(HUD_PRINTCENTER, "You can not get any attachments to this weapon")
		return
	end
	local weapon_atts = {}
	for k,v in pairs(activator:GetActiveWeapon().Attachments) do
		for num,att in pairs(v.atts) do
			if CustomizableWeaponry:hasSpecifiedAttachments(activator, {att}) == false then
				table.ForceInsert(weapon_atts, att)
			end
		end
	end
	if #weapon_atts < 2 then
		activator:PrintMessage(HUD_PRINTCENTER, "You can not get any more attachments to this weapon")
		return
	end
	local needtogive = {}
	for i=1, self.NumAtts do
		local rnd = table.Random(weapon_atts)
		table.insert(needtogive, i, rnd)
		table.RemoveByValue(weapon_atts, rnd)
	end
	if #needtogive > 0 then
		CustomizableWeaponry.giveAttachments(activator, needtogive)
	else
		activator:PrintMessage(HUD_PRINTCENTER, "You can not get any more attachments to this weapon")
		return
	end
	self:Remove()
end
