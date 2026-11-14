
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

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "OpenStart" )
	self:NetworkVar( "Float", 1, "OpenEnd" ) // 0 = closed
	self:NetworkVar( "Entity", 0, "Opener" )
end

// 0..1 while opening, nil when closed
function ENT:OpenProgress()
	local e = self:GetOpenEnd()
	if e <= 0 then return nil end
	local s = self:GetOpenStart()
	return math.Clamp( ( CurTime() - s ) / math.max( e - s, 0.01 ), 0, 1 )
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:SetAutomaticFrameAdvance( bUsingAnim )
	self.AutomaticFrameAdvance = bUsingAnim
end
