AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:Initialize()
	self:SetModel("models/blacksnow/rust_grenade.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	local phys = self:GetPhysicsObject()
	if phys and phys:IsValid() then
		phys:Wake()
	end
	
	self.timeleft = CurTime() + 10
	self:Think()
	
	timer.Create("trailmemey", 2, 1, function()
		self:EmitSound(Sound("weapons/smokegrenade/sg_explode.wav"),70,100)
		util.SpriteTrail(self.Entity, 0, Color(0, 255, 0, 210), false, 1, 100, 5, 5 / ((2 + 10) * 0.5), "trails/smoke.vmt")
	end)
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:PhysicsCollide(data, physobj)
end
---------------------------------------------------------------------------------------------------------------------------------------------

 function ENT:Think()

	if self.timeleft < CurTime() then
		
	self:EmitSound( "entities/airdrop_plane.wav", 511, 100, 1, CHAN_AUTO ) -- Same as below
	

	local ent2 = ents.Create( "ent_supplydrop_fix" )
	
	--local skytrace = {}
	--skytrace.endpos = GetEyeTrace() + Vector(0,0,65000)
	ent2:SetPos(self:GetPos() + Vector(0,0,7500) + Vector(math.random(1,200), math.random(1,200), 0) )
	ent2:Spawn()
	ent2:Activate()
	
	return true
	
	end
	--timer.Simple(10, function() self:Remove()end)
	timer.Create("destroy", 5, 1, function() self:Remove()end)
end
---------------------------------------------------------------------------------------------------------------------------------------------

