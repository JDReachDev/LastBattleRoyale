// Map vote window (end of the match) and admin map menu (F2). Server side: sv_mapvote.lua

LBR = LBR or {}
local UI = LBR.UI
local S = UI.S
local C = UI.col

local thumbs = {}
local function mapThumb( map )
	if thumbs[map] == nil then
		local path = "maps/thumb/" .. map .. ".png"
		thumbs[map] = file.Exists( path, "GAME" ) and Material( path, "smooth" ) or false
	end
	return thumbs[map] or nil
end

------------------------------------------------------------------------
// Vote
------------------------------------------------------------------------

local Vote = { maps = {}, builtin = {}, counts = {}, mine = nil, endTime = 0, current = "" }
local VoteFrame

local function openVote()
	if IsValid( VoteFrame ) then VoteFrame:Remove() end
	local n = #Vote.maps
	local cols = math.min( n, 4 )
	local rows = math.ceil( n / cols )
	local tw, th = S( 200 ), S( 170 )
	local gap = S( 10 )
	local f = UI.Frame( cols * tw + ( cols - 1 ) * gap + S( 40 ), rows * th + ( rows - 1 ) * gap + S( 92 ), "Vote the next map", "Only maps ready to play. Click to vote, you can change your vote." )
	VoteFrame = f
	f.Think = function( self )
		if not GetGlobalBool( "LBR_MapVote", false ) and Vote.endTime < CurTime() then self:Remove() end
	end
	local oldPaint = f.Paint
	f.Paint = function( self, pw, ph )
		oldPaint( self, pw, ph )
		local left = math.max( 0, math.ceil( Vote.endTime - CurTime() ) )
		UI.Text( left .. "s", "LBR_UI_Title", pw - S( 60 ), S( 14 ), left <= 5 and C.bad or C.accent, TEXT_ALIGN_RIGHT )
	end

	local grid = vgui.Create( "DPanel", f )
	grid:Dock( FILL )
	grid.Paint = nil
	for i, map in ipairs( Vote.maps ) do
		local b = vgui.Create( "DButton", grid )
		b:SetText( "" )
		b:SetSize( tw, th )
		b:SetPos( ( ( i - 1 ) % cols ) * ( tw + gap ), math.floor( ( i - 1 ) / cols ) * ( th + gap ) )
		b.DoClick = function()
			if Vote.endTime < CurTime() then return end
			Vote.mine = i
			surface.PlaySound( "ui/buttonclick.wav" )
			net.Start( "LBR_MapVote" )
				net.WriteUInt( i, 8 )
			net.SendToServer()
		end
		b.Paint = function( self, w, h )
			local hov = self:IsHovered()
			local sel = Vote.mine == i
			local win = Vote.winner == map
			UI.Box( 0, 0, w, h, hov and C.rowHover or C.row )
			local ih = h - S( 52 )
			local mat = mapThumb( map )
			if mat then
				surface.SetDrawColor( 255, 255, 255, hov and 255 or 210 )
				surface.SetMaterial( mat )
				surface.DrawTexturedRect( S( 4 ), S( 4 ), w - S( 8 ), ih - S( 4 ) )
			else
				UI.Box( S( 4 ), S( 4 ), w - S( 8 ), ih - S( 4 ), Color( 0, 0, 0, 120 ) )
				UI.Text( "?", "LBR_UI_Title", w / 2, ih / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			end
			UI.Text( UI.Fit( map, "LBR_UI_Text", w - S( 50 ) ), "LBR_UI_Text", S( 8 ), ih + S( 4 ), C.text )
			local tag = map == Vote.current and "CURRENT MAP" or ( Vote.builtin[i] and "BUILT-IN" or "CUSTOM" )
			UI.Text( tag, "LBR_UI_Tiny", S( 8 ), ih + S( 28 ), map == Vote.current and C.blue or C.dim )
			UI.Text( tostring( Vote.counts[i] or 0 ), "LBR_UI_Title", w - S( 8 ), ih + S( 6 ), C.accent, TEXT_ALIGN_RIGHT )
			if sel or win then
				local c = win and C.good or C.accent
				surface.SetDrawColor( c )
				surface.DrawOutlinedRect( 0, 0, w, h, S( 2 ) )
			end
		end
	end
end

net.Receive( "LBR_MapVoteStart", function()
	Vote.endTime = net.ReadFloat()
	Vote.current = net.ReadString()
	Vote.maps, Vote.builtin, Vote.counts = {}, {}, {}
	Vote.mine, Vote.winner = nil, nil
	for i = 1, net.ReadUInt( 8 ) do
		Vote.maps[i] = net.ReadString()
		Vote.builtin[i] = net.ReadBool()
	end
	surface.PlaySound( "buttons/blip1.wav" )
	openVote()
end )

net.Receive( "LBR_MapVoteUpdate", function()
	for i = 1, net.ReadUInt( 8 ) do Vote.counts[i] = net.ReadUInt( 8 ) end
end )

net.Receive( "LBR_MapVoteEnd", function()
	Vote.winner = net.ReadString()
	Vote.endTime = CurTime() + 3 // keep the window a moment to show the winner
	chat.AddText( C.accent, "[Map vote] ", C.text, "Next map: ", C.good, Vote.winner )
end )

concommand.Add( "lbr_mapvote", function()
	if GetGlobalBool( "LBR_MapVote", false ) and #Vote.maps > 0 then openVote() end
end )

------------------------------------------------------------------------
// Admin map menu (F2)
------------------------------------------------------------------------

local MapFrame
local STATUS_NONE, STATUS_BROKEN, STATUS_CUSTOM, STATUS_BUILTIN = 0, 1, 2, 3

local function buildMapMenu( list )
	if IsValid( MapFrame ) then MapFrame:Remove() end
	local ready, todo = {}, {}
	for _, m in ipairs( list ) do
		if m.status == STATUS_CUSTOM or m.status == STATUS_BUILTIN then ready[#ready + 1] = m else todo[#todo + 1] = m end
	end

	local f = UI.Frame( S( 620 ), S( 760 ), "Change map", #list .. " maps installed on the server. Ready ones can be played now, the others can be configured with F8 after the change." )
	MapFrame = f
	local current = string.lower( game.GetMap() )

	local top = vgui.Create( "DPanel", f )
	top:Dock( TOP )
	top:SetTall( S( 30 ) )
	top.Paint = nil
	local vb = UI.Button( top, "START MAP VOTE", C.accent, function()
		RunConsoleCommand( "lbr_mapvote_start" )
		f:Close()
	end )
	vb:Dock( RIGHT )
	vb:SetWide( S( 160 ) )

	local sp = UI.Scroll( f )
	sp:Dock( FILL )
	sp:DockMargin( 0, S( 6 ), 0, 0 )

	local function row( m, ok )
		local r = vgui.Create( "DPanel", sp )
		r:Dock( TOP )
		r:SetTall( S( 40 ) )
		r:DockMargin( 0, 0, S( 8 ), S( 3 ) )
		r.Paint = function( self, w, h )
			UI.Box( 0, 0, w, h, self:IsHovered() and C.rowHover or C.row )
			if m.map == current then UI.Accent( 0, 0, h, C.blue ) end
			local nameW = w - S( 150 )
			UI.Text( UI.Fit( m.map, "LBR_UI_Text", nameW * 0.5 ), "LBR_UI_Text", S( 12 ), h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			local tag, col
			if m.map == current then tag, col = "CURRENT", C.blue
			elseif m.status == STATUS_BUILTIN then tag, col = "BUILT-IN", C.good
			elseif m.status == STATUS_CUSTOM then tag, col = "CONFIGURED", C.good
			elseif m.status == STATUS_BROKEN then tag, col = "INCOMPLETE", C.bad
			else tag, col = "NOT CONFIGURED", C.dim end
			local x = S( 12 ) + nameW * 0.5 + S( 10 )
			UI.Text( tag, "LBR_UI_Tiny", x, ok and h / 2 or S( 6 ), col, TEXT_ALIGN_LEFT, ok and TEXT_ALIGN_CENTER or TEXT_ALIGN_TOP )
			if not ok and m.info ~= "" then
				UI.Text( UI.Fit( m.info, "LBR_UI_Tiny", nameW * 0.5 ), "LBR_UI_Tiny", x, h - S( 6 ), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM )
			end
		end
		local b = UI.Button( r, ok and "PLAY" or "CONFIGURE", ok and C.good or C.accent, function()
			Derma_Query( ok and ( "Change map to " .. m.map .. " now? The current match ends." )
				or ( "Change map to " .. m.map .. "? It is not ready yet: press F8 there to configure it." ),
				"Change map", "Yes", function()
					net.Start( "LBR_ChangeMap" )
						net.WriteString( m.map )
					net.SendToServer()
					if IsValid( f ) then f:Close() end
				end, "No" )
		end )
		b:Dock( RIGHT )
		b:DockMargin( 0, S( 5 ), S( 6 ), S( 5 ) )
		b:SetWide( S( 120 ) )
		if m.map == current then b.Disabled = true b.Label = "HERE" end
	end

	UI.Section( sp, "Ready to play", function() return #ready end, C.good ):DockMargin( 0, 0, S( 8 ), S( 4 ) )
	for _, m in ipairs( ready ) do row( m, true ) end
	UI.Section( sp, "To configure", function() return #todo end, C.dim ):DockMargin( 0, S( 12 ), S( 8 ), S( 4 ) )
	for _, m in ipairs( todo ) do row( m, false ) end
end

net.Receive( "LBR_MapList", function()
	local list = {}
	for i = 1, net.ReadUInt( 16 ) do
		list[i] = { map = net.ReadString(), status = net.ReadUInt( 2 ), info = net.ReadString() }
	end
	buildMapMenu( list )
end )

function LBR.OpenMapMenu()
	if IsValid( MapFrame ) then MapFrame:Close() return end // F2 again closes it
	net.Start( "LBR_MapList" )
	net.SendToServer()
end
concommand.Add( "lbr_mapmenu", LBR.OpenMapMenu )
