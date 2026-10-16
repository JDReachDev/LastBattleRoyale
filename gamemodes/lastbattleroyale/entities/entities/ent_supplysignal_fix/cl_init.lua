
include("shared.lua")

function ENT:Draw() 
self:DrawModel()

	local ledcolor = Color(0,255,0,255)
  	local Position = self.Entity:GetPos() +self.Entity:GetForward()*7 +self.Entity:GetUp()*6 +self.Entity:GetRight()*2
	local Angles = self.Entity:GetAngles()
	Angles:RotateAroundAxis(Angles:Right(), Vector(0, 90, 0).x)
	Angles:RotateAroundAxis(Angles:Up(), Vector(90, 90, 90).y)
	Angles:RotateAroundAxis(Angles:Forward(), Vector(90, 90, 90).z)
end