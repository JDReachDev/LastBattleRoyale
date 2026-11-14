// Attachment kit (base of lbr_attpack_small / lbr_attpack_medium / lbr_attpack_big).
// E gives NumAtts attachments you do not have yet for the weapon in your hands
// (else for the other weapons you carry), CW 2.0 or ArcCW:
// - CW 2.0: attachments of that weapon (CustomizableWeaponry.giveAttachments);
// - ArcCW: attachments that fit a slot of that weapon (ArcCW attachment
//   inventory: arccw_attinv_free 0, set by sv_attachments.lua).
// Mount them with C (customization menu of the weapon).

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Attachment kit"
ENT.Category = "Last Battle Royale"
ENT.Spawnable = false
ENT.NumAtts = 2
ENT.Model = "models/props_c17/briefcase001a.mdl" // a briefcase: not mistaken for an ammo box
ENT.LBR_AttKit = true

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
	return
end

function ENT:Initialize()
	self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() end
end

------------------------------------------------------------------------
// CW 2.0
------------------------------------------------------------------------

local function cwMissing( ply, wep )
	local out = {}
	local cw = CustomizableWeaponry
	if not cw or not IsValid( wep ) or not wep.CW20Weapon or not istable( wep.Attachments ) then return out end
	ply.CWAttachments = ply.CWAttachments or {}
	for _, cat in pairs( wep.Attachments ) do
		for _, att in pairs( cat.atts or {} ) do
			if cw.registeredAttachmentsSKey[att] and not ply.CWAttachments[att] and not table.HasValue( out, att ) then
				out[#out + 1] = att
			end
		end
	end
	return out
end

local function cwGive( ply, list )
	local cw = CustomizableWeaponry
	cw.giveAttachments( ply, list, true )
	local names = {}
	for _, att in ipairs( list ) do
		local a = cw.registeredAttachmentsSKey[att]
		names[#names + 1] = a and ( a.displayNameShort or a.displayName ) or att
	end
	return names
end

------------------------------------------------------------------------
// ArcCW
------------------------------------------------------------------------

local function arcMissing( ply, wep )
	local out = {}
	if not ArcCW or not ArcCW.AttachmentTable or not IsValid( wep ) or not wep.ArcCW or not istable( wep.Attachments ) then return out end
	local seen = {}
	for _, slot in pairs( wep.Attachments ) do
		if istable( slot ) and slot.Slot and not slot.Integral and not slot.Hidden then
			for _, att in ipairs( ArcCW:GetAttsForSlot( slot.Slot, wep ) ) do
				local t = ArcCW.AttachmentTable[att]
				if t and not seen[att] and not t.Free and not t.InvAtt and not t.AdminOnly and not t.Hidden and not t.Blacklisted
					and ArcCW:PlayerGetAtts( ply, att ) <= 0 then
					seen[att] = true
					out[#out + 1] = att
				end
			end
		end
	end
	return out
end

local function arcGive( ply, list )
	local names = {}
	for _, att in ipairs( list ) do
		ArcCW:PlayerGiveAtt( ply, att, 1 )
		local t = ArcCW.AttachmentTable[att]
		names[#names + 1] = t and ( t.AbbrevName or t.PrintName ) or att
	end
	ArcCW:PlayerSendAttInv( ply )
	return names
end

------------------------------------------------------------------------

function ENT:Use( ply )
	if not IsValid( ply ) or not ply:IsPlayer() or not ply:Alive() or self.Taken then return end

	local weps = { ply:GetActiveWeapon() }
	for _, w in ipairs( ply:GetWeapons() ) do
		if w ~= weps[1] then weps[#weps + 1] = w end
	end

	// one weapon gets the whole kit (the first one with something missing),
	// the rest goes to the next weapons
	local cwList, arcList, forWep = {}, {}, nil
	local n = 0
	for _, w in ipairs( weps ) do
		if n >= self.NumAtts then break end
		if IsValid( w ) then
			local isArc = w.ArcCW == true
			local pool = isArc and arcMissing( ply, w ) or cwMissing( ply, w )
			local into = isArc and arcList or cwList
			while #pool > 0 and n < self.NumAtts do
				local att = table.remove( pool, math.random( #pool ) )
				if not table.HasValue( into, att ) then
					into[#into + 1] = att
					n = n + 1
					forWep = forWep or w
				end
			end
		end
	end

	if n == 0 then
		LBR.Notify( ply, "No new attachments for your weapons", "bad", 3 )
		return
	end

	self.Taken = true
	local names = {}
	if #cwList > 0 then table.Add( names, cwGive( ply, cwList ) ) end
	if #arcList > 0 then table.Add( names, arcGive( ply, arcList ) ) end
	local wname = IsValid( forWep ) and ( forWep.GetPrintName and forWep:GetPrintName() or forWep:GetClass() ) or "your weapon"
	LBR.Notify( ply, "Attachments: " .. table.concat( names, ", " ) .. "  (C on " .. wname .. " to mount them)", "good", 5 )
	ply:EmitSound( "items/ammo_pickup.wav", 60, 110 )
	self:Remove()
end
