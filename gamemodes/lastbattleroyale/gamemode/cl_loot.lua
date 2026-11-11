// Loot panel of the map editor (F8 -> Q -> "Loot and vehicles").
// Edits data/lastbattleroyale/loot.txt on the server (format in sh_loot.lua).

LBR = LBR or {}
local UI = LBR.UI
local S = UI.S
local C = UI.col

local L = { groups = nil, source = "default", sel = "BETTERWEAPONS", dirty = false }
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

function L.Rebuild()
	if not IsValid( L.rows ) then return end
	L.rows:Clear()
	local list = curList()
	for i, e in ipairs( list ) do
		local name, kind = classInfo( e.class )
		local row = L.rows:Add( "DPanel" )
		row:Dock( TOP )
		row:SetTall( S( 34 ) )
		row:DockMargin( 0, 0, 0, S( 2 ) )
		row.Paint = function( self, w, h )
			UI.Box( 0, 0, w, h, self:IsHovered() and C.rowHover or C.row )
			if e.on then UI.Accent( 0, 0, h, name and C.accent or C.bad ) end
			local a = e.on and 255 or 90
			// checkbox
			local bs = S( 16 )
			local bx, by = S( 12 ), ( h - bs ) / 2
			surface.SetDrawColor( 255, 255, 255, 120 )
			surface.DrawOutlinedRect( bx, by, bs, bs )
			if e.on then UI.Box( bx + S( 3 ), by + S( 3 ), bs - S( 6 ), bs - S( 6 ), C.good ) end
			UI.Text( UI.Fit( e.class, "LBR_UI_Text", S( 230 ) ), "LBR_UI_Text", S( 40 ), h / 2, Color( C.text.r, C.text.g, C.text.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			if name then
				UI.Text( UI.Fit( name, "LBR_UI_Small", S( 200 ) ), "LBR_UI_Small", S( 280 ), h / 2, Color( C.dim.r, C.dim.g, C.dim.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			else
				UI.Text( "NOT INSTALLED", "LBR_UI_Tiny", S( 280 ), h / 2, Color( C.bad.r, C.bad.g, C.bad.b, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			end
			local total = totalWeight( list )
			local chance = ( e.on and total > 0 ) and ( e.weight / total * 100 ) or 0
			UI.Text( e.on and string.format( "%.1f%%", chance ) or "OFF", "LBR_UI_Small", w - S( 180 ), h / 2, e.on and C.accent or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
		row.OnMousePressed = function( self, code )
			local x = self:CursorPos()
			if code == MOUSE_LEFT and x < S( 270 ) then
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

		local wang = vgui.Create( "DNumberWang", row )
		wang:Dock( RIGHT )
		wang:DockMargin( 0, S( 5 ), S( 6 ), S( 5 ) )
		wang:SetWide( S( 54 ) )
		wang:SetMinMax( 1, LBR.LootMaxWeight )
		wang:SetDecimals( 0 )
		wang:SetValue( e.weight )
		wang:SetTooltip( "Weight: 2 = twice as likely as an entry with 1" )
		wang.OnValueChanged = function( _, v )
			local nv = math.Clamp( math.floor( tonumber( v ) or 1 ), 1, LBR.LootMaxWeight )
			if nv ~= e.weight then
				e.weight = nv
				markDirty()
			end
		end

		// extra reserve ammo on pickup (weapons only)
		local isWeapon = not LBR.LootGroupById( L.sel ).vehicle and ( kind == "weapon" or not name )
		if isWeapon then
			local am = vgui.Create( "DNumberWang", row )
			am:Dock( RIGHT )
			am:DockMargin( 0, S( 5 ), S( 6 ), S( 5 ) )
			am:SetWide( S( 60 ) )
			am:SetMinMax( 0, LBR.LootMaxAmmo )
			am:SetDecimals( 0 )
			am:SetValue( e.ammo or 0 )
			local t = weapons.Get( e.class )
			local prim = t and t.Primary or {}
			am:SetTooltip( "Extra ammo given when this weapon is picked up (0 = only the loaded magazine)"
				.. ( prim.Ammo and ( "\nAmmo type: " .. tostring( prim.Ammo ) ) or "" )
				.. ( prim.ClipSize and prim.ClipSize > 0 and ( "\nMagazine: " .. prim.ClipSize ) or "" ) )
			am.OnValueChanged = function( _, v )
				local nv = math.Clamp( math.floor( tonumber( v ) or 0 ), 0, LBR.LootMaxAmmo )
				if nv ~= ( e.ammo or 0 ) then
					e.ammo = nv
					markDirty()
				end
			end
		else
			local sp = vgui.Create( "DPanel", row )
			sp:Dock( RIGHT )
			sp:SetWide( S( 66 ) )
			sp.Paint = nil
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

	local fr = UI.Frame( S( 1000 ), S( 720 ), "Loot and vehicles", "What spawns in the rounds. Weight = how likely, extra ammo = given on pickup; untick to disable. Saved in data/" .. LBR.LootFile )
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
			if sel then UI.Accent( 0, 0, h ) end
			local list = L.groups[g.id] or {}
			local on = 0
			for _, e in ipairs( list ) do if e.on then on = on + 1 end end
			UI.Text( g.name, "LBR_UI_Text", S( 12 ), S( 6 ), sel and C.accent or C.text )
			UI.Text( on .. " active / " .. #list, "LBR_UI_Tiny", S( 12 ), h - S( 18 ), on == 0 and C.bad or C.dim )
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
		local g = LBR.LootGroupById( L.sel )
		UI.Text( string.upper( g.name ), "LBR_UI_Head", 0, 0, C.text )
		UI.Text( g.desc, "LBR_UI_Small", 0, S( 26 ), C.dim )
		UI.Text( "CLASS", "LBR_UI_Tiny", S( 40 ), h - S( 12 ), C.dim )
		UI.Text( "NAME", "LBR_UI_Tiny", S( 280 ), h - S( 12 ), C.dim )
		UI.Text( "CHANCE", "LBR_UI_Tiny", w - S( 180 ), h - S( 12 ), C.dim, TEXT_ALIGN_RIGHT )
		if not g.vehicle then UI.Text( "EXTRA AMMO", "LBR_UI_Tiny", w - S( 104 ), h - S( 12 ), C.dim, TEXT_ALIGN_RIGHT ) end
		UI.Text( "WEIGHT", "LBR_UI_Tiny", w - S( 44 ), h - S( 12 ), C.dim, TEXT_ALIGN_RIGHT )
	end

	local addBtn = UI.Button( head, "+ ADD", C.good, openPicker )
	addBtn:SetSize( S( 110 ), S( 30 ) )
	head.PerformLayout = function( self, w ) addBtn:SetPos( w - S( 110 ), 0 ) end

	L.rows = UI.Scroll( right )
	L.rows:Dock( FILL )
	L.rows:DockMargin( 0, S( 4 ), 0, 0 )

	L.Rebuild()
end
