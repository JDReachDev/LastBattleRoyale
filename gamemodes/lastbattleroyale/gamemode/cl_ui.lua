// Shared look for the menus (TAB scoreboard, F3 classes, F4 squad).
// Same style as the HUD: dark translucent panels, white text, gold accent.

LBR = LBR or {}
LBR.UI = LBR.UI or {}
local UI = LBR.UI

UI.scale = 1
function UI.S( v ) return math.Round( v * UI.scale ) end
local S = UI.S

local function CreateUIFonts()
	UI.scale = math.Clamp( ScrH() / 1080, 0.6, 2 )
	surface.CreateFont( "LBR_UI_Title", { font = "Roboto", size = S( 30 ), weight = 900, antialias = true } )
	surface.CreateFont( "LBR_UI_Head",  { font = "Roboto", size = S( 20 ), weight = 800, antialias = true } )
	surface.CreateFont( "LBR_UI_Text",  { font = "Roboto", size = S( 17 ), weight = 600, antialias = true } )
	surface.CreateFont( "LBR_UI_Small", { font = "Roboto", size = S( 14 ), weight = 600, antialias = true } )
	surface.CreateFont( "LBR_UI_Tiny",  { font = "Roboto", size = S( 12 ), weight = 800, antialias = true } )
end
CreateUIFonts()
hook.Add( "OnScreenSizeChanged", "LBR_UIFonts", CreateUIFonts )

UI.col = {
	bg       = Color( 10, 14, 24, 230 ),
	header   = Color( 255, 255, 255, 10 ),
	row      = Color( 255, 255, 255, 9 ),
	rowHover = Color( 255, 255, 255, 24 ),
	line     = Color( 255, 255, 255, 20 ),
	text     = Color( 236, 239, 245 ),
	dim      = Color( 150, 158, 175 ),
	accent   = Color( 255, 210, 70 ),
	good     = Color( 110, 230, 140 ),
	bad      = Color( 255, 85, 75 ),
	blue     = Color( 70, 170, 255 ),
	locked   = Color( 255, 255, 255, 40 ),
}
local C = UI.col

UI.matSkull = Material( "zpicons/skull.png", "smooth" )
UI.matLock = Material( "icon16/lock.png" )
UI.matGradL = Material( "vgui/gradient-l" )
UI.matGradU = Material( "vgui/gradient-u" )

function UI.Box( x, y, w, h, col )
	surface.SetDrawColor( col )
	surface.DrawRect( x, y, w, h )
end

// thin gold bar on the left of selected / highlighted things
function UI.Accent( x, y, h, col )
	surface.SetDrawColor( col or C.accent )
	surface.DrawRect( x, y, S( 3 ), h )
end

function UI.Bar( x, y, w, h, frac, col )
	UI.Box( x, y, w, h, Color( 0, 0, 0, 140 ) )
	UI.Box( x, y, math.floor( w * math.Clamp( frac, 0, 1 ) ), h, col )
end

function UI.Text( str, font, x, y, col, ax, ay )
	return draw.SimpleText( str, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP )
end

// Text cut with "..." to fit in w
function UI.Fit( str, font, w )
	surface.SetFont( font )
	if surface.GetTextSize( str ) <= w then return str end
	while #str > 1 and surface.GetTextSize( str .. "..." ) > w do
		str = string.sub( str, 1, -2 )
	end
	return str .. "..."
end

// Flat button: UI.Button( parent, "TEXT", color, function() end )
function UI.Button( parent, label, col, onClick )
	local b = vgui.Create( "DButton", parent )
	b:SetText( "" )
	b.Label = label
	b.Col = col or C.accent
	b.DoClick = function( self )
		if self.Disabled then return end
		surface.PlaySound( "ui/buttonclick.wav" )
		if onClick then onClick( self ) end
	end
	b.Paint = function( self, w, h )
		local c = self.Col
		if self.Disabled then
			UI.Box( 0, 0, w, h, Color( 255, 255, 255, 12 ) )
			UI.Text( self.Label, "LBR_UI_Small", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			return
		end
		local a = self:IsHovered() and 255 or 190
		UI.Box( 0, 0, w, h, Color( c.r, c.g, c.b, self:IsHovered() and 70 or 35 ) )
		surface.SetDrawColor( c.r, c.g, c.b, a )
		surface.DrawOutlinedRect( 0, 0, w, h )
		UI.Text( self.Label, "LBR_UI_Small", w / 2, h / 2, Color( 255, 255, 255, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	return b
end

// Window with title, subtitle and close button. Returns frame, content panel.
function UI.Frame( w, h, title, sub )
	local f = vgui.Create( "DFrame" )
	f:SetSize( math.min( w, ScrW() - S( 20 ) ), math.min( h, ScrH() - S( 20 ) ) )
	f:Center()
	f:SetTitle( "" )
	f:ShowCloseButton( false )
	f:SetDraggable( false )
	f:DockPadding( S( 20 ), S( 72 ), S( 20 ), S( 20 ) )
	f.startTime = SysTime()
	f.Title = title
	f.Sub = sub
	f.Paint = function( self, pw, ph )
		Derma_DrawBackgroundBlur( self, self.startTime )
		UI.Box( 0, 0, pw, ph, C.bg )
		surface.SetDrawColor( C.accent )
		surface.DrawRect( 0, 0, pw, S( 3 ) )
		UI.Text( string.upper( self.Title or "" ), "LBR_UI_Title", S( 20 ), S( 14 ), C.text )
		if self.Sub then
			UI.Text( self.Sub, "LBR_UI_Small", S( 20 ), S( 48 ), C.dim )
		end
	end

	local close = vgui.Create( "DButton", f )
	close:SetText( "" )
	close:SetSize( S( 32 ), S( 32 ) )
	close:SetPos( f:GetWide() - S( 46 ), S( 16 ) )
	close.DoClick = function() f:Close() end
	close.Paint = function( self, cw, ch )
		local col = self:IsHovered() and C.bad or C.dim
		UI.Text( "X", "LBR_UI_Head", cw / 2, ch / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	f:MakePopup()
	f:SetKeyboardInputEnabled( false ) // keys (F3/F4 again, movement) keep working
	return f
end

// Scroll panel with a slim scrollbar
function UI.Scroll( parent )
	local sp = vgui.Create( "DScrollPanel", parent )
	local bar = sp:GetVBar()
	bar:SetWide( S( 6 ) )
	bar:SetHideButtons( true )
	bar.Paint = function( self, w, h ) UI.Box( 0, 0, w, h, Color( 255, 255, 255, 8 ) ) end
	bar.btnGrip.Paint = function( self, w, h ) UI.Box( 0, 0, w, h, Color( 255, 255, 255, 60 ) ) end
	return sp
end

// Splits text into lines that fit in w (keeps the \n of the text)
function UI.Wrap( str, font, w )
	surface.SetFont( font )
	local out = {}
	for _, para in ipairs( string.Explode( "\n", str ) ) do
		local cur = ""
		for word in string.gmatch( para, "%S+" ) do
			local try = cur == "" and word or ( cur .. " " .. word )
			if cur ~= "" and surface.GetTextSize( try ) > w then
				out[#out + 1] = cur
				cur = word
			else
				cur = try
			end
		end
		out[#out + 1] = cur
	end
	return out
end

// Styled replacement of Derma_Query / Derma_Message:
// UI.Query( "text", "title", "Button 1", fn1, "Button 2", fn2, "Button 3", fn3 )
// The first button is the main one (gold), the others are grey. Functions may be nil.
function UI.Query( text, title, ... )
	local args = { ... }
	local btns = {}
	for i = 1, select( "#", ... ), 2 do
		if args[i] then btns[#btns + 1] = { label = args[i], fn = args[i + 1] } end
	end
	if #btns == 0 then btns[1] = { label = "OK" } end

	local w = S( 480 )
	local lines = UI.Wrap( text or "", "LBR_UI_Text", w - S( 40 ) )
	local lh = draw.GetFontHeight( "LBR_UI_Text" ) + S( 2 )
	local f = UI.Frame( w, S( 72 ) + #lines * lh + S( 70 ), title or "", nil )
	f:SetKeyboardInputEnabled( false )
	f:DoModal()

	local body = vgui.Create( "DPanel", f )
	body:Dock( FILL )
	body.Paint = function( self, bw, bh )
		for i, l in ipairs( lines ) do
			UI.Text( l, "LBR_UI_Text", 0, ( i - 1 ) * lh, C.text )
		end
	end

	local bar = vgui.Create( "DPanel", f )
	bar:Dock( BOTTOM )
	bar:SetTall( S( 32 ) )
	bar.Paint = nil
	for i = #btns, 1, -1 do
		local bt = btns[i]
		local b = UI.Button( bar, string.upper( bt.label ), i == 1 and C.accent or C.dim, function()
			f:Close()
			if bt.fn then bt.fn() end
		end )
		surface.SetFont( "LBR_UI_Small" )
		b:SetWide( math.max( S( 90 ), surface.GetTextSize( string.upper( bt.label ) ) + S( 30 ) ) )
		b:Dock( RIGHT )
		b:DockMargin( S( 8 ), 0, 0, 0 )
	end
	return f
end

// Section title with a line
function UI.Section( parent, label, countFn, col )
	local p = vgui.Create( "DPanel", parent )
	p:Dock( TOP )
	p:SetTall( S( 30 ) )
	p:DockMargin( 0, S( 8 ), 0, S( 4 ) )
	p.Paint = function( self, w, h )
		local txt = string.upper( label )
		if countFn then txt = txt .. "  " .. countFn() end
		surface.SetFont( "LBR_UI_Tiny" )
		local tw = surface.GetTextSize( txt )
		UI.Text( txt, "LBR_UI_Tiny", 0, h / 2, col or C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		UI.Box( tw + S( 10 ), h / 2, w - tw - S( 10 ), 1, C.line )
	end
	return p
end
