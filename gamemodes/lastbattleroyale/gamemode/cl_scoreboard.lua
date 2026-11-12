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

local function ammoText( wep )
	local lp = LocalPlayer()
	local clip = wep:Clip1()
	local ammoType = wep:GetPrimaryAmmoType()
	local reserve = ammoType >= 0 and lp:GetAmmoCount( ammoType ) or 0
	if clip >= 0 then return clip .. " / " .. reserve end
	if ammoType >= 0 then return tostring( reserve ) end
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

// one inventory slot: drag it on another slot to swap, right click to drop
local function invTile( parent, slot )
	local t = vgui.Create( "DButton", parent )
	t:SetText( "" )
	t:Dock( TOP )
	t:SetTall( S( 44 ) )
	t:DockMargin( 0, 0, 0, S( 3 ) )
	t.Slot = slot
	t:Droppable( "LBR_Inv" )
	t:Receiver( "LBR_Inv", function( self, panels, dropped )
		self.DropHover = not dropped
		if not dropped then return end
		local src = panels[1]
		if not IsValid( src ) or src == self or not src.Slot then return end
		net.Start( "LBR_InvMove" )
		net.WriteUInt( src.Slot, 4 )
		net.WriteUInt( self.Slot, 4 )
		net.SendToServer()
		surface.PlaySound( "common/wpn_moveselect.wav" )
	end )
	t.Weapon = function( self )
		if not inGame() then return end
		return LBR.InvGet( LocalPlayer() )[self.Slot]
	end
	t.DoRightClick = function( self )
		if not IsValid( self:Weapon() ) then return end
		net.Start( "LBR_InvDrop" )
		net.WriteUInt( self.Slot, 4 )
		net.SendToServer()
		surface.PlaySound( "ui/buttonclick.wav" )
	end
	t.Paint = function( self, w, h )
		local wep = self:Weapon()
		local bag = self.Slot > LBR.INV_EQUIP
		local active = IsValid( wep ) and wep == LocalPlayer():GetActiveWeapon()
		local hover = self:IsHovered() or self.DropHover
		self.DropHover = false
		UI.Box( 0, 0, w, h, hover and C.rowHover or C.row )
		if active then UI.Accent( 0, 0, h, C.accent ) end
		if self:IsDragging() then UI.Box( 0, 0, w, h, Color( 255, 210, 70, 25 ) ) end

		// key / slot number
		local key = bag and "B" .. ( self.Slot - LBR.INV_EQUIP ) or tostring( self.Slot )
		UI.Text( key, "LBR_UI_Small", S( 14 ), h / 2, bag and C.dim or C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		if not IsValid( wep ) then
			UI.Text( "EMPTY", "LBR_UI_Tiny", S( 44 ), h / 2, Color( C.dim.r, C.dim.g, C.dim.b, 90 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			return
		end
		local ammo = ammoText( wep )
		surface.SetFont( "LBR_UI_Small" )
		local aw = ammo and surface.GetTextSize( ammo ) + S( 14 ) or 0
		UI.Text( UI.Fit( weaponName( wep ), "LBR_UI_Text", w - S( 54 ) - aw ), "LBR_UI_Text", S( 44 ), h / 2, active and C.accent or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		if ammo then UI.Text( ammo, "LBR_UI_Small", w - S( 12 ), h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER ) end
	end
	return t
end

local function buildSide( f )
	local side = vgui.Create( "DPanel", f )
	side:Dock( RIGHT )
	side:SetWide( math.min( S( 400 ), math.floor( f:GetWide() * 0.42 ) ) )
	side:DockMargin( S( 16 ), 0, 0, 0 )
	side.Paint = nil

	// buttons at the bottom
	local btns = vgui.Create( "DPanel", side )
	btns:Dock( BOTTOM )
	btns:SetTall( S( 32 ) )
	btns:DockMargin( 0, S( 8 ), 0, 0 )
	btns.Paint = nil
	local list = {
		UI.Button( btns, "CLASSES  F3", C.accent, function() ShowClassMenu() end ),
		UI.Button( btns, "SQUAD  F4", C.blue, function() ShowTeamMenu() end ),
		UI.Button( btns, "MAP  F2", C.good, function() if LBR.OpenMapMenu then LBR.OpenMapMenu() end end ),
	}
	btns.Think = function( self )
		local admin = LocalPlayer():IsAdmin()
		if list[3]:IsVisible() ~= admin then
			list[3]:SetVisible( admin )
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
	local function count( from, to )
		return function()
			local n = 0
			local items = inGame() and LBR.InvGet( LocalPlayer() ) or {}
			for s = from, to do if IsValid( items[s] ) then n = n + 1 end end
			return n .. " / " .. ( to - from + 1 )
		end
	end
	local heads = {}
	heads[1] = sideHeader( inv, "EQUIPMENT", count( 1, LBR.INV_EQUIP ) )
	heads[1]:DockMargin( 0, 0, 0, S( 4 ) )
	for s = 1, LBR.INV_EQUIP do tiles[#tiles + 1] = invTile( inv, s ) end
	heads[2] = sideHeader( inv, "BACKPACK", count( LBR.INV_EQUIP + 1, LBR.INV_SLOTS ) )
	for s = LBR.INV_EQUIP + 1, LBR.INV_SLOTS do tiles[#tiles + 1] = invTile( inv, s ) end
	local hint = vgui.Create( "DPanel", inv )
	hint:Dock( TOP )
	hint:SetTall( S( 18 ) )
	hint.Paint = function( self, w, h )
		UI.Text( "Drag to move  -  Right click to drop  -  1-5 in hand", "LBR_UI_Tiny", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	tiles[#tiles + 1] = hint
	tiles[#tiles + 1] = heads[1]
	tiles[#tiles + 1] = heads[2]
	inv.Think = function( self )
		local show = inGame()
		for _, t in ipairs( tiles ) do
			if t:IsVisible() ~= show then t:SetVisible( show ) end
		end
	end
	return side
end

local function createBoard()
	local w = math.min( S( 1320 ), ScrW() - S( 40 ) )
	local h = math.min( S( 760 ), ScrH() - S( 80 ) )

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
		UI.Text( "F3 Classes   F4 Squad   Q Drop weapon in hand", "LBR_UI_Tiny", S( 20 ), ph - S( 18 ), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
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
	f.Think = function( self )
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
