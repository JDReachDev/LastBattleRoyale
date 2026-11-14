// TAB scoreboard. Original by Kanade, redone in the style of the HUD.
//  header : server name, map, match state, players alive
//  rows   : avatar, name (squad mates in gold), rank, class + level, round kills, ping
//  click  : enables the mouse; right click on a player: mute / profile / copy SteamID
// Health is not shown on purpose (no free info about enemies).

TEAM_PLAYER = 1
TEAM_CONT = 2
TEAM_SPEC = 3

local UI = LBR.UI
local S = UI.S
local C = UI.col

local usergroups = {
	owner = "Owner",
	superadmin = "Super Admin",
	testadmin = "Test Admin",
	admin = "Admin",
	moderator = "Moderator",
	testmoderator = "Test Moderator",
	testmod = "Test Mod",
	operator = "Operator",
	donator = "Donator",
	vip = "Vip",
	veteran = "Veteran",
	founder = "Founder",
	creator = "Creator"
}

// please do not change this, be a good person
local donators = {
	{"76561198098529139", Color(255,255,0)}, // LionM
	{"76561198046774227", Color(0,255,0)},
	{"76561198156389563", Color(242,20,70)},
	{"76561198124708739", Color(0,255,242)} // GPX- Demo
}
local creators = { ["STEAM_0:0:46273348"] = true, ["STEAM_0:1:98061917"] = true } // Last Stand

local donatorColor = {}
for _, d in ipairs( donators ) do donatorColor[d[1]] = d[2] end

local rankIcons = {}
for i = 1, 4 do rankIcons[i] = Material( "zpicons/rank" .. i .. ".png", "smooth" ) end
local function rankIcon( lvl )
	if lvl >= 50 then return rankIcons[4] end
	if lvl >= 25 then return rankIcons[3] end
	if lvl >= 10 then return rankIcons[2] end
	return rankIcons[1]
end

local stateNames = { "LOBBY", "MATCH STARTING", "IN GAME", "ROUND OVER" }

local function isMate( ply )
	local sid = ply:SteamID64()
	for _, s in ipairs( TEAMERSTAB or {} ) do
		if s == sid then return true end
	end
	return false
end

local function tagOf( ply )
	if creators[ply:SteamID()] then return "Last Stand Creator", C.accent end
	local g = usergroups[ply:GetUserGroup()]
	if g then return g, C.blue end
	if donatorColor[ply:SteamID64() or ""] then return "Donator", donatorColor[ply:SteamID64()] end
end

local function levelOf( ply )
	if ply.GetLevel == nil or ply.GetLSTClass == nil then
		player_manager.RunClass( ply, "SetupDataTables" )
	end
	local lvl = ply.GetLevel and ply:GetLevel() or 0
	local cls = ply.GetLSTClass and ply:GetLSTClass() or ""
	return lvl or 0, cls or ""
end

local Board

local function playerMenu( ply )
	if not IsValid( ply ) then return end
	local m = DermaMenu()
	if ply ~= LocalPlayer() and not ply:IsBot() then
		m:AddOption( ply:IsMuted() and "Unmute" or "Mute", function()
			if IsValid( ply ) then ply:SetMuted( not ply:IsMuted() ) end
		end ):SetIcon( ply:IsMuted() and "icon16/sound.png" or "icon16/sound_mute.png" )
	end
	if not ply:IsBot() then
		m:AddOption( "Steam profile", function() if IsValid( ply ) then ply:ShowProfile() end end ):SetIcon( "icon16/user.png" )
		m:AddOption( "Copy SteamID", function() if IsValid( ply ) then SetClipboardText( ply:SteamID() ) end end ):SetIcon( "icon16/page_copy.png" )
	end
	m:Open()
end

// columns from the right edge: { label, width }
local COLS = { { "PING", 60 }, { "KILLS", 70 }, { "CLASS", 190 } }

local function colX( w, i )
	local x = w - S( 14 )
	for k = 1, i - 1 do x = x - S( COLS[k][2] ) end
	return x
end

local function addRow( parent, ply, section )
	local row = vgui.Create( "DButton", parent )
	row:SetText( "" )
	row:Dock( TOP )
	row:SetTall( S( 40 ) )
	row:DockMargin( 0, 0, 0, S( 3 ) )
	row.ply = ply

	local av = vgui.Create( "AvatarImage", row )
	av:SetSize( S( 32 ), S( 32 ) )
	av:SetPos( S( 10 ), S( 4 ) )
	av:SetPlayer( ply, 64 )
	av:SetMouseInputEnabled( false )

	row.DoRightClick = function( self ) playerMenu( self.ply ) end
	row.DoClick = function( self ) playerMenu( self.ply ) end

	row.Paint = function( self, w, h )
		local p = self.ply
		if not IsValid( p ) then return end
		local me = p == LocalPlayer()
		local mate = not me and isMate( p )
		local dead = section == TEAM_CONT and not p:Alive()

		UI.Box( 0, 0, w, h, self:IsHovered() and C.rowHover or C.row )
		if me then
			UI.Accent( 0, 0, h, C.text )
		elseif mate then
			UI.Accent( 0, 0, h, C.accent )
		end

		// name + tag
		local nameCol = donatorColor[p:SteamID64() or ""] or ( mate and C.accent or C.text )
		if dead then nameCol = C.dim end
		local x = S( 52 )
		local maxName = colX( w, #COLS + 1 ) - x - S( 10 )
		local tag, tagCol = tagOf( p )
		local nameY = tag and h / 2 - S( 8 ) or h / 2
		UI.Text( UI.Fit( p:Nick(), "LBR_UI_Text", maxName ), "LBR_UI_Text", x, nameY, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		if tag then
			UI.Text( string.upper( tag ), "LBR_UI_Tiny", x, h / 2 + S( 9 ), tagCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end
		if p:IsMuted() then
			surface.SetFont( "LBR_UI_Text" )
			local nw = surface.GetTextSize( UI.Fit( p:Nick(), "LBR_UI_Text", maxName ) )
			UI.Text( "MUTED", "LBR_UI_Tiny", x + nw + S( 8 ), nameY, C.bad, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end

		// class + level
		local lvl, cls = levelOf( p )
		local cx = colX( w, 3 ) - S( COLS[3][2] ) + S( 10 )
		local isz = S( 20 )
		surface.SetMaterial( rankIcon( lvl ) )
		surface.SetDrawColor( 255, 255, 255, dead and 120 or 255 )
		surface.DrawTexturedRect( cx, h / 2 - isz / 2, isz, isz )
		UI.Text( UI.Fit( cls, "LBR_UI_Small", S( COLS[3][2] ) - S( 70 ) ), "LBR_UI_Small", cx + isz + S( 6 ), h / 2, dead and C.dim or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		UI.Text( "LV " .. lvl, "LBR_UI_Tiny", colX( w, 3 ), h / 2, C.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

		// kills this round (total frags in the lobby)
		local kills = section == TEAM_PLAYER and p:Frags() or p:GetNW2Int( "LBR_Kills", 0 )
		if dead then
			surface.SetMaterial( UI.matSkull )
			surface.SetDrawColor( 255, 255, 255, 160 )
			surface.DrawTexturedRect( colX( w, 2 ) - S( 52 ), h / 2 - S( 8 ), S( 16 ), S( 16 ) )
		end
		UI.Text( tostring( kills ), "LBR_UI_Text", colX( w, 2 ) - S( 14 ), h / 2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

		// ping
		local ping = p:Ping()
		local pingCol = p:IsBot() and C.dim or ( ping < 80 and C.good or ( ping < 175 and C.accent or C.bad ) )
		UI.Text( p:IsBot() and "BOT" or tostring( ping ), "LBR_UI_Small", colX( w, 1 ), h / 2, pingCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end
	return row
end

local function sortPlayers( list )
	table.sort( list, function( a, b )
		if a:Alive() ~= b:Alive() then return a:Alive() end
		local ka, kb = a:GetNW2Int( "LBR_Kills", 0 ), b:GetNW2Int( "LBR_Kills", 0 )
		if ka ~= kb then return ka > kb end
		return a:Nick():lower() < b:Nick():lower()
	end )
	return list
end

local sections = {
	{ TEAM_CONT, "In game" },
	{ TEAM_PLAYER, "Lobby" },
	{ TEAM_SPEC, "Spectators" },
}

// list of players by team, as a string: rebuild the rows only when it changes
local function signature()
	local t = {}
	for _, p in ipairs( player.GetAll() ) do t[#t + 1] = p:EntIndex() .. ":" .. p:Team() end
	table.sort( t )
	return table.concat( t, "," )
end

local function fillList( list )
	list:Clear()
	for _, sec in ipairs( sections ) do
		local players = sortPlayers( team.GetPlayers( sec[1] ) )
		if #players > 0 then
			local col = sec[1] == TEAM_CONT and C.good or ( sec[1] == TEAM_SPEC and C.dim or C.accent )
			UI.Section( list:GetCanvas(), sec[2], function() return #team.GetPlayers( sec[1] ) end, col )
			for _, p in ipairs( players ) do
				addRow( list:GetCanvas(), p, sec[1] )
			end
		end
	end
end

local function aliveCount()
	local n = 0
	for _, p in ipairs( team.GetPlayers( TEAM_CONT ) ) do
		if p:Alive() then n = n + 1 end
	end
	return n
end

// ---------------------------------------------------------------------------
// right side: inventory (sh_inventory.lua), your stats, menu buttons
// ---------------------------------------------------------------------------

local function weaponName( wep )
	local name = wep.GetPrintName and wep:GetPrintName() or wep:GetClass()
	if string.sub( name, 1, 1 ) == "#" then name = language.GetPhrase( string.sub( name, 2 ) ) end
	return string.upper( name )
end

// rounds in the weapon (nil: no magazine) and spare rounds (nil: no ammo at all)
local function ammoOf( wep )
	local clip = wep:Clip1()
	local ammoType = LBR.WeaponAmmoID( wep )
	local reserve = ammoType >= 0 and LocalPlayer():GetAmmoCount( ammoType ) or nil
	return clip >= 0 and clip or nil, reserve
end

// "6 / 40": the rounds in the weapon bright, the spare rounds dim after the slash
// (red when 0). Drawn from x; returns its width (measure only when doDraw is false)
local function drawAmmo( wep, x, y, numCol, alignY, doDraw )
	local clip, spare = ammoOf( wep )
	if not clip and not spare then return 0 end
	local first = clip or spare
	local rest = clip and spare and ( " / " .. spare ) or ""
	surface.SetFont( "LBR_UI_Small" )
	local fw = surface.GetTextSize( tostring( first ) )
	surface.SetFont( "LBR_UI_Tiny" )
	local rw = rest ~= "" and surface.GetTextSize( rest ) or 0
	if doDraw ~= false then
		UI.Text( tostring( first ), "LBR_UI_Small", x, y, first <= 0 and C.bad or numCol, TEXT_ALIGN_LEFT, alignY )
		if rest ~= "" then UI.Text( rest, "LBR_UI_Tiny", x + fw, y, spare <= 0 and C.bad or C.dim, TEXT_ALIGN_LEFT, alignY ) end
	end
	return fw + rw
end

// weapon icons: CW 2.0 weapons use a letter of the Counter-Strike icon font
// (IconLetter) or their own texture (SelectIcon); other weapons their
// selection texture or spawn menu icon. Returns false when there is none.
local function createIconFonts()
	surface.CreateFont( "LBR_InvIcon", { font = "csd", size = S( 44 ), weight = 500, antialias = true } )
	surface.CreateFont( "LBR_InvIconS", { font = "csd", size = S( 30 ), weight = 500, antialias = true } )
	surface.CreateFont( "LBR_InvIcon2", { font = "HalfLife2", size = S( 40 ), weight = 500, antialias = true } )
	surface.CreateFont( "LBR_InvIcon2S", { font = "HalfLife2", size = S( 28 ), weight = 500, antialias = true } )
end
createIconFonts()

// The icon letters do not sit in the middle of their line (each one is placed
// differently in the font), so centering the text puts them off. Each letter is
// drawn once in a hidden render target and its real edges are measured, then it
// is drawn with its own middle on the middle of the slot.
local letterBox = {} // letter .. font -> { x, y, w, h } from the text position
local measureQueue = {}
local queued = {}
local measureRT

local function measureLetter( letter, font )
	measureRT = measureRT or GetRenderTarget( "LBR_IconMeasure", 512, 256 )
	surface.SetFont( font )
	local tw, th = surface.GetTextSize( letter )
	local pad = 16
	render.PushRenderTarget( measureRT )
	render.Clear( 0, 0, 0, 255, true, true )
	cam.Start2D()
		surface.SetFont( font )
		surface.SetTextColor( 255, 255, 255, 255 )
		surface.SetTextPos( pad, pad )
		surface.DrawText( letter )
	cam.End2D()
	render.CapturePixels()
	local x1, y1, x2, y2 = math.huge, math.huge, -1, -1
	local maxX, maxY = math.min( 511, pad + tw + 8 ), math.min( 255, pad + th + 8 )
	for y = 0, maxY do
		for x = 0, maxX do
			local r = render.ReadPixel( x, y )
			if r and r > 80 then
				if x < x1 then x1 = x end
				if x > x2 then x2 = x end
				if y < y1 then y1 = y end
				if y > y2 then y2 = y end
			end
		end
	end
	render.PopRenderTarget()
	if x2 < 0 then return { x = 0, y = 0, w = tw, h = th } end // nothing drawn: use the text box
	return { x = x1 - pad, y = y1 - pad, w = x2 - x1 + 1, h = y2 - y1 + 1 }
end

// measured in HUDPaint (a clean 2D pass), a few per frame
hook.Add( "HUDPaint", "LBR_InvIconMeasure", function()
	for i = 1, 2 do
		local job = table.remove( measureQueue, 1 )
		if not job then return end
		local key = job[1] .. job[2]
		if not letterBox[key] then letterBox[key] = measureLetter( job[1], job[2] ) end
	end
end )

hook.Add( "OnScreenSizeChanged", "LBR_InvIconFonts", function()
	createIconFonts()
	letterBox = {}
	queued = {}
end )

local function boxOf( letter, font )
	local key = letter .. font
	local b = letterBox[key]
	if b then return b end
	if not queued[key] then
		queued[key] = true
		measureQueue[#measureQueue + 1] = { letter, font }
	end
end

local hl2Letters = {
	weapon_pistol = "d", weapon_357 = "e", weapon_smg1 = "a", weapon_ar2 = "l",
	weapon_shotgun = "b", weapon_crossbow = "g", weapon_rpg = "i", weapon_frag = "k",
	weapon_slam = "o", weapon_bugbait = "j", weapon_crowbar = "c", weapon_stunstick = "n",
}
local defaultSelect = surface.GetTextureID( "weapons/swep" )
local iconCache = {}

local function iconOf( wep )
	local class = wep:GetClass()
	local c = iconCache[class]
	if c then return c end
	if isnumber( wep.SelectIcon ) and wep.SelectIcon > 0 then
		c = { tex = wep.SelectIcon }
	elseif isstring( wep.IconLetter ) and wep.IconLetter ~= "" then
		c = { letter = wep.IconLetter, font = wep.SelectFont == "CW_SelectIcons2" and "LBR_InvIcon2" or "LBR_InvIcon" }
	elseif hl2Letters[class] then
		c = { letter = hl2Letters[class], font = "LBR_InvIcon2" }
	elseif isnumber( wep.WepSelectIcon ) and wep.WepSelectIcon > 0 and wep.WepSelectIcon ~= defaultSelect then
		c = { tex = wep.WepSelectIcon, color = true }
	else
		local m = Material( "entities/" .. class .. ".png", "smooth" )
		c = m:IsError() and { none = true } or { mat = m }
	end
	// big letter, then a small one if the big one does not fit the slot
	if c.letter then c.fonts = { c.font, c.font .. "S" } end
	iconCache[class] = c
	return c
end

local function drawWeaponIcon( wep, x, y, w, h, col )
	local c = iconOf( wep )
	if c.none then return false end
	if c.letter then
		local font, b
		for _, f in ipairs( c.fonts ) do
			local fb = boxOf( c.letter, f )
			if not fb then return true end // measured in a moment
			font, b = f, fb
			if fb.w <= w and fb.h <= h then break end
		end
		UI.Text( c.letter, font, math.floor( x + w / 2 - ( b.x + b.w / 2 ) ), math.floor( y + h / 2 - ( b.y + b.h / 2 ) ), col )
		return true
	end
	local s = h
	if c.tex then
		surface.SetTexture( c.tex )
		if c.color then surface.SetDrawColor( 255, 255, 255, col.a or 255 ) else surface.SetDrawColor( col ) end
	else
		surface.SetMaterial( c.mat )
		surface.SetDrawColor( 255, 255, 255, col.a or 255 )
	end
	surface.DrawTexturedRect( x + ( w - s ) / 2, y, s, s )
	return true
end
LBR.DrawWeaponIcon = drawWeaponIcon // weapon bar (cl_weaponselect.lua)

// small backpack symbol for the backpack slots
local function drawBag( x, y, s, col )
	local t = math.max( 2, math.floor( s / 12 ) )
	surface.SetDrawColor( col )
	surface.DrawOutlinedRect( x + s * 0.34, y + s * 0.04, s * 0.32, s * 0.2, t ) // handle
	draw.RoundedBox( math.floor( s * 0.16 ), x + s * 0.14, y + s * 0.2, s * 0.72, s * 0.78, col ) // body
	draw.RoundedBox( math.floor( s * 0.08 ), x + s * 0.28, y + s * 0.6, s * 0.44, s * 0.26, Color( 10, 14, 24, 200 ) ) // pocket
	surface.SetDrawColor( 10, 14, 24, 200 )
	surface.DrawRect( x + s * 0.14, y + s * 0.42, s * 0.72, t ) // flap
end

local function inGame()
	local lp = LocalPlayer()
	return IsValid( lp ) and lp:Alive() and lp:Team() == TEAM_CONT
end

local function sideHeader( parent, label, rightFn )
	local p = vgui.Create( "DPanel", parent )
	p:Dock( TOP )
	p:SetTall( S( 20 ) )
	p:DockMargin( 0, S( 6 ), 0, S( 4 ) )
	p.Paint = function( self, w, h )
		surface.SetFont( "LBR_UI_Tiny" )
		local tw = surface.GetTextSize( label )
		UI.Text( label, "LBR_UI_Tiny", 0, h / 2, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		local r = rightFn and rightFn() or ""
		local rw = 0
		if r ~= "" then
			rw = surface.GetTextSize( r ) + S( 10 )
			UI.Text( r, "LBR_UI_Tiny", w, h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
		UI.Box( tw + S( 10 ), h / 2, w - tw - S( 10 ) - rw, 1, C.line )
	end
	return p
end

// the magazine stores (sh_clips.lua): one tile per color, right click to drop
// one magazine, the part after the point or all of them in a box on the ground
local function clipRow( parent )
	local row = vgui.Create( "DPanel", parent )
	row:Dock( TOP )
	row:SetTall( S( 40 ) )
	row:DockMargin( 0, 0, 0, S( 4 ) )
	row.Paint = nil
	local tiles = {}
	for i, color in ipairs( LBR.ClipColors() ) do
		local t = LBR.TierById[color]
		local b = vgui.Create( "DButton", row )
		b:SetText( "" )
		tiles[i] = b
		local function have() return LBR.GetClips( LocalPlayer(), color ) end
		b.DoRightClick = function()
			local n = have()
			if n <= 0 then return end
			local function send( what )
				net.Start( "LBR_ClipDrop" )
				net.WriteString( color )
				net.WriteUInt( what, 2 )
				net.SendToServer()
				surface.PlaySound( "ui/buttonclick.wav" )
			end
			local m = DermaMenu()
			local whole = math.floor( n + 0.0001 )
			local rest = n - whole
			local o = m:AddOption( "Drop one magazine", function() send( 1 ) end )
			o:SetIcon( "icon16/arrow_down.png" )
			if n < 1 then o:SetEnabled( false ) end
			o = m:AddOption( "Drop the rest (x" .. LBR.ClipText( rest ) .. ")", function() send( 2 ) end )
			o:SetIcon( "icon16/arrow_down.png" )
			if rest < 0.0001 then o:SetEnabled( false ) end
			m:AddOption( "Drop all (x" .. LBR.ClipText( n ) .. ")", function() send( 3 ) end ):SetIcon( "icon16/box.png" )
			m:Open()
		end
		b.Paint = function( self, w, h )
			local n = have()
			local c = t.color
			UI.Box( 0, 0, w, h, self:IsHovered() and C.rowHover or C.row )
			UI.Box( 0, 0, w, h, Color( c.r, c.g, c.b, 22 ) )
			UI.Box( 0, h - S( 3 ), w, S( 3 ), c )
			local isz = S( 24 )
			LBR.DrawClipIcon( S( 10 ), math.floor( ( h - isz ) / 2 ), isz, c, n > 0 and 255 or 90, n )
			local txt = "x" .. LBR.ClipText( n )
				UI.Text( txt, "LBR_UI_Text", S( 10 ) + isz + S( 6 ), h / 2, n > 0 and c or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				// the limit of the color, dim after it
				surface.SetFont( "LBR_UI_Text" )
				local tw = surface.GetTextSize( txt )
				UI.Text( LBR.ClipLimitText( color ), "LBR_UI_Tiny", S( 10 ) + isz + S( 6 ) + tw, h / 2 + S( 1 ), LBR.ClipRoom( LocalPlayer(), color ) < 0.0001 and C.bad or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end
	end
	row.PerformLayout = function( self, w, h )
		local gap = S( 4 )
		local bw = math.floor( ( w - gap * ( #tiles - 1 ) ) / math.max( #tiles, 1 ) )
		for i, b in ipairs( tiles ) do
			b:SetPos( ( i - 1 ) * ( bw + gap ), 0 )
			b:SetSize( bw, h )
		end
	end
	return row
end

// a tile dropped outside the inventory (rest of the board, the drop zone, the
// game): the weapon is dropped. Panels with this receiver get LBR_DropTarget, so
// the drop zone lights up whenever letting go would drop.
local DROP_RED = Color( 235, 70, 70 )
local function invDropReceiver( self, panels, dropped )
	if not dropped then return end
	local src = panels[1]
	if not IsValid( src ) or not src.GetSlot or not src.Weapon or not IsValid( src:Weapon() ) then return end
	net.Start( "LBR_InvDrop" )
	net.WriteUInt( src:GetSlot(), 4 )
	net.SendToServer()
	surface.PlaySound( "ui/buttonclick.wav" )
end
local function makeDropTarget( pnl )
	pnl:Receiver( "LBR_Inv", invDropReceiver )
	pnl.LBR_DropTarget = true
end
local function draggingWeapon()
	if not dragndrop.IsDragging() then return false end
	local d = dragndrop.GetDroppable( "LBR_Inv" )
	local src = d and d[1]
	return IsValid( src ) and src.Weapon and IsValid( src:Weapon() )
end

// one inventory slot: drag it on another slot to swap, drag it out to drop it,
// right click for the menu (unload its ammo in a box / drop the weapon)
local function invTile( parent, slot )
	local t = vgui.Create( "DButton", parent )
	t:SetText( "" )
	t:Dock( TOP )
	t:SetTall( S( 52 ) )
	t:DockMargin( 0, 0, 0, S( 3 ) )
	t.Slot = slot
	t:Droppable( "LBR_Inv" )
	t:Receiver( "LBR_Inv", function( self, panels, dropped )
		self.DropHover = not dropped
		if not dropped then return end
		local src = panels[1]
		if not IsValid( src ) or src == self or not src.GetSlot then return end
		net.Start( "LBR_InvMove" )
		net.WriteUInt( src:GetSlot(), 4 )
		net.WriteUInt( self:GetSlot(), 4 )
		net.SendToServer()
		LocalPlayer():EmitSound( "weapons/shotgun/shotgun_cock.wav", 0, 110, 0.45, CHAN_STATIC ) // weapon handling sound
	end )
	t.Weapon = function( self )
		if not inGame() then return end
		return LBR.InvGet( LocalPlayer() )[self:GetSlot()]
	end
	// backpack tiles come after the equipment: their slot moves with lbr_inv_equipment
	t.GetSlot = function( self )
		return self.BagIndex and LBR.INV_EQUIP + self.BagIndex or self.Slot
	end
	t.DoRightClick = function( self )
		local wep = self:Weapon()
		if not IsValid( wep ) then return end
		local slot = self:GetSlot()
		local function send( msg )
			net.Start( msg )
			net.WriteUInt( slot, 4 )
			net.SendToServer()
			surface.PlaySound( "ui/buttonclick.wav" )
		end
		local m = DermaMenu()
		// weapons with a magazine: the rounds in it go back in the magazine store
		if LBR.UsesMagazines( wep ) then
			local n = LBR.ClipValueOfLoaded( wep )
			local t = LBR.TierById[LBR.ClipColorOf( wep )]
			local o = m:AddOption( "Unload (+" .. LBR.ClipText( n ) .. " " .. ( t and t.name or "" ) .. " magazine)", function() send( "LBR_InvUnload" ) end )
			o:SetIcon( "icon16/box.png" )
			if wep:Clip1() <= 0 then o:SetEnabled( false ) end
			m:AddSpacer()
		end
		// drop last and in red: the one you don't want to click by mistake
		local d = m:AddOption( "Drop weapon", function() send( "LBR_InvDrop" ) end )
		d:SetIcon( "icon16/arrow_down.png" )
		d:SetTextColor( DROP_RED )
		m:Open()
	end
	t.Paint = function( self, w, h )
		local wep = self:Weapon()
		local bag = self.BagIndex ~= nil
		local active = IsValid( wep ) and wep == LocalPlayer():GetActiveWeapon()
		local hover = self:IsHovered() or self.DropHover
		self.DropHover = false
		UI.Box( 0, 0, w, h, hover and C.rowHover or C.row )
		if active then UI.Accent( 0, 0, h, C.accent ) end
		if self:IsDragging() then UI.Box( 0, 0, w, h, Color( 255, 210, 70, 25 ) ) end

		// small tiles (many slots): name and ammo on one line
		local compact = h < S( 42 )
		// left: key you press (equipment) or a backpack (backpack)
		local ks = math.min( S( 28 ), h - S( 6 ) )
		local kx, ky = S( 10 ), math.floor( ( h - ks ) / 2 )
		if bag then
			drawBag( kx, ky, ks, IsValid( wep ) and C.dim or Color( C.dim.r, C.dim.g, C.dim.b, 90 ) )
		else
			local kc = active and C.accent or ( IsValid( wep ) and C.text or C.dim )
			surface.SetDrawColor( kc.r, kc.g, kc.b, IsValid( wep ) and 200 or 70 )
			surface.DrawOutlinedRect( kx, ky, ks, ks, 2 )
			UI.Text( tostring( self.Slot ), "LBR_UI_Text", kx + ks / 2, h / 2, Color( kc.r, kc.g, kc.b, IsValid( wep ) and 255 or 90 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		if not IsValid( wep ) then
			UI.Text( "EMPTY", "LBR_UI_Tiny", S( 56 ), h / 2, Color( C.dim.r, C.dim.g, C.dim.b, 90 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			return
		end

		// tier: colored tint + stripe on the right edge
		local tc = LBR.TierColor( wep )
		if tc then
			UI.Box( 0, 0, w, h, Color( tc.r, tc.g, tc.b, 22 ) )
			UI.Box( w - S( 4 ), 0, S( 4 ), h, tc )
		end

		// weapon icon
		local ix, iw = S( 50 ), S( 120 )
		drawWeaponIcon( wep, ix, S( 4 ), iw, h - S( 8 ), tc or ( active and C.accent or C.text ) ) // tier color first: gold on purple is unreadable
		local tx = ix + iw + S( 12 ) // same column for every slot, icon or not

		// name + ammo
		local clip, spare = ammoOf( wep )
		local hasAmmo = clip or spare
		local nameCol = tc or ( active and C.accent or C.text )
		if compact then
			// ammo first (right side), the name gets the room left
			local ax = w - S( 14 ) - drawAmmo( wep, 0, 0, C.text, TEXT_ALIGN_CENTER, false ) - S( 8 )
			if hasAmmo then drawAmmo( wep, ax + S( 8 ), h / 2, C.text, TEXT_ALIGN_CENTER ) end
			UI.Text( UI.Fit( weaponName( wep ), "LBR_UI_Small", ( hasAmmo and ax or w ) - tx - S( 10 ) ), "LBR_UI_Small", tx, h / 2, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		else
			UI.Text( UI.Fit( weaponName( wep ), "LBR_UI_Small", w - tx - S( 10 ) ), "LBR_UI_Small", tx, h / 2 - ( hasAmmo and S( 8 ) or 0 ), nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			if hasAmmo then drawAmmo( wep, tx, h / 2 + S( 9 ), C.text, TEXT_ALIGN_CENTER ) end
		end
	end
	return t
end

local function buildSide( f )
	local side = vgui.Create( "DPanel", f )
	side:Dock( RIGHT )
	side:SetWide( math.min( S( 560 ), math.floor( f:GetWide() * 0.5 ) ) )
	side:DockMargin( S( 16 ), 0, 0, 0 )
	side.Paint = nil
	// let go between the tiles (headers, magazines, stats): nothing happens
	side:Receiver( "LBR_Inv", function() end )

	// buttons at the bottom
	local btns = vgui.Create( "DPanel", side )
	btns:Dock( BOTTOM )
	btns:SetTall( S( 32 ) )
	btns:DockMargin( 0, S( 8 ), 0, 0 )
	btns.Paint = nil
	local list = {
		UI.Button( btns, "CLASSES  F3", C.accent, function() ShowClassMenu() end ),
		UI.Button( btns, "SQUAD  F4", C.blue, function() ShowTeamMenu() end ),
		UI.Button( btns, "MAP  M", C.good, function()
			GAMEMODE:ScoreboardHide() // the map (cl_map.lua) is drawn under the board
			if LBR.Map then LBR.Map.Toggle( true ) end
		end ),
		UI.Button( btns, "CHANGE LEVEL  F2", C.bad, function() if LBR.OpenMapMenu then LBR.OpenMapMenu() end end ),
	}
	btns.Think = function( self )
		local admin = LocalPlayer():IsAdmin()
		if list[4]:IsVisible() ~= admin then
			list[4]:SetVisible( admin )
			self:InvalidateLayout()
		end
	end
	btns.PerformLayout = function( self, w, h )
		local shown = {}
		for _, b in ipairs( list ) do
			if b:IsVisible() then shown[#shown + 1] = b end
		end
		local gap = S( 6 )
		local bw = math.floor( ( w - gap * ( #shown - 1 ) ) / #shown )
		for i, b in ipairs( shown ) do
			b:SetPos( ( i - 1 ) * ( bw + gap ), 0 )
			b:SetSize( bw, h )
		end
	end

	// stats
	local stats = vgui.Create( "DPanel", side )
	stats:Dock( BOTTOM )
	stats:SetTall( S( 92 ) )
	stats.Paint = function( self, w, h )
		local lp = LocalPlayer()
		if not IsValid( lp ) then return end
		UI.Box( 0, 0, w, h, C.row )
		local lvl, cls = levelOf( lp )
		local pad = S( 12 )
		local isz = S( 28 )
		surface.SetMaterial( rankIcon( lvl ) )
		surface.SetDrawColor( 255, 255, 255, 255 )
		surface.DrawTexturedRect( pad, S( 10 ), isz, isz )
		UI.Text( UI.Fit( string.upper( cls ~= "" and cls or "No class" ), "LBR_UI_Head", w * 0.55 ), "LBR_UI_Head", pad + isz + S( 8 ), S( 8 ), C.text )
		UI.Text( "LEVEL " .. lvl, "LBR_UI_Tiny", pad + isz + S( 8 ), S( 31 ), C.accent )
		// EXP to the next level
		local cv = GetConVar( "lbr_level_exp" )
		local need = ( lvl + 1 ) * ( cv and cv:GetInt() or 25 )
		local exp = lp.GetEXP and lp:GetEXP() or 0
		UI.Text( math.floor( exp ) .. " / " .. need .. " EXP", "LBR_UI_Tiny", w - pad, S( 31 ), C.dim, TEXT_ALIGN_RIGHT )
		UI.Bar( pad, S( 48 ), w - pad * 2, S( 5 ), need > 0 and exp / need or 0, C.accent )
		// numbers
		local vals = {
			{ "ROUND KILLS", lp:GetNW2Int( "LBR_Kills", 0 ) },
			{ "TOTAL KILLS", lp:Frags() },
			{ "DEATHS", lp:Deaths() },
		}
		local cw = ( w - pad * 2 ) / #vals
		surface.SetFont( "LBR_UI_Text" )
		for i, v in ipairs( vals ) do
			local x = pad + ( i - 1 ) * cw
			local vw = surface.GetTextSize( tostring( v[2] ) )
			UI.Text( tostring( v[2] ), "LBR_UI_Text", x, S( 62 ), C.text )
			UI.Text( v[1], "LBR_UI_Tiny", x + vw + S( 6 ), S( 66 ), C.dim )
			surface.SetFont( "LBR_UI_Text" )
		end
	end
	sideHeader( side, "STATS" ):Dock( BOTTOM )

	// inventory
	local inv = vgui.Create( "DPanel", side )
	inv:Dock( FILL )
	inv.Paint = function( self, w, h )
		if inGame() then return end
		UI.Text( "Your inventory shows here during the match", "LBR_UI_Small", w / 2, S( 80 ), C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	local tiles = {}
	// slot counts come from lbr_inv_equipment / lbr_inv_backpack: tiles are made for
	// the maximum and the extra ones hidden
	local function count( bag )
		return function()
			local n = 0
			local items = inGame() and LBR.InvGet( LocalPlayer() ) or {}
			local from, to = 1, LBR.INV_EQUIP
			if bag then from, to = LBR.INV_EQUIP + 1, LBR.INV_SLOTS end
			for s = from, to do if IsValid( items[s] ) then n = n + 1 end end
			return n .. " / " .. ( to - from + 1 )
		end
	end
	local heads = {}
	heads[3] = sideHeader( inv, "MAGAZINES" )
	heads[3]:DockMargin( 0, 0, 0, S( 4 ) )
	local clips = clipRow( inv )
	heads[1] = sideHeader( inv, "EQUIPMENT", count( false ) )
	local equipTiles, bagTiles = {}, {}
	for s = 1, LBR.INV_EQUIP_MAX do equipTiles[s] = invTile( inv, s ) end
	heads[2] = sideHeader( inv, "BACKPACK", count( true ) )
	for k = 1, LBR.INV_BAG_MAX do
		bagTiles[k] = invTile( inv, LBR.INV_EQUIP + k )
		bagTiles[k].BagIndex = k
	end
	local hint = vgui.Create( "DPanel", inv )
	hint:Dock( TOP )
	hint:SetTall( S( 18 ) )
	hint.Paint = function( self, w, h )
		UI.Text( "Drag to move / out to drop  -  Right click: unload / drop  -  1-" .. LBR.INV_EQUIP .. " in hand", "LBR_UI_Tiny", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	local lastE, lastB, lastH
	inv.Think = function( self )
		local show = inGame()
		local function vis( p, v ) if p:IsVisible() ~= v then p:SetVisible( v ) end end
		vis( hint, show )
		vis( heads[1], show )
		vis( heads[3], show )
		vis( clips, show )
		vis( heads[2], show and LBR.INV_BAG > 0 )
		for s, t in ipairs( equipTiles ) do vis( t, show and s <= LBR.INV_EQUIP ) end
		for k, t in ipairs( bagTiles ) do vis( t, show and k <= LBR.INV_BAG ) end
		// many slots: smaller tiles so they all fit
		local h = self:GetTall()
		if LBR.INV_EQUIP ~= lastE or LBR.INV_BAG ~= lastB or h ~= lastH then
			lastE, lastB, lastH = LBR.INV_EQUIP, LBR.INV_BAG, h
			// hint + MAGAZINES header and row + EQUIPMENT (+ BACKPACK) header
			local fixed = S( 18 ) + S( 24 ) + S( 44 ) + S( 30 ) * ( LBR.INV_BAG > 0 and 2 or 1 ) + S( 4 )
			local th = math.floor( ( h - fixed ) / math.max( LBR.INV_SLOTS, 1 ) ) - S( 3 )
			th = math.Clamp( th, S( 24 ), S( 52 ) ) // 6 + 6 slots: compact tiles (one line)
			for _, t in ipairs( equipTiles ) do t:SetTall( th ) end
			for _, t in ipairs( bagTiles ) do t:SetTall( th ) end
			self:InvalidateLayout()
		end
	end
	return side
end

local function createBoard()
	local w = math.min( S( 1440 ), ScrW() - S( 40 ) )
	local h = math.min( S( 840 ), ScrH() - S( 80 ) )

	local f = vgui.Create( "EditablePanel" )
	f:SetSize( w, h )
	f:Center()
	f:DockPadding( S( 20 ), S( 96 ), S( 20 ), S( 34 ) )
	f.Paint = function( self, pw, ph )
		UI.Box( 0, 0, pw, ph, C.bg )
		UI.Box( 0, 0, pw, S( 3 ), C.accent )

		UI.Text( UI.Fit( GetHostName(), "LBR_UI_Title", pw * 0.38 ), "LBR_UI_Title", S( 20 ), S( 16 ), C.text )
		UI.Text( string.upper( game.GetMap() ), "LBR_UI_Small", S( 20 ), S( 52 ), C.dim )

		// right side: state + alive
		local state = GetGlobalInt( "state", 1 )
		local stateCol = state == 3 and C.good or ( state == 4 and C.bad or C.accent )
		UI.Text( stateNames[state] or "", "LBR_UI_Tiny", pw - S( 20 ), S( 20 ), stateCol, TEXT_ALIGN_RIGHT )
		local alive = aliveCount()
		UI.Text( tostring( alive ), "LBR_UI_Title", pw - S( 20 ), S( 36 ), C.text, TEXT_ALIGN_RIGHT )
		surface.SetFont( "LBR_UI_Title" )
		local aw = surface.GetTextSize( tostring( alive ) )
		UI.Text( "ALIVE", "LBR_UI_Tiny", pw - S( 26 ) - aw, S( 50 ), C.dim, TEXT_ALIGN_RIGHT )

		// column titles
		local y = S( 80 )
		UI.Text( "PLAYER", "LBR_UI_Tiny", S( 20 ) + S( 52 ), y, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		local cw = IsValid( self.List ) and self.List:GetWide() or pw - S( 40 )
		for i, c in ipairs( COLS ) do
			if i == 3 then
				UI.Text( c[1], "LBR_UI_Tiny", S( 20 ) + colX( cw, 3 ) - S( c[2] ) + S( 10 ), y, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			elseif i == 2 then
				UI.Text( c[1], "LBR_UI_Tiny", S( 20 ) + colX( cw, 2 ) - S( 14 ), y, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
			else
				UI.Text( c[1], "LBR_UI_Tiny", S( 20 ) + colX( cw, 1 ), y, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
			end
		end

		// footer
		local hint = self:IsMouseInputEnabled() and "Right click a player: mute / profile" or "Click to use the mouse"
		UI.Text( "F3 Classes   F4 Squad   M Map   Q Drop weapon in hand", "LBR_UI_Tiny", S( 20 ), ph - S( 18 ), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		UI.Text( hint, "LBR_UI_Tiny", pw - S( 20 ), ph - S( 18 ), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end

	// admins: start the round now with the players already in
	local start = UI.Button( f, "START NOW", C.good, function()
		net.Start( "LBR_ForceStart" )
		net.SendToServer()
	end )
	start:SetSize( S( 130 ), S( 30 ) )
	start:SetTooltip( "Start the round with the players already in, even if the minimum is not reached" )
	// always shown to admins in the lobby; greyed out with the reason when it can't start.
	// Called from the board's Think: a hidden panel does not run its own Think, so
	// the button could never come back once hidden.
	local function updateStart( self )
		local lp = LocalPlayer()
		local show = IsValid( lp ) and lp:IsAdmin() and GetGlobalInt( "state", 1 ) == 1
		if self:IsVisible() ~= show then self:SetVisible( show ) end
		if not show then return end
		if not GetGlobalBool( "LBR_MapReady", true ) then
			self.Disabled, self.Label = true, "MAP NOT READY"
		elseif team.NumPlayers( TEAM_PLAYER or 1 ) < 1 then
			self.Disabled, self.Label = true, "NO PLAYERS"
		else
			// alone: still allowed, to test the map
			self.Disabled = false
			self.Label = team.NumPlayers( TEAM_PLAYER or 1 ) < 2 and "START (TEST)" or "START NOW"
		end
		self:SetPos( math.floor( ( f:GetWide() - self:GetWide() ) / 2 ), S( 24 ) )
	end

	buildSide( f )
	local list = UI.Scroll( f )
	list:Dock( FILL )
	f.List = list
	f.Sig = ""
	f.NextCheck = 0

	// drag a weapon out of the inventory to drop it: anywhere on the board but the
	// inventory column, or out in the game, and on the zone shown on the right while
	// you drag
	makeDropTarget( f )
	local world = vgui.GetWorldPanel()
	if IsValid( world ) and not world.LBR_DropTarget then makeDropTarget( world ) end
	local zone = vgui.Create( "DPanel" )
	makeDropTarget( zone )
	zone:MakePopup()
	zone:SetKeyboardInputEnabled( false )
	zone:Hide()
	f.DropZone = zone
	f.OnRemove = function() if IsValid( zone ) then zone:Remove() end end
	zone.Paint = function( self, w, h )
		local r = dragndrop.m_Receiver
		local hot = IsValid( r ) and r.LBR_DropTarget
		local pulse = math.abs( math.sin( CurTime() * 5 ) )
		UI.Box( 0, 0, w, h, Color( 20, 8, 10, 235 ) )
		UI.Box( 0, 0, w, h, Color( DROP_RED.r, DROP_RED.g, DROP_RED.b, hot and 60 + pulse * 40 or 25 ) )
		surface.SetDrawColor( DROP_RED.r, DROP_RED.g, DROP_RED.b, hot and 255 or 140 )
		surface.DrawOutlinedRect( 0, 0, w, h, hot and S( 3 ) or S( 2 ) )
		// arrow pointing down + text
		local cx, cy = w / 2, h / 2 - S( 30 )
		local a = S( 18 )
		draw.NoTexture()
		surface.DrawPoly( {
			{ x = cx - a, y = cy - a * 0.4 }, { x = cx + a, y = cy - a * 0.4 }, { x = cx, y = cy + a * 0.8 },
		} )
		local tc = Color( 255, 255, 255, hot and 255 or 180 )
		UI.Text( "DROP", "LBR_UI_Head", cx, cy + a + S( 14 ), DROP_RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		UI.Text( UI.Fit( "Let go here to", "LBR_UI_Tiny", w - S( 12 ) ), "LBR_UI_Tiny", cx, cy + a + S( 38 ), tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		UI.Text( UI.Fit( "drop the weapon", "LBR_UI_Tiny", w - S( 12 ) ), "LBR_UI_Tiny", cx, cy + a + S( 54 ), tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	local function updateZone()
		local show = draggingWeapon()
		if show then
			// to the right of the board; no room there (4:3): over the player list
			local fx, fy = f:GetPos()
			local rx = fx + f:GetWide() + S( 10 )
			local room = ScrW() - rx - S( 10 )
			if room >= S( 110 ) then
				zone:SetPos( rx, fy )
				zone:SetSize( math.min( room, S( 220 ) ), f:GetTall() )
			else
				local lx, ly = list:LocalToScreen( 0, 0 )
				zone:SetPos( lx, ly )
				zone:SetSize( list:GetWide(), list:GetTall() )
			end
		end
		if zone:IsVisible() ~= show then
			zone:SetVisible( show )
			if show then zone:MoveToFront() end
		end
	end

	f.Think = function( self )
		updateZone()
		updateStart( start )
		if CurTime() < self.NextCheck then return end
		self.NextCheck = CurTime() + 0.5
		local sig = signature()
		if sig ~= self.Sig then
			self.Sig = sig
			fillList( self.List )
		end
	end
	return f
end

function GM:ScoreboardShow()
	if not IsValid( Board ) then Board = createBoard() end
	Board.Sig = "" // rebuild now
	Board.NextCheck = 0
	Board:Show()
	Board:MakePopup()
	Board:SetKeyboardInputEnabled( false ) // keep moving with WASD
	Board:SetMouseInputEnabled( true ) // mouse goes to the board: the view stays still and buttons work right away
	return true
end

function GM:ScoreboardHide()
	if IsValid( Board ) then
		Board:SetMouseInputEnabled( false )
		Board:Hide()
		if IsValid( Board.DropZone ) then Board.DropZone:Hide() end
	end
	CloseDermaMenus()
	gui.EnableScreenClicker( false )
end

// left click while the scoreboard is open: give the mouse to the scoreboard
hook.Add( "PlayerBindPress", "LBR_ScoreboardMouse", function( ply, bind, pressed )
	if pressed and IsValid( Board ) and Board:IsVisible() and not Board:IsMouseInputEnabled()
		and ( bind == "+attack" or bind == "+attack2" ) then
		Board:SetMouseInputEnabled( true )
		return true
	end
end )

// the view never turns while the scoreboard is open
hook.Add( "InputMouseApply", "LBR_ScoreboardFreezeView", function( cmd )
	if IsValid( Board ) and Board:IsVisible() then
		cmd:SetMouseX( 0 )
		cmd:SetMouseY( 0 )
		return true
	end
end )

// Old global, kept for addons that called it
function ShowScoreBoard()
	GAMEMODE:ScoreboardShow()
end

// tell new players about TAB: when they join and when a match starts
// (the match hint is shown in the first few matches only)
hook.Add( "InitPostEntity", "LBR_TabHint", function()
	timer.Simple( 6, function()
		if LBR.NotifyLocal then LBR.NotifyLocal( "Hold TAB: players, your stats, classes and squad", "info", 7 ) end
	end )
end )

local wasInGame = false
timer.Create( "LBR_TabHint", 1, 0, function()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	local now = lp:Alive() and lp:Team() == TEAM_CONT
	if now and not wasInGame then
		local shown = cookie.GetNumber( "lbr_tabhint", 0 )
		if shown < 5 and LBR.NotifyLocal then
			cookie.Set( "lbr_tabhint", tostring( shown + 1 ) )
			LBR.NotifyLocal( "Hold TAB for your inventory: " .. LBR.INV_EQUIP .. " equipment + " .. LBR.INV_BAG .. " backpack slots", "info", 7 )
		end
	end
	wasInGame = now
end )
