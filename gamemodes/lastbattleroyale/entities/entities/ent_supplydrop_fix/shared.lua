
ENT.Type 			= "anim"
ENT.PrintName 		= "Supply Drop Crate"
ENT.Author 			= "DrVrej; BlackSnow"
ENT.Contact 		= ""
ENT.Purpose 		= "I like mystery boxes!"
ENT.Instructions 	= ""
ENT.Category		= "Rust Source"

ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.AutomaticFrameAdvance = true
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:SetAutomaticFrameAdvance( bUsingAnim )
	self.AutomaticFrameAdvance = bUsingAnim
end