AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

function ENT:Initialize()
	local cmd = GetConVar("lst_usecssarmor"):GetInt()
	if cmd == 0 then
		self.Entity:SetModel("models/Items/item_item_crate.mdl")
	else
		self.Entity:SetModel("models/combine_vests/obseletevest.mdl")
	end
	self.Entity:PhysicsInit(SOLID_VPHYSICS)
	self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
	self.Entity:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	local phys = self.Entity:GetPhysicsObject()

	if phys and phys:IsValid() then phys:Wake() end
	self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS) 
end

function ENT:Use(plyUse)
	plyUse:SetModel("models/mw2/skin_12/MW2_Soldier_06.mdl")
	plyUse:SetArmor(30)
	self:EmitSound( Sound("npc/combine_soldier/zipline_clothing".. math.random(1, 2).. ".wav") )
	self:Remove()
end

function ENT:OnRemove()
	self:Remove()
end