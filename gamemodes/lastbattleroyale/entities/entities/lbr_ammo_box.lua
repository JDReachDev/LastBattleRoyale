// Magazine unloaded from a weapon (right click in the TAB inventory > Unload a
// magazine). Anyone with a weapon of the same ammo group (pistol / SMG, rifle,
// sniper, shotgun: see LBR.AmmoGroup) takes it with E and gets one magazine of
// that weapon (Amount = magazines, not rounds). It disappears after a while so the ground does not fill up.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ammo"
ENT.Spawnable = false

local LIFETIME = 120

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "AmmoID" )
	self:NetworkVar( "Int", 1, "Amount" ) // magazines
end

function ENT:Group()
	return LBR.AmmoGroup( self:GetAmmoID() )
end

// "Rifle magazine", or the caliber name for an ammo type outside the groups
function ENT:GroupName()
	local g = self:Group()
	if g and LBR.AmmoGroupNames[g] then return LBR.AmmoGroupNames[g] .. " magazine" end
	return ( game.GetAmmoName( self:GetAmmoID() ) or "ammo" ) .. " magazine"
end

// the weapon of ply that takes this ammo: the one in hand first
function ENT:WeaponFor( ply )
	local g = self:Group()
	if not g then return end
	local act = ply:GetActiveWeapon()
	if IsValid( act ) and LBR.AmmoGroup( act:GetPrimaryAmmoType() ) == g then return act end
	for _, w in ipairs( ply:GetWeapons() ) do
		if LBR.AmmoGroup( w:GetPrimaryAmmoType() ) == g then return w end
	end
end

if SERVER then
	function ENT:Initialize()
		self:SetModel( "models/items/boxmrounds.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
		self:SetUseType( SIMPLE_USE )
		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then phys:Wake() end
		self.DieTime = CurTime() + LIFETIME
	end

	function ENT:Think()
		if CurTime() > self.DieTime then self:Remove() return end
		self:NextThink( CurTime() + 1 )
		return true
	end

	function ENT:Use( ply )
		if not IsValid( ply ) or not ply:IsPlayer() or not ply:Alive() or self.Taken then return end
		local w = self:WeaponFor( ply )
		if not IsValid( w ) then
			LBR.Notify( ply, "No weapon for this ammo (" .. self:GroupName() .. ")", "bad", 2 )
			return
		end
		self.Taken = true
		ply:GiveAmmo( self:GetAmount() * math.max( w:GetMaxClip1(), 1 ), w:GetPrimaryAmmoType() )
		self:EmitSound( "items/ammo_pickup.wav" )
		self:Remove()
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
