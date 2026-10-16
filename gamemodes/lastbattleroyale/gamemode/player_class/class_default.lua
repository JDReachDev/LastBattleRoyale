
AddCSLuaFile()

DEFINE_BASECLASS( "player_default" )

local PLAYER = {}
PLAYER.OVPCLASSNAME			= "class_default"
PLAYER.DisplayName			= "Recruit"
PLAYER.WalkSpeed			= 1
PLAYER.RunSpeed				= 1
PLAYER.CrouchedWalkSpeed	= 0.3
PLAYER.DuckSpeed			= 0.3
PLAYER.UnDuckSpeed			= 0.3
PLAYER.JumpPower			= 200
PLAYER.CanUseFlashlight		= true
PLAYER.MaxHealth			= 100
PLAYER.StartHealth			= 100
PLAYER.StartArmor			= 0
PLAYER.DropWeaponOnDie		= false
PLAYER.TeammateNoCollide	= false
PLAYER.AvoidPlayers			= true
PLAYER.UseVMHands			= true

function PLAYER:ReturnStat(stat)
	return PLAYER[stat]
end

function PLAYER:ApplyStats()
	local pl = self.Player
	pl:SetWalkSpeed( GetGMWalkSpeed() * self.WalkSpeed )
	pl:SetRunSpeed( GetGMRunSpeed() * self.RunSpeed )
	pl:SetCrouchedWalkSpeed( self.CrouchedWalkSpeed )
	pl:SetMaxHealth( self.MaxHealth )
	pl:SetHealth( self.StartHealth )
	pl:SetJumpPower( GetGMJumpPower() )
end

function PLAYER:SaveStats()
	local pl = self.Player
	pl:SetPData(self.OVPCLASSNAME .. "_level", pl:GetLevel())
	pl:SetPData(self.OVPCLASSNAME .. "_exp", pl:GetEXP())
	pl:PrintMessage(HUD_PRINTCONSOLE, "saved stats for " .. self.DisplayName)
end

function PLAYER:Loadout()
	local pl = self.Player
	pl:RemoveAllAmmo()
	pl:StripWeapons()
	//pl:GiveAmmo( 256, 	"Pistol", 		true )
	pl:Give( "weapon_crowbar" )
end

function PLAYER:SetupDataTables()

	print("Setting up datatables for "..self.Player:Nick())
	local pl = self.Player
	pl:NetworkVar( "Int", 0, "Level" )
	pl:NetworkVar( "Int", 1, "EXP" )
	pl:NetworkVar( "String", 2, "LSTClass")
	
	if SERVER then
		pl:SetLevel( pl:GetPData( self.OVPCLASSNAME .. "_level", 0 ) )
		pl:SetEXP( pl:GetPData( self.OVPCLASSNAME .. "_exp", 0 ) )
		pl:SetLSTClass( PLAYER.DisplayName )
	end
	
end

player_manager.RegisterClass( "class_default", PLAYER, "player_default" )
