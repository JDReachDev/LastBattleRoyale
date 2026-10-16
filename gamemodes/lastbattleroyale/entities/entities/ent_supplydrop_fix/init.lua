AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")


function ENT:Initialize()
	self:SetModel("models/blacksnow/supplycrate.mdl")
	self:SetGravity( 100 )
	self:SetHealth( 6000 )
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if phys and phys:IsValid() then
		phys:Wake()
	end
end



function ENT:PhysicsCollide(data, physobj)

end

function ENT:Use(activator, caller)
	if activator:IsPlayer() then
		self:EmitSound(Sound("items/ammopickup.wav"),70,100)
		activator:PrintMessage(HUD_PRINTTALK, "Looting...")
		activator:Freeze(true)
		timer.Simple(5, function()
			if IsValid(activator) then
				activator:Freeze(false)
			end
		end )
		timer.Create("SupplyDrop", 5, 1, function()
			local whenToUnfreeze = 5
			
			WEPS = {
				"cw_ak74",
				"cw_g4p_an94",
				"cw_g4p_m98b",
				"cw_g4p_fn_fal",
				"cw_g4p_g36c",
				"cw_g4p_m16a4",
				"cw_g4p_magpul_masada",
				"cw_g4p_masada_acr"
			}
			local rnd = math.random(1,2)
			if rnd == 1 then
				activator:Give("sg_medkit_fix")
				activator:Give("cw_frag_grenade")
				activator:Give("weapon_grenadeplacer")
				activator:Give("cw_m1911")
				activator:SetArmor(30)
				activator:SetModel("models/mw2/skin_12/MW2_Soldier_06.mdl")
				activator:EmitSound( Sound("npc/combine_soldier/zipline_clothing".. math.random(1, 2).. ".wav") )
				activator:PrintMessage(HUD_PRINTTALK, "You picked up survivalist pack")
			elseif rnd == 2 then
				local wep = table.Random( WEPS )
				activator:Give(wep)
				activator:Give("cw_g4p_fiveseven")
				activator:SelectWeapon(wep)
				activator:SetArmor(75)
				activator:SetModel("models/mw2/skin_03/MW2_Soldier_0" .. math.random(2,4) .. ".mdl")
				activator:EmitSound( Sound("npc/combine_soldier/zipline_clothing".. math.random(1, 2).. ".wav") )
				activator:PrintMessage(HUD_PRINTTALK, "You picked up battle pack")
			end
		end)
		self:Remove()
	end
end
