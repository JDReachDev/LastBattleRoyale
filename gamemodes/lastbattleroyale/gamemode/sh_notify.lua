// Gamemode messages with the same look as the HUD and menus.
//  LBR.Chat( target, "text", kind )    chat line with a colored [LBR] tag
//  LBR.Notify( target, "text", kind )  big message in the middle of the screen (replaces HUD_PRINTCENTER)
// target: a player, a table of players, or nil for everybody.
// kind: "info" (gold, default), "good" (green), "bad" (red), "event" (orange), "squad" (blue)

LBR = LBR or {}

LBR.MsgColors = {
	info  = Color( 255, 210, 70 ),
	good  = Color( 110, 230, 140 ),
	bad   = Color( 255, 85, 75 ),
	event = Color( 255, 140, 40 ),
	squad = Color( 70, 170, 255 ),
}
local colText = Color( 236, 239, 245 )

if SERVER then
	util.AddNetworkString( "LBR_Chat" )
	util.AddNetworkString( "LBR_Notify" )

	local function send( target )
		if target == nil then net.Broadcast() else net.Send( target ) end
	end
	local function valid( target )
		return target == nil or istable( target ) or ( IsValid( target ) and target:IsPlayer() )
	end

	function LBR.Chat( target, text, kind )
		text = tostring( text )
		if not valid( target ) then print( "[LBR] " .. text ) return end
		net.Start( "LBR_Chat" )
			net.WriteString( text )
			net.WriteString( kind or "info" )
		send( target )
	end

	function LBR.Notify( target, text, kind, duration )
		if not valid( target ) then return end
		net.Start( "LBR_Notify" )
			net.WriteString( tostring( text ) )
			net.WriteString( kind or "info" )
			net.WriteFloat( duration or 4 )
		send( target )
	end
	return
end

------------------------------------------------------------------------
// Client
------------------------------------------------------------------------

function LBR.ChatLocal( text, kind )
	chat.AddText( LBR.MsgColors[kind or "info"] or LBR.MsgColors.info, "[LBR] ", colText, tostring( text ) )
end

net.Receive( "LBR_Chat", function()
	local text, kind = net.ReadString(), net.ReadString()
	LBR.ChatLocal( text, kind )
end )

local notes = {}

function LBR.NotifyLocal( text, kind, duration )
	// same text again: refresh it instead of stacking it
	for _, n in ipairs( notes ) do
		if n.text == text then n.die = CurTime() + ( duration or 4 ) return end
	end
	table.insert( notes, 1, { text = text, kind = kind or "info", start = CurTime(), die = CurTime() + ( duration or 4 ) } )
	while #notes > 4 do table.remove( notes ) end
	if kind == "bad" or kind == "event" then surface.PlaySound( "buttons/blip1.wav" ) end
end

net.Receive( "LBR_Notify", function()
	local text, kind, dur = net.ReadString(), net.ReadString(), net.ReadFloat()
	LBR.NotifyLocal( text, kind, dur )
end )

hook.Add( "HUDPaint", "LBR_Notify", function()
	if #notes == 0 then return end
	local UI = LBR.UI
	if not UI then return end
	local S = UI.S
	local now = CurTime()
	local y = ScrH() * 0.27
	local font = "LBR_UI_Head"
	surface.SetFont( font )
	for i = #notes, 1, -1 do
		if notes[i].die < now then table.remove( notes, i ) end
	end
	for _, n in ipairs( notes ) do
		local a = math.min( ( now - n.start ) / 0.2, 1, ( n.die - now ) / 0.4 )
		a = math.Clamp( a, 0, 1 )
		local col = LBR.MsgColors[n.kind] or LBR.MsgColors.info
		local tw, th = surface.GetTextSize( n.text )
		local w, h = tw + S( 44 ), th + S( 16 )
		local x = ScrW() / 2 - w / 2 + ( 1 - a ) * S( 20 )
		surface.SetDrawColor( 10, 14, 24, 220 * a )
		surface.DrawRect( x, y, w, h )
		surface.SetDrawColor( col.r, col.g, col.b, 255 * a )
		surface.DrawRect( x, y, S( 4 ), h )
		surface.SetDrawColor( col.r, col.g, col.b, 60 * a )
		surface.DrawRect( x + S( 4 ), y + h - S( 2 ), ( w - S( 4 ) ) * math.Clamp( ( n.die - now ) / 4, 0, 1 ), S( 2 ) )
		draw.SimpleText( n.text, font, x + S( 22 ), y + h / 2, Color( colText.r, colText.g, colText.b, 255 * a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		y = y + h + S( 6 )
	end
end )
