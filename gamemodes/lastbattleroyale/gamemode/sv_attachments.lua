// CW 2.0 attachments: everyone starts with none.
// CW 2.0 gives every attachment on spawn by default (one server convar per
// attachment, cw_att_<name>, all 1). In a battle royale attachments are loot:
// they come from the attachment kits (lbr_attpack_*), so here every
// cw_att_* convar is set to 0 and players lose their attachments when they die.
// lbr_cw_spawn_attachments 1 = leave CW 2.0 as it is (all attachments on spawn).

local cvKeep = CreateConVar( "lbr_cw_spawn_attachments", "0", FCVAR_ARCHIVE, "1 = CW 2.0 gives every attachment on spawn, 0 = attachments only from the attachment packs" )

local ARCCW_CVARS = {
	arccw_attinv_free = "0",
	arccw_attinv_lockmode = "1",
	arccw_attinv_loseondie = "1",
	arccw_attinv_giveonspawn = "0",
	arccw_mult_defaultammo = "0",
	arccw_atts_spawnrand = "0",
}

local function stripSpawnAttachments()
	if cvKeep:GetBool() then return end
	local cw = CustomizableWeaponry
	if not cw or not istable( cw.registeredAttachments ) then return end

	local changed = 0
	for _, att in ipairs( cw.registeredAttachments ) do
		if att.cvar and GetConVarNumber( att.cvar ) ~= 0 then
			RunConsoleCommand( att.cvar, "0" )
			changed = changed + 1
		end
	end
	if GetConVarNumber( "cw_keep_attachments_post_death" ) ~= 0 then
		RunConsoleCommand( "cw_keep_attachments_post_death", "0" )
	end
	// ArcCW: attachments from the kits only (inventory, lost on death), no free
	// extra magazines on the first deploy (ammo comes from the kits)
	for cv, v in pairs( ARCCW_CVARS ) do
		local c = GetConVar( cv )
		if c and c:GetString() ~= v then RunConsoleCommand( cv, v ) end
	end
	if changed > 0 then
		print( "[LBR] CW 2.0: " .. changed .. " attachments no longer given on spawn (lbr_cw_spawn_attachments 1 to undo)" )
	end
end

hook.Add( "InitPostEntity", "LBR_CWAttachments", function()
	stripSpawnAttachments()
	timer.Simple( 2, stripSpawnAttachments ) // attachments registered late by other packs
end )

// every round starts with nothing: take away what players still have from before
// (CW 2.0 does this on its own on spawn once the convars are 0; this covers
// players who joined before the convars changed)
hook.Add( "PlayerSpawn", "LBR_ArcCWAttachments", function( ply )
	if cvKeep:GetBool() or not ArcCW or not ply.ArcCW_AttInv then return end
	if next( ply.ArcCW_AttInv ) == nil then return end
	ply.ArcCW_AttInv = {}
	if ArcCW.PlayerSendAttInv then ArcCW:PlayerSendAttInv( ply ) end
end )

hook.Add( "PlayerSpawn", "LBR_CWAttachments", function( ply )
	if cvKeep:GetBool() then return end
	if not CustomizableWeaponry or not ply.CWAttachments then return end
	timer.Simple( 0, function()
		if not IsValid( ply ) or not ply.CWAttachments then return end
		if next( ply.CWAttachments ) == nil then return end
		for k in pairs( ply.CWAttachments ) do ply.CWAttachments[k] = nil end
		SendUserMessage( "CW20_LOSTATTACHMENTS", ply )
	end )
end )

cvars.AddChangeCallback( "lbr_cw_spawn_attachments", function( _, _, new )
	if tonumber( new ) == 0 then stripSpawnAttachments() end
end, "LBR_CWAttachments" )

// weapon bar: a new choice made while a CW 2.0 weapon is still holstering
// (CW 2.0 would otherwise keep switching to the first one chosen)
concommand.Add( "lbr_switchweapon", function( ply, _, args )
	if not IsValid( ply ) or not ply:Alive() then return end
	local wep = Entity( tonumber( args[1] ) or 0 )
	if not IsValid( wep ) or not wep:IsWeapon() or wep:GetOwner() ~= ply then return end
	local act = ply:GetActiveWeapon()
	if IsValid( act ) and act.CW20Weapon and IsValid( act.SwitchWep ) and act ~= wep then
		act.SwitchWep = wep
	end
end )
