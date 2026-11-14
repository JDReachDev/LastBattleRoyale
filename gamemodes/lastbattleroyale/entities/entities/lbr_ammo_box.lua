// Box of magazines of one color on the ground (sh_clips.lua): dropped from TAB,
// fallen from a dead player (one per color), in a supply drop.
// Up to the limit of the color (lbr_clips_max_*), the rest stays in the box.
// E takes one magazine, hold E for one every TAKE_TIME seconds; under one
// magazine left (0.23) the last press takes it all. Any weapon: the magazines go
// in the store of that color. Dropped next to a box of the same color, more
// magazines go in that box.
// Dropped boxes disappear after LIFETIME seconds, the ones of the dead and of the
// supply drops stay until the round ends.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Magazines"
ENT.Spawnable = false

local LIFETIME = 120
local TAKE_TIME = 0.4

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "Amount" ) // magazines
	self:NetworkVar( "String", 0, "Tier" ) // color
end

function ENT:TierTable()
	return LBR.TierById and LBR.TierById[self:GetTier()]
end

// "Purple magazines x2.5"
function ENT:Label()
	local t = self:TierTable()
	return ( t and t.name or "Ammo" ) .. " magazines x" .. LBR.ClipText( self:GetAmount() )
end

// what one press takes
function ENT:NextTake()
	local n = self:GetAmount()
	return n < 1.001 and n or 1
end

if SERVER then
	function ENT:Initialize()
		self:SetModel( "models/items/boxmrounds.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
		self:SetUseType( CONTINUOUS_USE )
		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then phys:Wake() end
		self:Refresh( self.Life )
		local t = self:TierTable()
		if t then self:SetColor( t.color ) end
	end

	// life: seconds left, 0 = until the round ends, nil = the default
	function ENT:Refresh( life )
		if life ~= nil then self.Life = life end
		local l = self.Life == nil and LIFETIME or self.Life
		self.DieTime = l > 0 and CurTime() + l or nil
	end

	function ENT:Think()
		if self.DieTime and CurTime() > self.DieTime then self:Remove() return end
		self:NextThink( CurTime() + 1 )
		return true
	end

	function ENT:Use( ply )
		if not IsValid( ply ) or not ply:IsPlayer() or not ply:Alive() or self.Taken then return end
		if ( ply.LBR_ClipBoxNext or 0 ) > CurTime() then return end
		ply.LBR_ClipBoxNext = CurTime() + TAKE_TIME
		local t = self:TierTable()
		local room = LBR.ClipRoom( ply, self:GetTier() )
		if room < 0.0001 then
			if ( ply.LBR_ClipFullMsg or 0 ) < CurTime() then
				ply.LBR_ClipFullMsg = CurTime() + 2
				LBR.Notify( ply, "Your " .. ( t and t.name or "" ) .. " magazines are full (x" .. LBR.ClipText( LBR.ClipMax( self:GetTier() ) ) .. ")", "bad", 2 )
			end
			return
		end
		local n = math.min( self:NextTake(), room )
		if n <= 0 then return end
		n = LBR.ClipAdd( ply, self:GetTier(), n )
		local left = self:GetAmount() - n
		LBR.Notify( ply, "+" .. LBR.ClipText( n ) .. " " .. ( t and t.name or "" ) .. " magazine" .. ( n > 1 and "s" or "" ) .. " (you: x" .. LBR.ClipText( LBR.GetClips( ply, self:GetTier() ) ) .. ", box: " .. ( left < 0.0001 and "empty" or "x" .. LBR.ClipText( left ) .. " left" ) .. ")", "good", 2 )
		if left < 0.0001 then
			self.Taken = true
			self:EmitSound( "items/ammo_pickup.wav" )
			self:Remove()
		else
			self:SetAmount( left )
			self:EmitSound( "items/ammo_pickup.wav", 60, 115 )
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
