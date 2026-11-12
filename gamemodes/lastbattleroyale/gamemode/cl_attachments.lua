// CW 2.0 customization menu (C) with attachments as loot.
// CW 2.0 draws every attachment of the weapon the same way, owned or not, so it
// looks like you have them all. Here the menu shows only the attachments you
// own (plus the ones already mounted), and a small panel says how many you have
// for that weapon and how to mount them.

LBR = LBR or {}

local function owns( ply, name, wep )
	if ply.CWAttachments and ply.CWAttachments[name] then return true end
	if wep.ActiveAttachments and wep.ActiveAttachments[name] then return true end
	return false
end

local function filterOn()
	local cw = CustomizableWeaponry
	return cw and cw.useAttachmentPossessionSystem ~= false
end

local function patchMenu()
	local cw = CustomizableWeaponry
	if not cw or not cw.interactionMenu or not istable( cw.interactionMenu.tabs ) then return false end
	local tab
	for _, t in pairs( cw.interactionMenu.tabs ) do
		if istable( t ) and t.name == "TAB_CUSTOMIZATION" then tab = t break end
	end
	if not tab or not isfunction( tab.drawFunc ) then return false end
	if tab.LBR_Patched then return true end
	tab.LBR_Patched = true

	local orig = tab.drawFunc
	tab.drawFunc = function( wep, ... )
		if not filterOn() then return orig( wep, ... ) end
		local ply = LocalPlayer()
		local tbl = wep:GetTable()
		local prev = rawget( tbl, "isAttachmentEligible" )
		local base = wep.isAttachmentEligible
		tbl.isAttachmentEligible = function( w, name, active )
			if not owns( ply, name, w ) then return false end
			return base( w, name, active )
		end
		local ok, err = pcall( orig, wep, ... )
		tbl.isAttachmentEligible = prev
		if not ok then ErrorNoHalt( "[LBR] CW menu: " .. tostring( err ) .. "\n" ) end
	end
	return true
end

hook.Add( "InitPostEntity", "LBR_CWMenu", function()
	if patchMenu() then return end
	timer.Create( "LBR_CWMenu", 2, 10, function()
		if patchMenu() then timer.Remove( "LBR_CWMenu" ) end
	end )
end )
if IsValid( LocalPlayer() ) then patchMenu() end // lua refresh

local function countFor( ply, wep )
	local n, seen = 0, {}
	for _, cat in pairs( wep.Attachments or {} ) do
		for _, att in pairs( cat.atts or {} ) do
			if not seen[att] and ply.CWAttachments and ply.CWAttachments[att] then
				seen[att] = true
				n = n + 1
			end
		end
	end
	return n
end

hook.Add( "HUDPaint", "LBR_CWMenuHint", function()
	if not filterOn() then return end
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) or not wep.CW20Weapon or not wep.dt or not CW_CUSTOMIZE then return end
	if wep.dt.State ~= CW_CUSTOMIZE then return end
	if wep.CustomizationTab ~= CustomizableWeaponry.interactionMenu.CUSTOMIZATION_TAB then return end

	local n = countFor( ply, wep )
	local title = n > 0 and ( n .. ( n == 1 and " ATTACHMENT" or " ATTACHMENTS" ) .. " FOR THIS WEAPON" ) or "NO ATTACHMENTS FOR THIS WEAPON"
	local sub = n > 0 and "Press the category number (1, 2, 3...) to mount / change" or "Find attachment kits in the loot and pick them up with E"
	local S = LBR.UI and LBR.UI.S or function( v ) return v end
	local col = n > 0 and Color( 255, 210, 70 ) or Color( 255, 80, 70 )

	surface.SetFont( "LBR_HUD_Small" )
	local tw, th = surface.GetTextSize( title )
	surface.SetFont( "LBR_HUD_Tiny" )
	local sw, sh = surface.GetTextSize( sub )
	local w = math.max( tw, sw ) + S( 40 )
	local h = S( 14 ) + th + S( 4 ) + sh + S( 12 )
	local x, y = ScrW() / 2 - w / 2, ScrH() - S( 150 ) - h
	surface.SetDrawColor( 10, 14, 24, 205 )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( col )
	surface.DrawRect( x, y, w, S( 2 ) )
	draw.SimpleText( title, "LBR_HUD_Small", ScrW() / 2, y + S( 12 ), col, TEXT_ALIGN_CENTER )
	draw.SimpleText( sub, "LBR_HUD_Tiny", ScrW() / 2, y + S( 14 ) + th + S( 4 ), Color( 236, 239, 245 ), TEXT_ALIGN_CENTER )
end )
