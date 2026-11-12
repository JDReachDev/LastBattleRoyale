// Placeholder for Sandbox's tool gun.
// Last Battle Royale derives from "base", not Sandbox. Addons with tools (SCars,
// WAC, ...) put files in weapons/gmod_tool/stools/, so the game finds a
// weapons/gmod_tool folder without its shared.lua and prints at every start:
// "AddCSLuaFile: Couldn't find 'weapons/gmod_tool/shared.lua'".
// This file only makes that folder a valid weapon: nobody gets it, it does nothing
// and the tools of those addons are not loaded (they are Sandbox tools).

AddCSLuaFile()

SWEP.PrintName = "Tool Gun"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.UseHands = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
