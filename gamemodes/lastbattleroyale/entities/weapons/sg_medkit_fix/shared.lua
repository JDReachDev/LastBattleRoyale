SWEP.PrintName 		= "Atlantis Medical Kit"
SWEP.Author 		= "Gmod4phun, Progsys\n(Less messy code/icons - LordiAnders)" 
SWEP.Purpose		= "Give medical supplies to your friends."
SWEP.Instructions	= "Left click to heal yourself. Use + Right click to throw Adrenaline, Reload + Right click to throw Medkit"
SWEP.AdminSpawnable = true
SWEP.Spawnable 		= true
SWEP.ViewModelFOV 	= 64
SWEP.ViewModel 		= "models/pg_props/pg_weapons/pg_healthkit_v.mdl"
SWEP.WorldModel 	= "models/pg_props/pg_weapons/pg_healthkit_w.mdl"
SWEP.Slot 			= 4
SWEP.SlotPos = 1
SWEP.HoldType = "slam"
SWEP.Weight = 5
SWEP.DrawCrosshair = false
SWEP.Category = "CAP Misc Weapons"
SWEP.base = "weapon_base"

SWEP.Primary.ClipSize = -1
SWEP.Primary.Ammo = "GaussEnergy" 
SWEP.Primary.DefaultClip = 4
SWEP.Primary.Automatic = false

SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.ClipSize = -1

SWEP.CanHolster = true

if CLIENT then
SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/sg_medkit")
SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
	self:SetWeaponHoldType( self.HoldType )
end

local function SG_IsActive(self)
	if not IsValid(self) then return false end
	if not self.Owner or not IsValid(self.Owner) then return false end
	if not IsValid(self.Owner:GetActiveWeapon()) then return false end
	if not self.Owner:GetActiveWeapon() == self then return false end
	return true
end

function SWEP:Deploy()
	self:SendWeaponAnim( ACT_VM_DRAW )
	self:SetNextPrimaryFire(CurTime()+0.8)
	self:SetNextSecondaryFire(CurTime()+0.8)

timer.Simple(self.Owner:GetViewModel():SequenceDuration(), function()
	if SG_IsActive(self) then
	self:SendWeaponAnim(ACT_VM_IDLE)
	end
end)

end  


function SWEP:PrimaryAttack()
if self:Ammo1() > 0 then
	self.CanHolster = false

	self:TakePrimaryAmmo(1)

	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
	self:SetNextPrimaryFire(CurTime()+4)
	self:SetNextSecondaryFire(CurTime()+4)

timer.Simple(3, function()
	if not SG_IsActive(self) then return end
	if self.Owner:Health() < 100 then
		if (self.Owner:Health() + 35) > 100 then
			self.Owner:SetHealth(100)
		else
			self.Owner:SetHealth(self.Owner:Health() + 35)
		end
	end
end)	

timer.Simple(self.Owner:GetViewModel():SequenceDuration(), function()
	if SG_IsActive(self) then
	self:SendWeaponAnim(ACT_VM_IDLE)
	self.CanHolster = true
	end
end)

timer.Simple(2.6, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("weapons/slam/mine_mode.wav")
	end
end)

timer.Simple(0.7, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("doors/generic_door_open.wav", 75, 200)
	end
end)

timer.Simple(2.2, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("doors/generic_door_close.wav", 75, 200)
	end
end)

timer.Simple(2, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("weapons/ak47/ak47_clipout.wav", 40, 170)
	end
end)

timer.Simple(1.6, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("npc/combine_soldier/gear6.wav", 80, 120)
	end
end)

end
end

function SWEP:SecondaryAttack()
if self.Owner:KeyDown(IN_USE) and self:Ammo1() > 0 then
self.CanHolster = false

self:TakePrimaryAmmo(1)

timer.Simple(self.Owner:GetViewModel():SequenceDuration(), function()
	if SG_IsActive(self) then
		self:SendWeaponAnim(ACT_VM_IDLE)
		self.CanHolster = true
	end
end)

	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK_2 )
	self:SetNextPrimaryFire(CurTime()+4)
	self:SetNextSecondaryFire(CurTime()+4)

timer.Simple(2.8, function()
if not SG_IsActive(self) then return end
if SERVER then
--The thrown Adrenaline
local syr = ents.Create("sg_adrenaline_thrown")
local o = self.Owner

local tr = util.TraceLine( {
	start = o:GetShootPos(),
	endpos = o:GetShootPos() + o:EyeAngles():Forward() * 50,
	filter = o
} )

syr:SetPos(tr.HitPos + Vector(0,0,10))
syr:Spawn()
end
end)

timer.Simple(0.8, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("doors/generic_door_open.wav", 75, 200)
	end
end)

timer.Simple(2.2, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("doors/generic_door_close.wav", 75, 200)
	end
end)

timer.Simple(1.6, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("npc/combine_soldier/gear6.wav", 80, 120)
	end
end)

timer.Simple(2.7, function()
	if not SG_IsActive(self) then return end
	if SERVER then
		self:EmitSound("physics/cardboard/cardboard_box_break3.wav", 80, 180)
	end
end)

return

end

----------------------------------------------------------
if self.Owner:KeyDown(IN_RELOAD) then

	self.CanHolster = false

timer.Simple(0.4, function()
	if SG_IsActive(self) then
		self.Owner:ConCommand("lastinv")
		if SERVER then
			local med = ents.Create("sg_med_thrown")
			local o = self.Owner

			local tr = util.TraceLine( {
				start = o:GetShootPos(),
				endpos = o:GetShootPos() + o:EyeAngles():Forward() * 50,
				filter = o
			} )

			med:SetPos(tr.HitPos + Vector(0,0,10))
			med:Spawn()
		end
		if SERVER then 
			self.Owner:StripWeapon(self:GetClass()) --You ARE technically throwing your medkit away
		end
	end
end)

	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	self:SetNextPrimaryFire(CurTime() + self.Owner:GetViewModel():SequenceDuration())
	self:SetNextSecondaryFire(CurTime() + self.Owner:GetViewModel():SequenceDuration())

end
end

function SWEP:Reload() end

function SWEP:Holster()

	return self.CanHolster
end