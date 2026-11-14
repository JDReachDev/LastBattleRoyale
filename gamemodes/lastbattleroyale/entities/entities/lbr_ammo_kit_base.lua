// Ammo kit (base of lbr_ammo_small / lbr_ammo_medium / lbr_ammo_big).
// E opens a small menu with the three magazine colors (sh_clips.lua): you pick
// what you take, one magazine per click (or key 1 / 2 / 3), right click takes as
// many of that color as the kit has. Mags = green magazines in the kit; a
// magazine of a tier costs 100 / percent of the tier (sh_tiers.lua: 1 / 2 / 4 by
// default): a kit of 8 = 8 green, or 6 green + 1 blue, or 2 green + 1 blue + 1
// purple... When what is left is less than one magazine of the color you pick,
// you get that part of a magazine (2 green left = 0.5 purple). The kit
// disappears when empty.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ammo kit"
ENT.Category = "Last Battle Royale"
ENT.Spawnable = false
ENT.Mags = 8
ENT.Model = "models/items/boxmrounds.mdl"
ENT.LBR_AmmoKit = true

local USE_DIST = 140

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Charge" ) // what is left, in hundredths of a green magazine
end

// cost of one magazine of a color, in hundredths of a green magazine
local function colorCost( color )
	local t = LBR.TierById and LBR.TierById[color]
	return math.max( 1, math.Round( 10000 / math.max( t and t.percent or 100, 1 ) ) )
end
ENT.ColorCost = colorCost

// green magazines left ("6", "2.5")
function ENT:LeftText()
	return LBR.ClipText( self:GetCharge() / 100 )
end

if SERVER then
	util.AddNetworkString( "LBR_KitOpen" )
	util.AddNetworkString( "LBR_KitTake" )

	function ENT:Initialize()
		self:SetModel( self.Model )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )
		self:SetCharge( self.Mags * 100 )
		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then phys:Wake() end
	end

	function ENT:Use( ply )
		if not IsValid( ply ) or not ply:IsPlayer() or not ply:Alive() or self.Empty then return end
		net.Start( "LBR_KitOpen" )
		net.WriteEntity( self )
		net.Send( ply )
	end

	// one magazine of a color (or the part the kit has left, or the room left
	// under the limit of the color)
	function ENT:TakeOne( ply, color )
		local charge = self:GetCharge()
		if charge <= 0 then return false end
		local room = LBR.ClipRoom( ply, color )
		if room < 0.01 then return false, true end
		local cost = colorCost( color )
		local pay = math.min( cost, charge, math.ceil( room * cost ) )
		local n = math.min( pay / cost, room )
		LBR.ClipAdd( ply, color, n )
		self:SetCharge( charge - pay )
		if charge - pay <= 0 then
			self.Empty = true
			self:EmitSound( "items/ammo_pickup.wav" )
			self:Remove()
		end
		return n
	end

	net.Receive( "LBR_KitTake", function( _, ply )
		local kit = net.ReadEntity()
		local color = net.ReadString()
		local all = net.ReadBool()
		if not IsValid( kit ) or not kit.LBR_AmmoKit or kit.Empty or not ply:Alive() then return end
		if not LBR.TierById or not LBR.TierById[color] then return end
		if ply:GetShootPos():Distance( kit:WorldSpaceCenter() ) > USE_DIST + 40 then return end
		if ( ply.LBR_KitNext or 0 ) > CurTime() then return end
		ply.LBR_KitNext = CurTime() + 0.15
		local got, full = 0, false
		repeat
			local n, isFull = kit:TakeOne( ply, color )
			full = isFull
			if not n then break end
			got = got + n
		until not all or kit.Empty
		local t = LBR.TierById[color]
		if got <= 0 then
			if full then LBR.Notify( ply, "Your " .. t.name .. " magazines are full (x" .. LBR.ClipText( LBR.ClipMax( color ) ) .. ")", "bad", 2 ) end
			return
		end
		if not kit.Empty then kit:EmitSound( "items/ammo_pickup.wav", 60, 115 ) end
		LBR.Notify( ply, "+" .. LBR.ClipText( got ) .. " " .. t.name .. " magazine" .. ( got > 1 and "s" or "" ) .. " (you: x" .. LBR.ClipText( LBR.GetClips( ply, color ) ) .. ", kit: " .. ( kit.Empty and "empty" or kit:LeftText() .. " green left" ) .. ")", "good", 2 )
	end )
else
	function ENT:Draw()
		self:DrawModel()
	end

	local menu
	local function S( v ) return math.Round( v * ScrH() / 1080 ) end

	local function take( kit, color, all )
		if not IsValid( kit ) then return end
		net.Start( "LBR_KitTake" )
		net.WriteEntity( kit )
		net.WriteString( color )
		net.WriteBool( all )
		net.SendToServer()
		surface.PlaySound( "ui/buttonclick.wav" )
	end

	local function close()
		if IsValid( menu ) then menu:Remove() end
		menu = nil
	end
	function LBR.KitMenuOpen() return IsValid( menu ) end

	local WHITE = Color( 235, 238, 245 )

	// the kit as a row of magazines (one per green magazine it holds), white;
	// hovering a color paints in that color (pulsing) the magazines one pick takes
	local function drawRow( kit, x, y, w, size, hoverColor )
		local charge = kit:GetCharge()
		local total = math.max( kit.Mags or 8, math.ceil( charge / 100 ) )
		local step = math.min( size * 0.8, w / total )
		size = math.min( size, step / 0.8 )
		local rowW = step * ( total - 1 ) + size * 0.6
		local sx0 = x + ( w - rowW ) / 2 - size * 0.2 // the icon is drawn from 0.2 to 0.8 of its box
		local cost = hoverColor and colorCost( hoverColor ) or 0
		local from = math.max( charge - cost, 0 ) // hundredths still there after the pick
		local hc = hoverColor and LBR.TierById[hoverColor].color
		local pulse = 150 + math.abs( math.sin( CurTime() * 6 ) ) * 105
		for i = 1, total do
			local lo = ( i - 1 ) * 100
			local full = math.Clamp( ( charge - lo ) / 100, 0, 1 )
			local keep = math.Clamp( ( from - lo ) / 100, 0, 1 )
			local ix = sx0 + ( i - 1 ) * step
			if hc and full > keep then
				// (part of) this one goes with the pick: colored, the rest stays white
				LBR.DrawClipIcon( ix, y, size, hc, pulse, full, keep, WHITE )
			else
				LBR.DrawClipIcon( ix, y, size, WHITE, full > 0 and 255 or 70, full )
			end
		end
	end

	local function open( kit )
		close()
		local colors = LBR.ClipColors()
		local bw, bh, gap = S( 170 ), S( 96 ), S( 8 )
		local w = bw * #colors + gap * ( #colors - 1 ) + S( 32 )
		local rowY, rowH = S( 44 ), S( 42 )
		local btnY = rowY + rowH + S( 14 )
		local h = btnY + bh + S( 34 )
		local f = vgui.Create( "DFrame" )
		menu = f
		f:SetSize( w, h )
		f:SetPos( ( ScrW() - w ) / 2, ScrH() * 0.55 )
		f:SetTitle( "" )
		f:ShowCloseButton( false )
		f:SetDraggable( false )
		f.Kit = kit
		local btns = {}
		f.Paint = function( self, pw, ph )
			surface.SetDrawColor( 10, 14, 24, 245 )
			surface.DrawRect( 0, 0, pw, ph )
			surface.SetDrawColor( 255, 210, 70 )
			surface.DrawRect( 0, 0, pw, S( 3 ) )
			if not IsValid( kit ) then return end
			draw.SimpleText( "PICK YOUR MAGAZINES", "LBR_UI_Head", S( 16 ), S( 12 ), color_white )
			draw.SimpleText( string.upper( kit.PrintName or "Ammo kit" ), "LBR_UI_Tiny", pw - S( 16 ), S( 18 ), Color( 150, 158, 175 ), TEXT_ALIGN_RIGHT )
			local hover
			for _, b in ipairs( btns ) do if b:IsHovered() then hover = b.Color end end
			drawRow( kit, S( 16 ), rowY, pw - S( 32 ), rowH, hover )
			draw.SimpleText( "Click or 1-" .. #colors .. ": take one   -   Right click: all in that color   -   E: close", "LBR_UI_Tiny", pw / 2, ph - S( 16 ), Color( 150, 158, 175 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		local opened = CurTime()
		f.Think = function( self )
			local lp = LocalPlayer()
			if not IsValid( kit ) or not lp:Alive() or lp:GetShootPos():Distance( kit:WorldSpaceCenter() ) > USE_DIST + 20 then close() return end
			// hit by someone: the menu goes away at once, you get your aim back (the zone
			// damage does not close it, sh_clips.lua)
			if ( LBR.LastEnemyHit or 0 ) > opened then close() return end
		end
		for i, color in ipairs( colors ) do
			local t = LBR.TierById[color]
			local cost = colorCost( color )
			local b = vgui.Create( "DButton", f )
			btns[i] = b
			b.Color = color
			b:SetText( "" )
			b:SetPos( S( 16 ) + ( i - 1 ) * ( bw + gap ), btnY )
			b:SetSize( bw, bh )
			b.DoClick = function() take( kit, color, false ) end
			b.DoRightClick = function() take( kit, color, true ) end
			b.Paint = function( self, pw, ph )
				if not IsValid( kit ) then return end
				local c = t.color
				local can = kit:GetCharge() / cost // how many of this color the kit still gives
				local room = LBR.ClipRoom( LocalPlayer(), color )
				local a = ( can > 0 and room >= 0.01 ) and 1 or 0.35
				surface.SetDrawColor( c.r, c.g, c.b, ( self:IsHovered() and 80 or 28 ) * a )
				surface.DrawRect( 0, 0, pw, ph )
				surface.SetDrawColor( c.r, c.g, c.b, 230 * a )
				surface.DrawOutlinedRect( 0, 0, pw, ph, self:IsHovered() and 3 or 2 )
				LBR.DrawClipIcon( S( 10 ), S( 10 ), S( 30 ), c, 255 * a, 1 )
				draw.SimpleText( string.upper( t.name ), "LBR_UI_Head", S( 38 ), S( 14 ), Color( c.r, c.g, c.b, 255 * a ) )
				draw.SimpleText( "[" .. i .. "]", "LBR_UI_Head", pw - S( 10 ), S( 12 ), Color( 255, 255, 255, 140 * a ), TEXT_ALIGN_RIGHT )
				// what one costs, as white magazines of the kit
				local n = cost / 100
				local isz = S( 20 )
				local step = isz * 0.75
				draw.SimpleText( "=", "LBR_UI_Text", S( 14 ), S( 56 ), Color( 255, 255, 255, 200 * a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				for k = 1, math.ceil( n ) do
					LBR.DrawClipIcon( S( 26 ) + ( k - 1 ) * step, S( 56 ) - isz / 2, isz, WHITE, 255 * a, math.min( n - ( k - 1 ), 1 ) )
				end
				local next1 = math.min( can, 1, room )
				draw.SimpleText( can <= 0 and "EMPTY" or ( room < 0.01 and "FULL" or ( next1 < 1 and "TAKE x" .. LBR.ClipText( next1 ) or "TAKE 1" ) ), "LBR_UI_Small", pw / 2, ph - S( 14 ), Color( 255, 255, 255, ( self:IsHovered() and 255 or 170 ) * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			end
		end
		f:MakePopup()
		f:SetKeyboardInputEnabled( false ) // you can still move; 1-3 and E are read below
	end

	net.Receive( "LBR_KitOpen", function()
		local kit = net.ReadEntity()
		if IsValid( kit ) then open( kit ) end
	end )

	// while the menu is open: slot keys take a color, E closes it
	hook.Add( "PlayerBindPress", "LBR_KitMenu", function( _, bind, pressed )
		if not IsValid( menu ) or not pressed then return end
		local n = tonumber( string.match( bind, "^slot(%d)$" ) or "" )
		local colors = LBR.ClipColors()
		if n and colors[n] then
			take( menu.Kit, colors[n], false )
			return true
		end
		if string.find( bind, "+use", 1, true ) then
			close()
			return true
		end
	end )
end
