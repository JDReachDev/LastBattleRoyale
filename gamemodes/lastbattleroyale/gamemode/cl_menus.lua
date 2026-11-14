// F3 class menu, F4 squad menu and the squad invite popup, in the style of the HUD.
// The server side is unchanged (ChangeClass, SendTeamRequest, SendTeamRequestBTS) plus
// LBR_ClassInfo (sv_menus.lua) for the level of every class.

local UI = LBR.UI
local S = UI.S
local C = UI.col

local function weaponName( cls )
	local names = {
		weapon_crowbar = "Crowbar", weapon_stunstick = "Stunstick", weapon_slam = "S.L.A.M.",
		weapon_fists = "Fists", weapon_pistol = "9mm Pistol",
	}
	if names[cls] then return names[cls] end
	local w = weapons.Get( cls )
	if w and w.PrintName and w.PrintName ~= "" then return language.GetPhrase( w.PrintName ) end
	return cls
end

local function expNeeded( lvl )
	local cv = GetConVar( "lbr_level_exp" )
	return ( lvl + 1 ) * ( cv and cv:GetInt() or 25 )
end

/////////////////////////////////////////////////////////////////////////////// F3 classes

local ClassInfo = { levels = {}, exps = {}, current = "", nextClass = "", premium = false }
local ClassFrame

net.Receive( "LBR_ClassInfo", function()
	ClassInfo.current = net.ReadString()
	ClassInfo.nextClass = net.ReadString()
	ClassInfo.premium = net.ReadBool()
	for i = 1, net.ReadUInt( 8 ) do
		local cls = net.ReadString()
		ClassInfo.levels[cls] = net.ReadUInt( 16 )
		ClassInfo.exps[cls] = net.ReadUInt( 32 )
	end
	ClassInfo.received = true
end )

local function requestClassInfo()
	net.Start( "LBR_ClassInfo" )
	net.SendToServer()
end

local function classLevel( cls ) return ClassInfo.levels[cls] or 0 end

// list of { text, ok } requirements, and whether every one is met
local function requirements( c )
	local list, ok = {}, true
	if c.premium then
		list[#list + 1] = { "Donators only", ClassInfo.premium }
		ok = ok and ClassInfo.premium
	end
	for _, need in ipairs( c.classesneeded or {} ) do
		local bc = baseclass.Get( need.class )
		local name = bc and bc.DisplayName or need.class
		local have = classLevel( need.class )
		local met = have >= need.level
		list[#list + 1] = { name .. " level " .. need.level .. "  (" .. math.min( have, need.level ) .. "/" .. need.level .. ")", met }
		ok = ok and met
	end
	return list, ok
end

local function classStatus( c )
	local _, ok = requirements( c )
	if c.class == ClassInfo.nextClass and c.class ~= ClassInfo.current then return "NEXT ROUND", C.blue end
	if c.class == ClassInfo.current then return "IN USE", C.good end
	if not ok then return "LOCKED", C.dim end
	return nil
end

local function statBar( parent, label, value, maxValue, text, col )
	local p = vgui.Create( "DPanel", parent )
	p:Dock( TOP )
	p:SetTall( S( 34 ) )
	p:DockMargin( 0, 0, 0, S( 4 ) )
	p.Paint = function( self, w, h )
		UI.Text( label, "LBR_UI_Tiny", 0, 0, C.dim )
		UI.Text( text, "LBR_UI_Tiny", w, 0, C.text, TEXT_ALIGN_RIGHT )
		UI.Bar( 0, S( 18 ), w, S( 8 ), value / maxValue, col )
	end
	return p
end

local function buildDetail( detail, c )
	detail:Clear()
	local bc = baseclass.Get( c.class ) or {}
	local info = CLASS_INFO and CLASS_INFO[c.class] or {}
	local lvl = classLevel( c.class )
	local exp = ClassInfo.exps[c.class] or 0

	local head = vgui.Create( "DPanel", detail )
	head:Dock( TOP )
	head:SetTall( S( 96 ) )
	head.Paint = function( self, w, h )
		UI.Text( string.upper( bc.DisplayName or c.name ), "LBR_UI_Title", 0, 0, C.text )
		UI.Text( info.desc or "", "LBR_UI_Small", 0, S( 38 ), C.dim )
		local st, col = classStatus( c )
		if st then UI.Text( st, "LBR_UI_Tiny", w, S( 8 ), col, TEXT_ALIGN_RIGHT ) end
		// level + EXP
		local need = expNeeded( lvl )
		UI.Text( "LEVEL " .. lvl, "LBR_UI_Head", 0, S( 62 ), C.accent )
		UI.Text( exp .. " / " .. need .. " EXP", "LBR_UI_Tiny", w, S( 66 ), C.dim, TEXT_ALIGN_RIGHT )
		UI.Bar( 0, S( 88 ), w, S( 6 ), exp / need, C.accent )
	end

	UI.Section( detail, "Stats" )
	local hp = bc.MaxHealth or 100
	statBar( detail, "HEALTH", hp, 120, tostring( hp ), hp < 60 and C.bad or C.good )
	local ar = LBR.ClassCfg and LBR.ClassCfg[c.class] and LBR.ClassCfg[c.class].armor or 0
	if ar > 0 then statBar( detail, "ARMOR", ar, 100, tostring( ar ), C.blue ) end
	local run = bc.RunSpeed or 1
	statBar( detail, "SPEED", run, 1.6, math.Round( run * 100 ) .. "%", C.blue )

	UI.Section( detail, "Loadout" )
	local lo = vgui.Create( "DPanel", detail )
	lo:Dock( TOP )
	local items = info.loadout or {}
	lo:SetTall( math.max( 1, #items ) * S( 24 ) )
	lo.Paint = function( self, w, h )
		if #items == 0 then UI.Text( "-", "LBR_UI_Text", 0, 0, C.dim ) return end
		for i, wcls in ipairs( items ) do
			UI.Box( 0, ( i - 1 ) * S( 24 ) + S( 8 ), S( 6 ), S( 6 ), C.accent )
			UI.Text( weaponName( wcls ), "LBR_UI_Text", S( 16 ), ( i - 1 ) * S( 24 ), C.text )
		end
	end

	local reqs, ok = requirements( c )
	if #reqs > 0 then
		UI.Section( detail, "Unlock" )
		local rp = vgui.Create( "DPanel", detail )
		rp:Dock( TOP )
		rp:SetTall( #reqs * S( 22 ) )
		rp.Paint = function( self, w, h )
			for i, r in ipairs( reqs ) do
				local y = ( i - 1 ) * S( 22 )
				local col = r[2] and C.good or C.bad
				surface.SetDrawColor( col )
				if r[2] then
					surface.DrawRect( S( 2 ), y + S( 4 ), S( 10 ), S( 10 ) )
				else
					surface.DrawOutlinedRect( S( 2 ), y + S( 4 ), S( 10 ), S( 10 ) )
				end
				UI.Text( r[1], "LBR_UI_Small", S( 20 ), y, r[2] and C.text or C.dim )
			end
		end
	end

	local btn = UI.Button( detail, "", C.accent, function()
		net.Start( "ChangeClass" )
			net.WriteString( c.class )
		net.SendToServer()
		ClassInfo.nextClass = c.class // shown at once, the server answer confirms it
		timer.Simple( 0.3, requestClassInfo )
	end )
	btn:Dock( BOTTOM )
	btn:SetTall( S( 44 ) )
	btn.Think = function( self )
		if c.class == ClassInfo.nextClass then
			self.Label, self.Disabled = c.class == ClassInfo.current and "IN USE" or "SELECTED FOR NEXT ROUND", true
		elseif not ok then
			self.Label, self.Disabled = "LOCKED", true
		else
			self.Label, self.Disabled = "SELECT " .. string.upper( bc.DisplayName or c.name ), false
		end
	end
	local note = vgui.Create( "DPanel", detail )
	note:Dock( BOTTOM )
	note:SetTall( S( 26 ) )
	note.Paint = function( self, w, h )
		UI.Text( "The new class is used from the next round. EXP is saved per class.", "LBR_UI_Tiny", 0, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end
end

function ShowClassMenu()
	if IsValid( ClassFrame ) then ClassFrame:Close() return end
	requestClassInfo()

	local f = UI.Frame( S( 980 ), S( 640 ), "Classes", "Level up a class to unlock the next ones" )
	ClassFrame = f
	local body = f

	local list = UI.Scroll( body )
	list:Dock( LEFT )
	list:SetWide( S( 340 ) )
	list:DockMargin( 0, 0, S( 20 ), 0 )

	local detail = vgui.Create( "DPanel", body )
	detail:Dock( FILL )
	detail.Paint = nil

	local selected
	local function select( c )
		selected = c
		buildDetail( detail, c )
	end

	for _, c in ipairs( CLASSES or {} ) do
		local card = vgui.Create( "DButton", list:GetCanvas() )
		card:SetText( "" )
		card:Dock( TOP )
		card:SetTall( S( 58 ) )
		card:DockMargin( 0, 0, S( 8 ), S( 4 ) )
		card.DoClick = function()
			surface.PlaySound( "ui/buttonrollover.wav" )
			select( c )
		end
		card.Paint = function( self, w, h )
			local bc = baseclass.Get( c.class ) or {}
			local st, stCol = classStatus( c )
			local locked = st == "LOCKED"
			UI.Box( 0, 0, w, h, ( selected == c or self:IsHovered() ) and C.rowHover or C.row )
			if selected == c then UI.Accent( 0, 0, h ) end
			local nameCol = locked and C.dim or C.text
			UI.Text( bc.DisplayName or c.name, "LBR_UI_Head", S( 14 ), S( 8 ), nameCol )
			if locked then
				surface.SetMaterial( UI.matLock )
				surface.SetDrawColor( 255, 255, 255, 160 )
				surface.DrawTexturedRect( w - S( 30 ), S( 10 ), S( 16 ), S( 16 ) )
			elseif st then
				UI.Text( st, "LBR_UI_Tiny", w - S( 12 ), S( 12 ), stCol, TEXT_ALIGN_RIGHT )
			end
			local lvl = classLevel( c.class )
			UI.Text( "LV " .. lvl, "LBR_UI_Tiny", S( 14 ), S( 36 ), locked and C.dim or C.accent )
			UI.Bar( S( 56 ), S( 40 ), w - S( 70 ), S( 4 ), ( ClassInfo.exps[c.class] or 0 ) / expNeeded( lvl ), locked and C.dim or C.accent )
		end
	end

	// open on the class in use, once the server answered
	local start
	for _, c in ipairs( CLASSES or {} ) do
		if baseclass.Get( c.class ) and LocalPlayer().GetLSTClass and baseclass.Get( c.class ).DisplayName == LocalPlayer():GetLSTClass() then start = c end
	end
	start = start or ( CLASSES and CLASSES[1] )
	if start then select( start ) end
	f.Think = function( self )
		if ClassInfo.received and not self.Refreshed and selected then
			self.Refreshed = true
			select( selected ) // levels arrived: rebuild requirements
		end
	end
	ClassInfo.received = false
end
concommand.Add( "showclassmenu", ShowClassMenu )
concommand.Add( "lbr_classmenu", ShowClassMenu )

/////////////////////////////////////////////////////////////////////////////// squad invite popup

local Invite = nil // { from = nick, expires = time }
local InviteToast

local function sendAnswer( yes )
	net.Start( "SendTeamRequestBTS" )
		net.WriteBool( yes )
	net.SendToServer()
	answeredcall = nil
	Invite = nil
	if IsValid( InviteToast ) then InviteToast:Remove() end
end

function ShowTeamRequest( str )
	Invite = { from = str, expires = CurTime() + 15 }
	if IsValid( InviteToast ) then InviteToast:Remove() end
	surface.PlaySound( "buttons/blip1.wav" )

	local p = vgui.Create( "DPanel" )
	InviteToast = p
	p:SetSize( S( 340 ), S( 96 ) )
	p:SetPos( ScrW() - p:GetWide() - S( 24 ), ScrH() * 0.3 )
	p:SetMouseInputEnabled( false )
	p:SetKeyboardInputEnabled( false )
	p.Think = function( self )
		if not Invite or CurTime() > Invite.expires then self:Remove() end
	end
	p.Paint = function( self, w, h )
		if not Invite then return end
		UI.Box( 0, 0, w, h, C.bg )
		UI.Accent( 0, 0, h )
		UI.Text( "SQUAD INVITE", "LBR_UI_Tiny", S( 16 ), S( 10 ), C.accent )
		UI.Text( UI.Fit( Invite.from, "LBR_UI_Head", w - S( 32 ) ), "LBR_UI_Head", S( 16 ), S( 26 ), C.text )
		UI.Text( "wants to team up with you", "LBR_UI_Small", S( 16 ), S( 50 ), C.dim )
		UI.Text( "F7 ACCEPT", "LBR_UI_Tiny", S( 16 ), S( 74 ), C.good )
		UI.Text( "F6 DECLINE", "LBR_UI_Tiny", S( 100 ), S( 74 ), C.bad )
		UI.Box( 0, h - S( 3 ), w * math.Clamp( ( Invite.expires - CurTime() ) / 15, 0, 1 ), S( 3 ), C.accent )
	end
end

function DecilineRequest()
	if Invite then sendAnswer( false ) end
end

function AcceptRequest()
	if Invite then sendAnswer( true ) end
end

/////////////////////////////////////////////////////////////////////////////// F4 squad

local SquadFrame
local inviteCooldown = {} // steamid64 -> time
local removing = {}       // steamid64 -> true (asked to remove, done at the next round)


local function isMate( ply )
	local sid = ply:SteamID64()
	for _, s in ipairs( TEAMERSTAB or {} ) do
		if s == sid then return true end
	end
	return false
end

local function mates()
	local t = {}
	for _, sid in ipairs( TEAMERSTAB or {} ) do
		local p = player.GetBySteamID64( sid )
		if IsValid( p ) then t[#t + 1] = p end
	end
	return t
end

local function squadSlot( parent, ply, isMe )
	local slot = vgui.Create( "DPanel", parent )
	slot.Paint = function( self, w, h )
		UI.Box( 0, 0, w, h, C.row )
		if not IsValid( ply ) then
			UI.Text( "EMPTY", "LBR_UI_Tiny", w / 2, h / 2, C.locked, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			return
		end
		UI.Accent( 0, 0, h, isMe and C.text or C.accent )
		UI.Text( UI.Fit( ply:Nick(), "LBR_UI_Text", w - S( 24 ) ), "LBR_UI_Text", w / 2, S( 76 ), isMe and C.text or C.accent, TEXT_ALIGN_CENTER )
		local cls = ply.GetLSTClass and ply:GetLSTClass() or ""
		local lvl = ply.GetLevel and ply:GetLevel() or 0
		UI.Text( cls .. "  LV " .. lvl, "LBR_UI_Tiny", w / 2, S( 98 ), C.dim, TEXT_ALIGN_CENTER )
		if removing[ply:SteamID64()] then
			UI.Text( "LEAVES NEXT ROUND", "LBR_UI_Tiny", w / 2, S( 116 ), C.bad, TEXT_ALIGN_CENTER )
		end
	end
	if IsValid( ply ) then
		local av = vgui.Create( "AvatarImage", slot )
		av:SetSize( S( 56 ), S( 56 ) )
		av:SetPlayer( ply, 64 )
		slot.PerformLayout = function( self, w, h ) av:SetPos( ( w - av:GetWide() ) / 2, S( 12 ) ) end
		if not isMe then
			local b = UI.Button( slot, "REMOVE", C.bad, function()
				net.Start( "SendTeamRequest" )
					net.WriteString( ply:Nick() )
				net.SendToServer()
				removing[ply:SteamID64()] = true
			end )
			b:Dock( BOTTOM )
			b:DockMargin( S( 10 ), 0, S( 10 ), S( 10 ) )
			b:SetTall( S( 28 ) )
			b.Think = function( self ) self.Disabled = removing[ply:SteamID64()] end
			b:SetTooltip( "Leaves the squad when the next round starts" )
		end
	end
	return slot
end

local function buildSquad( f )
	f.Squad:Clear()
	local list = { LocalPlayer() }
	local still = {}
	for _, m in ipairs( mates() ) do
		list[#list + 1] = m
		still[m:SteamID64()] = removing[m:SteamID64()]
	end
	removing = still // players that already left are forgotten
	for i = 1, 4 do
		local s = squadSlot( f.Squad, list[i], i == 1 )
		s:Dock( LEFT )
		s:DockMargin( 0, 0, i < 4 and S( 10 ) or 0, 0 )
	end
	f.Squad.PerformLayout = function( self, w, h )
		for _, ch in ipairs( self:GetChildren() ) do ch:SetWide( ( w - S( 30 ) ) / 4 ) end
	end
	f.Squad:InvalidateLayout()
end

local function buildPlayers( f )
	local canvas = f.Players:GetCanvas()
	f.Players:Clear()
	local others = {}
	for _, p in ipairs( player.GetAll() ) do
		if p ~= LocalPlayer() and p:Team() ~= TEAM_SPEC and not isMate( p ) then others[#others + 1] = p end
	end
	table.sort( others, function( a, b ) return a:Nick():lower() < b:Nick():lower() end )

	if #others == 0 then
		local e = vgui.Create( "DPanel", canvas )
		e:Dock( TOP )
		e:SetTall( S( 40 ) )
		e.Paint = function( self, w, h )
			UI.Text( "Nobody to invite right now", "LBR_UI_Small", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	for _, p in ipairs( others ) do
		local row = vgui.Create( "DPanel", canvas )
		row:Dock( TOP )
		row:SetTall( S( 42 ) )
		row:DockMargin( 0, 0, S( 8 ), S( 3 ) )
		local av = vgui.Create( "AvatarImage", row )
		av:SetSize( S( 32 ), S( 32 ) )
		av:SetPos( S( 10 ), S( 5 ) )
		av:SetPlayer( p, 64 )
		row.Paint = function( self, w, h )
			if not IsValid( p ) then return end
			UI.Box( 0, 0, w, h, C.row )
			UI.Text( UI.Fit( p:Nick(), "LBR_UI_Text", w * 0.45 ), "LBR_UI_Text", S( 52 ), h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			local cls = p.GetLSTClass and p:GetLSTClass() or ""
			local lvl = p.GetLevel and p:GetLevel() or 0
			UI.Text( cls .. "  LV " .. lvl, "LBR_UI_Tiny", w - S( 140 ), h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
		local b = UI.Button( row, "INVITE", C.accent, function( self )
			if not IsValid( p ) then return end
			net.Start( "SendTeamRequest" )
				net.WriteString( p:Nick() )
			net.SendToServer()
			inviteCooldown[p:SteamID64() or p:Nick()] = CurTime() + 15
		end )
		b:Dock( RIGHT )
		b:SetWide( S( 110 ) )
		b:DockMargin( 0, S( 7 ), S( 10 ), S( 7 ) )
		b.Think = function( self )
			if not IsValid( p ) then return end
			local left = ( inviteCooldown[p:SteamID64() or p:Nick()] or 0 ) - CurTime()
			if left > 0 then
				self.Label, self.Disabled = "SENT  " .. math.ceil( left ), true
			else
				self.Label, self.Disabled = "INVITE", false
			end
		end
	end
end

local function squadSignature()
	local t = { table.concat( TEAMERSTAB or {}, "," ) }
	for _, p in ipairs( player.GetAll() ) do t[#t + 1] = p:EntIndex() .. ":" .. p:Team() end
	return table.concat( t, ";" )
end

function ShowTeamMenu()
	if IsValid( SquadFrame ) then SquadFrame:Close() return end
	local f = UI.Frame( S( 820 ), S( 660 ), "Squad", "Up to 4 players. Invites can be sent before the weapons are hot." )
	SquadFrame = f

	// pending invite: answer with the mouse too
	local inv = vgui.Create( "DPanel", f )
	inv:Dock( TOP )
	inv:SetTall( 0 )
	inv:DockMargin( 0, 0, 0, 0 )
	inv.Paint = function( self, w, h )
		if not Invite then return end
		UI.Box( 0, 0, w, h, Color( C.accent.r, C.accent.g, C.accent.b, 25 ) )
		UI.Accent( 0, 0, h )
		UI.Text( "INVITE FROM", "LBR_UI_Tiny", S( 14 ), S( 8 ), C.accent )
		UI.Text( UI.Fit( Invite.from, "LBR_UI_Head", w * 0.45 ), "LBR_UI_Head", S( 14 ), S( 22 ), C.text )
	end
	local acc = UI.Button( inv, "ACCEPT (F7)", C.good, function() AcceptRequest() end )
	acc:Dock( RIGHT )
	acc:SetWide( S( 130 ) )
	acc:DockMargin( S( 8 ), S( 10 ), S( 10 ), S( 10 ) )
	local dec = UI.Button( inv, "DECLINE (F6)", C.bad, function() DecilineRequest() end )
	dec:Dock( RIGHT )
	dec:SetWide( S( 130 ) )
	dec:DockMargin( 0, S( 10 ), 0, S( 10 ) )

	UI.Section( f, "Your squad" )
	local squad = vgui.Create( "DPanel", f )
	squad:Dock( TOP )
	squad:SetTall( S( 170 ) )
	squad.Paint = nil
	f.Squad = squad

	UI.Section( f, "Players" )
	local players = UI.Scroll( f )
	players:Dock( FILL )
	f.Players = players

	f.Sig = nil
	f.Think = function( self )
		local want = Invite and S( 62 ) or 0
		if inv:GetTall() ~= want then
			inv:SetTall( want )
			inv:DockMargin( 0, 0, 0, want > 0 and S( 6 ) or 0 )
		end
		if ( self.NextCheck or 0 ) > CurTime() then return end
		self.NextCheck = CurTime() + 0.5
		local sig = squadSignature()
		if sig ~= self.Sig then
			self.Sig = sig
			buildSquad( self )
			buildPlayers( self )
		end
	end
end
concommand.Add( "showteammenu", ShowTeamMenu )
concommand.Add( "lbr_squadmenu", ShowTeamMenu )
