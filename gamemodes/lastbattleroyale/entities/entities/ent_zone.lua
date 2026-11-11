AddCSLuaFile()

// Marker entity at the zone center. The zone itself is drawn by gamemode/cl_zone.lua
// and computed by gamemode/sh_zone.lua (no per-frame work here anymore).

ENT.PrintName = "Zone"
ENT.Type = "anim"
ENT.Model = "models/Items/item_item_crate.mdl"

function ENT:Initialize()
	self:SetModel( self.Model )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_NONE )
	self:DrawShadow( false )
end

function ENT:Draw()
end
