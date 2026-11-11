// Minimal copy of Sandbox's base_gmodentity.
// Last Battle Royale derives from "base", not Sandbox, so this base did not exist and
// every addon entity built on it failed to load ("Trying to derive entity ... from non
// existant entity base_gmodentity"): kevlar_armor from other packs, WAC seats and
// rockets, SCars parts, ... Only the functions those addons use are here.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = ""
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:SetOverlayText( text )
	self:SetNWString( "GModOverlayText", text )
end

function ENT:GetOverlayText()
	local txt = self:GetNWString( "GModOverlayText" )
	if not game.SinglePlayer() then
		local name = self:GetPlayerName()
		if name and name ~= "" then
			if txt == "" then return "- " .. name .. " -" end
			return txt .. "\n\n- " .. name .. " -"
		end
	end
	return txt
end

function ENT:SetOverlayData( data ) self.OverlayData = data end
function ENT:GetOverlayData() return self.OverlayData end

function ENT:SetPlayer( ply )
	self.Founder = ply
	if IsValid( ply ) then
		self:SetNWString( "FounderName", ply:Nick() )
		self.FounderSID = ply:SteamID64()
		self.FounderIndex = ply:UniqueID()
	else
		self:SetNWString( "FounderName", "" )
		self.FounderSID = nil
		self.FounderIndex = nil
	end
end

function ENT:GetPlayer()
	if self.Founder == nil then return NULL end
	return self.Founder
end

function ENT:GetPlayerName()
	local ply = self:GetPlayer()
	if IsValid( ply ) then return ply:Nick() end
	return self:GetNWString( "FounderName" )
end

if CLIENT then
	function ENT:BeingLookedAtByLocalPlayer()
		local lp = LocalPlayer()
		if not IsValid( lp ) then return false end
		local tr = lp:GetEyeTrace()
		return tr.Entity == self and tr.HitPos:Distance( lp:GetShootPos() ) <= 256
	end

	function ENT:DrawEntityOutline() end

	function ENT:Draw()
		self:DrawModel()
	end
end
