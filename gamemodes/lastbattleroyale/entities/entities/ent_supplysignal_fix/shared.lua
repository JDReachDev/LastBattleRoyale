
ENT.Type 			= "anim"
ENT.PrintName 		= "Supply Signal Grenade"
ENT.Author 			= "DrVrej; BlackSnow; Pook (Thanks buddy :D)"
ENT.Contact 		= ""
ENT.Purpose 		= "???"
ENT.Instructions 	= ""
ENT.Category		= "Rust Source"

ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.AutomaticFrameAdvance = true
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:SetAutomaticFrameAdvance( bUsingAnim )
	self.AutomaticFrameAdvance = bUsingAnim
end

if CLIENT then  
    function ENT:Think()
    local dlight = DynamicLight( self:EntIndex() )
	if ( dlight ) then
		local r, g, b, a = self:GetColor()
		dlight.Pos = self:GetPos()
		dlight.r = 10
		dlight.g = 255
		dlight.b = 10
		dlight.Brightness = 2
		dlight.Size = 256
		dlight.Decay = 1000
		dlight.DieTime = 300
	end
end
end 