// Loot panel of the map editor (F8 -> Q -> "Loot and vehicles").
// Edits data/lastbattleroyale/loot.txt on the server (format in sh_loot.lua).

LBR = LBR or {}
local UI = LBR.UI
local S = UI.S
local C = UI.col

local L = { groups = nil, source = "default", sel = "GREEN", dirty = false }
LBR.LootEditor = L

------------------------------------------------------------------------
// Installed classes
------------------------------------------------------------------------

local function phrase( s )
	if isstring( s ) and string.sub( s, 1, 1 ) == "#" then return language.GetPhrase( string.sub( s, 2 ) ) end
	return s
end

// name, kind ("weapon" / "entity" / "vehicle") or nil when not installed
local function classInfo( class )
	local w = weapons.Get( class )
	if w then return phrase( w.PrintName ) or class, "weapon" end
	local e = scripted_ents.Get( class )
	if e then return phrase( e.PrintName ) or class, LBR.IsVehicleClass( class ) and "vehicle" or "entity" end
	local v = list.Get( "Vehicles" )[class]
	if v then return v.Name or class, "vehicle" end
end

local function installedList()
	local out = {}
	for _, w in ipairs( weapons.GetList() ) do
		if w.ClassName and not string.find( w.ClassName, "_base", 1, true ) then
			out[#out + 1] = { class = w.ClassName, name = phrase( w.PrintName ) or w.ClassName, cat = w.Category or "", kind = "weapon" }
		end
	end
	for class, t in pairs( scripted_ents.GetList() ) do
		local e = t.t or {}
		if not string.find( class, "_base", 1, true ) and ( e.Spawnable or e.AdminSpawnable or LBR.IsLootClass( class ) or LBR.IsVehicleClass( class ) ) then
			out[#out + 1] = { class = class, name = phrase( e.PrintName ) or class, cat = e.Category or "", kind = LBR.IsVehicleClass( class ) and "vehicle" or "entity" }
		end
	end
	table.sort( out, function( a, b ) return a.class < b.class end )
	return out
end

------------------------------------------------------------------------
// Net
------------------------------------------------------------------------

net.Receive( "LBR_Loot_Data", function()
	L.source = net.ReadString()
	local size = net.ReadUInt( 16 )
	local groups = LBR.LootFromJSON( util.Decompress( net.ReadData( size ), 1024 * 1024 ) or "" )
	if not groups then return end
	L.groups = groups
	L.dirty = false
	if IsValid( L.frame ) then L.Rebuild() else L.Open() end
end )

function LBR.OpenLootEditor()
	net.Start( "LBR_Loot_Get" )
	net.SendToServer()
end

local function save()
	local data = util.Compress( LBR.LootToJSON( L.groups ) )
	if not data or #data > 60000 then
		chat.AddText( C.bad, "[Loot] Too many entries to send" )
		return
	end
	net.Start( "LBR_Loot_Save" )
		net.WriteUInt( #data, 16 )
		net.WriteData( data, #data )
	net.SendToServer()
end

------------------------------------------------------------------------
// Panel
------------------------------------------------------------------------

local function curList()
	L.groups[L.sel] = L.groups[L.sel] or {}
	return L.groups[L.sel]
end

local function totalWeight( list )
	local t = 0
	for _, e in ipairs( list ) do if e.on then t = t + e.weight end end
	return t
end

local function markDirty() L.dirty = true end

local function addClass( class )
	class = string.Trim( class or "" )
	if not LBR.LootValidClass( class ) then return false end
	local list = curList()
	for _, e in ipairs( list ) do
		if e.class == class then
			e.on = true
			return false
		end
	end
	if #list >= LBR.LootMaxPerGroup then return false end
	// a weapon is in one tier only: adding it here takes it out of the others
	local g = LBR.LootGroupById( L.sel )
	if g and g.tier then
		for _, o in ipairs( LBR.LootGroups ) do
			if o.tier and o.id ~= g.id then
				local ol = L.groups[o.id] or {}
				for k = #ol, 1, -1 do
					if ol[k].class == class then table.remove( ol, k ) end
				end
			end
		end
	end
	list[#list + 1] = { class = class, weight = 1, on = true }
	markDirty()
	return true
end

// window to pick installed weapons / entities
local function openPicker()
	if IsValid( L.picker ) then L.picker:Remove() end
	local fr = UI.Frame( S( 620 ), S( 640 ), "Add to " .. LBR.LootGroupById( L.sel ).name, "Double click (or select and press Add). Search by class, name or category." )
	L.picker = fr
	fr:SetKeyboardInputEnabled( true )

	local search = vgui.Create( "DTextEntry", fr )
	search:Dock( TOP )
	search:SetTall( S( 30 ) )
	search:SetPlaceholderText( "Search..." )

	local bottom = vgui.Create( "DPanel", fr )
	bottom:Dock( BOTTOM )
	bottom:SetTall( S( 36 ) )
	bottom:DockMargin( 0, S( 8 ), 0, 0 )
	bottom.Paint = nil

	local lv = vgui.Create( "DListView", fr )
	lv:Dock( FILL )
	lv:DockMargin( 0, S( 8 ), 0, 0 )
	lv:SetMultiSelect( true )
	lv:AddColumn( "Class" )
	lv:AddColumn( "Name" )
	lv:AddColumn( "Category" )
	lv:AddColumn( "Type" ):SetFixedWidth( S( 70 ) )

	local all = installedList()
	local isVeh = LBR.LootGroupById( L.sel ).vehicle
	local function fill()
		lv:Clear()
		local q = string.lower( search:GetValue() or "" )
		local n = 0
		for _, it in ipairs( all ) do
			local wanted = isVeh and it.kind == "vehicle" or ( not isVeh and it.kind ~= "vehicle" )
			if wanted and ( q == "" or string.find( string.lower( it.class .. " " .. it.name .. " " .. it.cat ), q, 1, true ) ) then
				local line = lv:AddLine( it.class, it.name, it.cat, it.kind )
				line.class = it.class
				n = n + 1
				if n >= 500 then break end
			end
		end
	end
	fill()
	search.OnChange = fill

	local function addSelected()
		local added = 0
		for _, line in ipairs( lv:GetSelected() ) do
			if addClass( line.class ) then added = added + 1 end
		end
		if added > 0 then
			surface.PlaySound( "buttons/button14.wav" )
			L.Rebuild()
		end
	end
	lv.DoDoubleClick = function( _, _, line )
		if addClass( line.class ) then
			surface.PlaySound( "buttons/button14.wav" )
			L.Rebuild()
		end
	end

	local add = UI.Button( bottom, "ADD SELECTED", C.good, addSelected )
	add:Dock( RIGHT )
	add:SetWide( S( 160 ) )

	// class typed by hand (pack not installed on this client, etc.)
	local manual = vgui.Create( "DTextEntry", bottom )
	manual:Dock( LEFT )
	manual:SetWide( S( 220 ) )
	manual:SetPlaceholderText( "or type a class name" )
	local addManual = UI.Button( bottom, "ADD", C.accent, function()
		if addClass( manual:GetValue() ) then
			manual:SetValue( "" )
			surface.PlaySound( "buttons/button14.wav" )
			L.Rebuild()
		end
	end )
	addManual:Dock( LEFT )
	addManual:DockMargin( S( 6 ), 0, 0, 0 )
	addManual:SetWide( S( 70 ) )
end

local function numberBox( parent, minv, maxv, value, tip, onChange )
	local wang = vgui.Create( "DNumberWang", parent )
	wang:SetMinMax( minv, maxv )
	wang:SetDecimals( 0 )
	wang:SetValue( value )
	if tip then wang:SetTooltip( tip ) end
	wang.OnValueChanged = function( _, v )
		onChange( math.Clamp( math.floor( tonumber( v ) or minv ), minv, maxv ) )
	end
	return wang
end

// one line of the settings page: label on the left, control on the right
local function settingRow( label, sub, col )
	local row = L.rows:Add( "DPanel" )
	row:Dock( TOP )
	row:SetTall( S( 40 ) )
	row:DockMargin( 0, 0, 0, S( 2 ) )
	row.Paint = function( self, w, h )
		UI.Box( 0, 0, w, h, C.row )
		local x = S( 12 )
		if col then
			UI.Accent( 0, 0, h, col )
			LBR.DrawTierBox( S( 10 ), S( 10 ), S( 20 ), S( 20 ), col )
			x = S( 40 )
		end
		UI.Text( label, "LBR_UI_Text", x, S( 4 ), col or C.text )
		local s = isfunction( sub ) and sub() or sub
		if s then UI.Text( UI.Fit( s, "LBR_UI_Tiny", w - x - S( 120 ) ), "LBR_UI_Tiny", x, h - S( 16 ), C.dim ) end
	end
	return row
end

local function rowControl( ctrl, wide )
	ctrl:Dock( RIGHT )
	ctrl:DockMargin( 0, S( 7 ), S( 10 ), S( 7 ) )
	ctrl:SetWide( wide or S( 80 ) )
	return ctrl
end

// Magazines per tier + supply drop (whole addon, saved in loot.txt too)
local function buildSettings()
	L.groups.TIERS = L.groups.TIERS or {}
	L.groups.SUPPLY = LBR.LootCleanSupply( L.groups.SUPPLY )
	local T, SUP = L.groups.TIERS, L.groups.SUPPLY

	UI.Section( L.rows, "Ammo kits: magazines per tier" )
	for _, tier in ipairs( LBR.Tiers ) do
		local function mags( n, p ) return math.max( 1, math.floor( n * p / 100 ) ) end
		local row = settingRow( string.upper( tier.id ) .. " weapons", function()
			local p = T[tier.id] or tier.defaultPercent
			return string.format( "%d%% of a kit: small %d, medium %d, big %d magazines", p, mags( 6, p ), mags( 10, p ), mags( 24, p ) )
		end, tier.color )
		rowControl( numberBox( row, 1, 1000, T[tier.id] or tier.defaultPercent,
			"Percent of the magazines of an ammo kit given to a weapon of this tier", function( v )
				if v ~= T[tier.id] then T[tier.id] = v markDirty() end
			end ) )
	end

	UI.Section( L.rows, "Supply drop" )
	local function supNum( key, label, sub, minv, maxv )
		local row = settingRow( label, sub )
		rowControl( numberBox( row, minv, maxv, SUP[key], nil, function( v )
			if v ~= SUP[key] then SUP[key] = v markDirty() end
		end ) )
	end
	supNum( "time", "Opening time (seconds)", "Press E and stay close: the bar fills up in this time, then the loot comes out", 0, 60 )
	supNum( "purple", "Purple weapons", "Purple weapons that always come out", 0, 10 )
	supNum( "blue", "Blue weapons", "Blue weapons (each one can be a purple one, see below)", 0, 10 )
	supNum( "purple_chance", "Chance blue -> purple (%)", "Chance that each blue weapon is a purple one instead", 0, 100 )
	supNum( "purple_clips", "Purple magazines", "Purple magazines in a box next to the crate (any weapon takes them)", 0, 10 )

	local row = settingRow( "Items" )
	row:SetTall( S( 72 ) )
	row.Paint = function( _, w, h )
		UI.Box( 0, 0, w, h, C.row )
		UI.Text( "Items", "LBR_UI_Text", S( 12 ), S( 4 ), C.text )
		UI.Text( UI.Fit( "Classes that always come out, separated by commas (armor, medkits, ammo kits...)", "LBR_UI_Tiny", w - S( 24 ) ), "LBR_UI_Tiny", S( 12 ), S( 24 ), C.dim )
	end
	local entry = vgui.Create( "DTextEntry", row )
	entry:Dock( BOTTOM )
	entry:DockMargin( S( 12 ), 0, S( 10 ), S( 8 ) )
	entry:SetTall( S( 26 ) )
	entry:SetValue( table.concat( SUP.items, ", " ) )
	entry.OnChange = function( self )
		local items = {}
		for _, c in ipairs( string.Explode( ",", self:GetValue() or "" ) ) do
			c = string.Trim( c )
			if LBR.LootValidClass( c ) and #items < 20 then items[#items + 1] = c end
		end
		SUP.items = items
		markDirty()
	end
end

local function baseDamage( class )
	local t = weapons.Get( class )
	if not t then return end
	local prim = t.Primary or {}
	return tonumber( t.Damage ) or tonumber( prim.Damage ), tonumber( t.Shots ) or tonumber( t.Num ) or tonumber( prim.NumShots )
end

function L.Rebuild()
	if not IsValid( L.rows ) then return end
	L.rows:Clear()
	if L.sel == "SETTINGS" then
		buildSettings()
		return
	end
	local list = curList()
	local group = LBR.LootGroupById( L.sel )
	local tier = group.tier and LBR.TierById[group.tier]
	local accent = tier and tier.color or C.accent
	local hasDamage = group.tier ~= nil or group.id == "THROWABLES"
	for i, e in ipairs( list ) do
		local name, kind = classInfo( e.class )
		local row = L.rows:Add( "DPanel" )
		row:Dock( TOP )
		row:SetTall( S( 34 ) )
		row:DockMargin( 0, 0, 0, S( 2 ) )
		row.Paint = function( self, w, h )
			UI.Box( 0, 0, w, h, self:IsHovered() and C.rowHover or C.row )
			if e.on then UI.Accent( 0, 0, h, name and accent or C.bad ) end
			local a = e.on and 255 or 90
			// checkbox
			local bs = S( 16 )
			local bx, by = S( 12 ), ( h - bs ) / 2
			surface.SetDrawColor( 255, 255, 255, 120 )
			surface.DrawOutlinedRect( bx, by, bs, bs )
			if e.on then UI.Box( bx + S( 3 ), by + S( 3 ), bs - S( 6 ), bs - S( 6 ), C.good ) end
			UI.Text( UI.Fit( e.class, "LBR_UI_Text", S( 220 ) ), "LBR_UI_Text", S( 40 ), h / 2, Color( C.text.r, C.text.g, C.text.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			if name then
				UI.Text( UI.Fit( name, "LBR_UI_Small", S( 150 ) ), "LBR_UI_Small", S( 270 ), h / 2, Color( C.dim.r, C.dim.g, C.dim.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			else
				UI.Text( "NOT INSTALLED", "LBR_UI_Tiny", S( 270 ), h / 2, Color( C.bad.r, C.bad.g, C.bad.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			end
			local total = totalWeight( list )
			local chance = ( e.on and total > 0 ) and ( e.weight / total * 100 ) or 0
			UI.Text( e.on and string.format( "%.1f%%", chance ) or "OFF", "LBR_UI_Small", w - S( 240 ), h / 2, e.on and accent or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
		row.OnMousePressed = function( self, code )
			local x = self:CursorPos()
			if code == MOUSE_LEFT and x < S( 260 ) then
				e.on = not e.on
				markDirty()
				surface.PlaySound( "ui/buttonclick.wav" )
			end
		end
		row:SetCursor( "hand" )

		local del = UI.Button( row, "X", C.bad, function()
			table.remove( list, i )
			markDirty()
			L.Rebuild()
		end )
		del:Dock( RIGHT )
		del:DockMargin( S( 6 ), S( 5 ), S( 6 ), S( 5 ) )
		del:SetWide( S( 26 ) )

		local wang = numberBox( row, 1, LBR.LootMaxWeight, e.weight, "Weight: 2 = twice as likely as an entry with 1", function( nv )
			if nv ~= e.weight then e.weight = nv markDirty() end
		end )
		wang:Dock( RIGHT )
		wang:DockMargin( 0, S( 5 ), S( 6 ), S( 5 ) )
		wang:SetWide( S( 54 ) )

		// extra reserve ammo on pickup and damage percent (weapons only)
		local isWeapon = not group.vehicle and ( kind == "weapon" or not name )
		if isWeapon then
			local t = weapons.Get( e.class )
			local prim = t and t.Primary or {}
			local am = numberBox( row, 0, LBR.LootMaxAmmo, e.ammo or 0, "Extra ammo given when this weapon is picked up (0 = only the loaded magazine)"
				.. ( prim.Ammo and ( "\nAmmo type: " .. tostring( prim.Ammo ) ) or "" )
				.. ( prim.ClipSize and prim.ClipSize > 0 and ( "\nMagazine: " .. prim.ClipSize ) or "" ), function( nv )
				if nv ~= ( e.ammo or 0 ) then e.ammo = nv markDirty() end
			end )
			am:Dock( RIGHT )
			am:DockMargin( 0, S( 5 ), S( 6 ), S( 5 ) )
			am:SetWide( S( 60 ) )
		else
			local sp = vgui.Create( "DPanel", row )
			sp:Dock( RIGHT )
			sp:SetWide( S( 66 ) )
			sp.Paint = nil
		end
		if hasDamage and isWeapon then
			local d, shots = baseDamage( e.class )
			local dm = numberBox( row, 1, LBR.LootMaxDamage, e.damage or 100, "Damage of this weapon in percent (100 = as the weapon pack made it)"
				.. ( d and ( "\nBase damage: " .. d .. ( shots and shots > 1 and ( " x" .. shots ) or "" ) ) or "" ), function( nv )
				if nv ~= ( e.damage or 100 ) then
					e.damage = nv ~= 100 and nv or nil
					markDirty()
				end
			end )
			dm:Dock( RIGHT )
			dm:DockMargin( 0, S( 5 ), S( 6 ), S( 5 ) )
			dm:SetWide( S( 54 ) )
		end
	end
	if #list == 0 then
		local empty = L.rows:Add( "DPanel" )
		empty:Dock( TOP )
		empty:SetTall( S( 60 ) )
		empty.Paint = function( _, w, h )
			UI.Text( "Empty: nothing of this kind will spawn. Press ADD to pick something.", "LBR_UI_Small", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end
end

function L.Open()
	if not L.groups then return end
	if IsValid( L.frame ) then L.frame:Remove() end
	if LBR.Editor and IsValid( LBR.Editor.menu ) then LBR.Editor.menu:Remove() end

	local fr = UI.Frame( S( 1000 ), S( 720 ), "Loot and vehicles", "What spawns in the rounds. Weight = how likely, extra ammo = given on pickup, damage % = weapon damage; untick to disable. Saved in data/" .. LBR.LootFile )
	L.frame = fr
	fr:SetKeyboardInputEnabled( true )
	local baseClose = fr.Close
	fr.Close = function( self )
		if L.dirty then
			LBR.UI.Query( "You have unsaved loot changes.", "Loot and vehicles",
				"Save and close", function() save() baseClose( self ) end,
				"Close without saving", function() L.dirty = false baseClose( self ) end,
				"Cancel" )
			return
		end
		if IsValid( L.picker ) then L.picker:Remove() end
		baseClose( self )
	end

	// bottom bar
	local bottom = vgui.Create( "DPanel", fr )
	bottom:Dock( BOTTOM )
	bottom:SetTall( S( 38 ) )
	bottom:DockMargin( 0, S( 10 ), 0, 0 )
	bottom.Paint = function( _, w, h )
		local txt = L.dirty and "Unsaved changes" or ( L.source == "file" and "Using data/" .. LBR.LootFile or "Using the defaults of config.lua (no loot.txt yet)" )
		UI.Text( txt, "LBR_UI_Small", S( 330 ), h / 2, L.dirty and C.accent or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end

	local saveBtn = UI.Button( bottom, "SAVE", C.good, function() save() end )
	saveBtn:Dock( LEFT )
	saveBtn:SetWide( S( 150 ) )

	local resetBtn = UI.Button( bottom, "RESET TO DEFAULT", C.bad, function()
		LBR.UI.Query( "Delete data/" .. LBR.LootFile .. " and go back to the loot of config.lua?", "Reset loot", "Reset", function()
			net.Start( "LBR_Loot_Reset" )
			net.SendToServer()
		end, "Cancel" )
	end )
	resetBtn:Dock( LEFT )
	resetBtn:DockMargin( S( 8 ), 0, 0, 0 )
	resetBtn:SetWide( S( 160 ) )

	local backBtn = UI.Button( bottom, "BACK TO EDITOR MENU", C.blue, function()
		fr:Close()
		timer.Simple( 0, function()
			if not IsValid( fr ) and LBR.Editor and LBR.Editor.active and LBR.Editor.OpenMenu then LBR.Editor.OpenMenu() end
		end )
	end )
	backBtn:Dock( RIGHT )
	backBtn:SetWide( S( 200 ) )

	// groups on the left
	local left = vgui.Create( "DPanel", fr )
	left:Dock( LEFT )
	left:SetWide( S( 240 ) )
	left:DockMargin( 0, 0, S( 14 ), 0 )
	left.Paint = nil
	local function groupButton( id, h )
		local b = vgui.Create( "DButton", left )
		b:SetText( "" )
		b:Dock( TOP )
		b:SetTall( S( h ) )
		b:DockMargin( 0, 0, 0, S( 3 ) )
		b.DoClick = function()
			L.sel = id
			surface.PlaySound( "ui/buttonclick.wav" )
			if IsValid( L.picker ) then L.picker:Remove() end
			L.Rebuild()
		end
		return b
	end
	local sb = groupButton( "SETTINGS", 36 )
	sb.Paint = function( self, w, h )
		local sel = L.sel == "SETTINGS"
		UI.Box( 0, 0, w, h, ( sel or self:IsHovered() ) and C.rowHover or C.row )
		if sel then UI.Accent( 0, 0, h ) end
		UI.Text( "Tiers and supply drop", "LBR_UI_Text", S( 12 ), h / 2, sel and C.accent or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end
	for _, g in ipairs( LBR.LootGroups ) do
		if g.vehicle and g.id == "CARS" then UI.Section( left, "Vehicles" ) end
		local b = vgui.Create( "DButton", left )
		b:SetText( "" )
		b:Dock( TOP )
		b:SetTall( S( 44 ) )
		b:DockMargin( 0, 0, 0, S( 3 ) )
		b.DoClick = function()
			L.sel = g.id
			surface.PlaySound( "ui/buttonclick.wav" )
			if IsValid( L.picker ) then L.picker:Remove() end
			L.Rebuild()
		end
		b.Paint = function( self, w, h )
			local sel = L.sel == g.id
			UI.Box( 0, 0, w, h, ( sel or self:IsHovered() ) and C.rowHover or C.row )
			local tier = g.tier and LBR.TierById[g.tier]
			if sel then UI.Accent( 0, 0, h, tier and tier.color ) end
			local list = L.groups[g.id] or {}
			local on = 0
			for _, e in ipairs( list ) do if e.on then on = on + 1 end end
			local x = S( 12 )
			if tier then
				LBR.DrawTierBox( w - S( 34 ), S( 10 ), S( 24 ), S( 24 ), tier.color )
			end
			UI.Text( g.name, "LBR_UI_Text", x, S( 6 ), tier and tier.color or ( sel and C.accent or C.text ) )
			UI.Text( on .. " active / " .. #list, "LBR_UI_Tiny", x, h - S( 18 ), on == 0 and C.bad or C.dim )
		end
	end

	// right: header + rows
	local right = vgui.Create( "DPanel", fr )
	right:Dock( FILL )
	right.Paint = nil

	local head = vgui.Create( "DPanel", right )
	head:Dock( TOP )
	head:SetTall( S( 58 ) )
	head.Paint = function( _, w, h )
		if L.sel == "SETTINGS" then
			UI.Text( "TIERS AND SUPPLY DROP", "LBR_UI_Head", 0, 0, C.text )
			UI.Text( "For the whole addon (every map). Saved in data/" .. LBR.LootFile .. " with the loot.", "LBR_UI_Small", 0, S( 26 ), C.dim )
			return
		end
		local g = LBR.LootGroupById( L.sel )
		local tier = g.tier and LBR.TierById[g.tier]
		local x = 0
		if tier then
			LBR.DrawTierBox( 0, S( 2 ), S( 22 ), S( 22 ), tier.color )
			x = S( 30 )
		end
		UI.Text( string.upper( g.name ), "LBR_UI_Head", x, 0, tier and tier.color or C.text )
		UI.Text( g.desc, "LBR_UI_Small", 0, S( 26 ), C.dim )
		UI.Text( "CLASS", "LBR_UI_Tiny", S( 40 ), h - S( 12 ), C.dim )
		UI.Text( "NAME", "LBR_UI_Tiny", S( 270 ), h - S( 12 ), C.dim )
		UI.Text( "CHANCE", "LBR_UI_Tiny", w - S( 240 ), h - S( 12 ), C.dim, TEXT_ALIGN_RIGHT )
		if tier or g.id == "THROWABLES" then UI.Text( "DAMAGE %", "LBR_UI_Tiny", w - S( 170 ), h - S( 12 ), C.dim, TEXT_ALIGN_RIGHT ) end
		if not g.vehicle then UI.Text( "EXTRA AMMO", "LBR_UI_Tiny", w - S( 104 ), h - S( 12 ), C.dim, TEXT_ALIGN_RIGHT ) end
		UI.Text( "WEIGHT", "LBR_UI_Tiny", w - S( 44 ), h - S( 12 ), C.dim, TEXT_ALIGN_RIGHT )
	end

	local addBtn = UI.Button( head, "+ ADD", C.good, openPicker )
	addBtn:SetSize( S( 110 ), S( 30 ) )
	head.PerformLayout = function( self, w ) addBtn:SetPos( w - S( 110 ), 0 ) end
	head.Think = function() addBtn:SetVisible( L.sel ~= "SETTINGS" ) end

	L.rows = UI.Scroll( right )
	L.rows:Dock( FILL )
	L.rows:DockMargin( 0, S( 4 ), 0, 0 )

	L.Rebuild()
end
