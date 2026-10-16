AddCSLuaFile() 

ENT.PrintName = "Zone"
ENT.Type = "anim"
ENT.Model = "models/Items/item_item_crate.mdl"
ENT.Radius = 0

function ENT:Initialize()
	self:SetModel( self.Model )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_NONE )
end

local spherecolor = Color( 0, 175, 175, 35 )

function ENT:Think()
	self.Radius = GetGlobalInt("Zone_Radius")
	if GetGlobalInt("Zone_Radius") < 1750 then
		if spherecolor["r"] < 256 and spherecolor["g"] > 0 and spherecolor["b"] > 0 then
			spherecolor = Color( spherecolor["r"] + 0.5, spherecolor["g"] - 0.5, spherecolor["b"] - 0.5, 50 )
		end
	else
		spherecolor = Color( 0, 175, 175, 35 )
	end
end

function ENT:Draw()
end

if CLIENT then
	hook.Add( "HUDPaint", "spherehudpaint", function()
		//cam.Start3D()
			render.SetColorMaterial()
			render.DrawSphere( GetGlobalVector("Zone_Pos"), GetGlobalInt("Zone_Radius"), 50, 50, spherecolor )
		//cam.End3D()
	end )
end
