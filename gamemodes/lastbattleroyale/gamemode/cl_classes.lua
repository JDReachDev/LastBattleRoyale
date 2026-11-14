// Classes panel of the map editor (F8 -> Q -> "Classes").
// Edits data/lastbattleroyale/classes.txt on the server (format in sh_classcfg.lua):
// name, description, health, armor, speed, loadout and unlock of every F3 class.

LBR = LBR or {}
local UI = LBR.UI
local S = UI.S
local C = UI.col

local E = { cfg = nil, source = "default", sel = nil, dirty = false }
LBR.ClassEditor = E

local function markDirty() E.dirty = true end

local function weaponLabel( cls )
	local w = weapons.Get( cls )
	if w and w.PrintName and w.PrintName ~= "" then
		local n = w.PrintName
		if string.sub( n, 1, 1 ) == "#" then n = language.GetPhrase( string.sub( n, 2 ) ) end
		return n
	end
	local e = scripted_ents.Get( cls )
	if e and e.PrintName then return e.PrintName end
end

function LBR.OpenClassEditor()
	net.Start( "LBR_Classes_Get" )
		net.WriteBool( true )
	net.SendToServer()
end

function LBR.OnClassesForEditor( cfg, source )
	E.cfg = table.Copy( cfg )
	E.source = source
	E.dirty = false
	if not E.sel or not E.cfg[E.sel] then E.sel = CLASSES and CLASSES[1] and CLASSES[1].class end
	if IsValid( E.frame ) then E.Rebuild() else E.Open() end
end

local function save()
	local data = util.Compress( LBR.ClassesToJSON( E.cfg ) )
	if not data or #data > 60000 then
		chat.AddText( C.bad, "[Classes] Too big to send" )
		return
	end
	net.Start( "LBR_Classes_Save" )
		net.WriteUInt( #data, 16 )
		net.WriteData( data, #data )
	net.SendToServer()
end

local function className( cls )
	return E.cfg and E.cfg[cls] and E.cfg[cls].name or cls
end

------------------------------------------------------------------------
// Weapon picker
------------------------------------------------------------------------

local function openPicker( onPick )
	if IsValid( E.picker ) then E.picker:Remove() end
	local fr = UI.Frame( S( 560 ), S( 600 ), "Add to the loadout", "Double click a weapon (or type a class name below)" )
	E.picker = fr
	fr:SetKeyboardInputEnabled( true )

	local search = vgui.Create( "DTextEntry", fr )
	search:Dock( TOP )
	search:SetTall( S( 30 ) )
	search:SetPlaceholderText( "Search..." )

	local bottom = vgui.Create( "DPanel", fr )
	bottom:Dock( BOTTOM )
	bottom:SetTall( S( 34 ) )
	bottom:DockMargin( 0, S( 8 ), 0, 0 )
	bottom.Paint = nil

	local lv = vgui.Create( "DListView", fr )
	lv:Dock( FILL )
	lv:DockMargin( 0, S( 8 ), 0, 0 )
	lv:AddColumn( "Class" )
	lv:AddColumn( "Name" )
	lv:AddColumn( "Category" )

	local all = {}
	for _, w in ipairs( weapons.GetList() ) do
		if w.ClassName and not string.find( w.ClassName, "_base", 1, true ) then
			all[#all + 1] = { class = w.ClassName, name = weaponLabel( w.ClassName ) or w.ClassName, cat = w.Category or "" }
		end
	end
	for _, c in ipairs( { "weapon_crowbar", "weapon_stunstick", "weapon_fists", "weapon_pistol", "weapon_357", "weapon_smg1", "weapon_shotgun", "weapon_slam", "weapon_frag" } ) do
		all[#all + 1] = { class = c, name = c, cat = "Half-Life 2" }
	end
	table.sort( all, function( a, b ) return a.class < b.class end )

	local function fill()
		lv:Clear()
		local q = string.lower( search:GetValue() or "" )
		local n = 0
		for _, it in ipairs( all ) do
			if q == "" or string.find( string.lower( it.class .. " " .. it.name .. " " .. it.cat ), q, 1, true ) then
				lv:AddLine( it.class, it.name, it.cat ).class = it.class
				n = n + 1
				if n >= 500 then break end
			end
		end
	end
	fill()
	search.OnChange = fill
	lv.DoDoubleClick = function( _, _, line )
		onPick( line.class )
		fr:Remove()
	end

	local manual = vgui.Create( "DTextEntry", bottom )
	manual:Dock( FILL )
	manual:SetPlaceholderText( "class name, e.g. cw_m1911" )
	local add = UI.Button( bottom, "ADD", C.good, function()
		local v = string.Trim( manual:GetValue() or "" )
		if LBR.LootValidClass( v ) then
			onPick( v )
			fr:Remove()
		end
	end )
	add:Dock( RIGHT )
	add:DockMargin( S( 6 ), 0, 0, 0 )
	add:SetWide( S( 80 ) )
end

------------------------------------------------------------------------
// Detail of one class
------------------------------------------------------------------------

local function fieldRow( parent, label, sub )
	local row = parent:Add( "DPanel" )
	row:Dock( TOP )
	row:SetTall( S( 40 ) )
	row:DockMargin( 0, 0, 0, S( 2 ) )
	row.Paint = function( _, w, h )
		UI.Box( 0, 0, w, h, C.row )
		UI.Text( label, "LBR_UI_Text", S( 12 ), S( 4 ), C.text )
		if sub then UI.Text( UI.Fit( sub, "LBR_UI_Tiny", w - S( 200 ) ), "LBR_UI_Tiny", S( 12 ), h - S( 16 ), C.dim ) end
	end
	return row
end

local function numberField( parent, label, sub, e, key )
	local l = LBR.ClassLimits[key]
	local row = fieldRow( parent, label, sub )
	local wang = vgui.Create( "DNumberWang", row )
	wang:Dock( RIGHT )
	wang:DockMargin( 0, S( 7 ), S( 10 ), S( 7 ) )
	wang:SetWide( S( 80 ) )
	wang:SetMinMax( l[1], l[2] )
	wang:SetDecimals( 0 )
	wang:SetValue( e[key] )
	wang.OnValueChanged = function( _, v )
		local nv = math.Clamp( math.floor( tonumber( v ) or l[1] ), l[1], l[2] )
		if nv ~= e[key] then e[key] = nv markDirty() end
	end
end

local function textField( parent, label, e, key, maxLen )
	local row = fieldRow( parent, label )
	row:SetTall( S( 66 ) )
	local entry = vgui.Create( "DTextEntry", row )
	entry:Dock( BOTTOM )
	entry:DockMargin( S( 12 ), 0, S( 10 ), S( 8 ) )
	entry:SetTall( S( 26 ) )
	entry:SetValue( e[key] or "" )
	entry.OnChange = function( self )
		e[key] = string.sub( self:GetValue() or "", 1, maxLen )
		markDirty()
	end
end

local function buildClass( rows, cls )
	local e = E.cfg[cls]
	if not e then return end

	UI.Section( rows, "Menu" )
	textField( rows, "Name", e, "name", 32 )
	textField( rows, "Description (F3 menu)", e, "desc", 200 )

	UI.Section( rows, "Stats" )
	numberField( rows, "Health", "Max and starting health", e, "health" )
	numberField( rows, "Armor", "Armor at spawn (0 = none)", e, "armor" )
	numberField( rows, "Walk speed %", "Percent of the server walk speed (100 = normal)", e, "walk" )
	numberField( rows, "Run speed %", "Percent of the server run speed (100 = normal)", e, "run" )

	UI.Section( rows, "Loadout", function() return #e.loadout .. " / " .. LBR.ClassMaxLoadout end )
	for i, w in ipairs( e.loadout ) do
		local row = rows:Add( "DPanel" )
		row:Dock( TOP )
		row:SetTall( S( 32 ) )
		row:DockMargin( 0, 0, 0, S( 2 ) )
		local label = weaponLabel( w )
		local t = LBR.TierOfClass and LBR.TierOfClass( w )
		row.Paint = function( _, rw, h )
			UI.Box( 0, 0, rw, h, C.row )
			UI.Accent( 0, 0, h, t and t.color or C.accent )
			UI.Text( w, "LBR_UI_Text", S( 12 ), h / 2, t and t.color or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			UI.Text( label or "NOT INSTALLED", "LBR_UI_Small", S( 280 ), h / 2, label and C.dim or C.bad, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end
		local del = UI.Button( row, "X", C.bad, function()
			table.remove( e.loadout, i )
			markDirty()
			E.Rebuild()
		end )
		del:Dock( RIGHT )
		del:DockMargin( S( 6 ), S( 4 ), S( 6 ), S( 4 ) )
		del:SetWide( S( 26 ) )
	end
	if #e.loadout < LBR.ClassMaxLoadout then
		local add = UI.Button( rows, "+ ADD WEAPON", C.good, function()
			openPicker( function( w )
				if #e.loadout >= LBR.ClassMaxLoadout then return end
				for _, x in ipairs( e.loadout ) do if x == w then return end end
				e.loadout[#e.loadout + 1] = w
				markDirty()
				surface.PlaySound( "buttons/button14.wav" )
				E.Rebuild()
			end )
		end )
		add:Dock( TOP )
		add:SetTall( S( 30 ) )
		add:DockMargin( 0, S( 2 ), 0, 0 )
	end

	UI.Section( rows, "Unlock: levels needed in other classes" )
	for i, n in ipairs( e.needs ) do
		local row = rows:Add( "DPanel" )
		row:Dock( TOP )
		row:SetTall( S( 36 ) )
		row:DockMargin( 0, 0, 0, S( 2 ) )
		row.Paint = function( _, rw, h )
			UI.Box( 0, 0, rw, h, C.row )
			UI.Text( "level", "LBR_UI_Small", rw - S( 150 ), h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
		local combo = vgui.Create( "DComboBox", row )
		combo:Dock( LEFT )
		combo:DockMargin( S( 10 ), S( 5 ), 0, S( 5 ) )
		combo:SetWide( S( 240 ) )
		for _, c in ipairs( CLASSES or {} ) do
			if c.class ~= cls then combo:AddChoice( className( c.class ), c.class, c.class == n.class ) end
		end
		combo.OnSelect = function( _, _, _, data )
			n.class = data
			markDirty()
		end
		local del = UI.Button( row, "X", C.bad, function()
			table.remove( e.needs, i )
			markDirty()
			E.Rebuild()
		end )
		del:Dock( RIGHT )
		del:DockMargin( S( 6 ), S( 5 ), S( 6 ), S( 5 ) )
		del:SetWide( S( 26 ) )
		local l = LBR.ClassLimits.level
		local wang = vgui.Create( "DNumberWang", row )
		wang:Dock( RIGHT )
		wang:DockMargin( 0, S( 5 ), S( 6 ), S( 5 ) )
		wang:SetWide( S( 70 ) )
		wang:SetMinMax( l[1], l[2] )
		wang:SetDecimals( 0 )
		wang:SetValue( n.level )
		wang.OnValueChanged = function( _, v )
			local nv = math.Clamp( math.floor( tonumber( v ) or 0 ), l[1], l[2] )
			if nv ~= n.level then n.level = nv markDirty() end
		end
	end
	if #e.needs == 0 then
		local free = rows:Add( "DPanel" )
		free:Dock( TOP )
		free:SetTall( S( 30 ) )
		free.Paint = function( _, w, h )
			UI.Text( "Unlocked from the start", "LBR_UI_Small", S( 12 ), h / 2, C.good, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end
	end
	if #e.needs < LBR.ClassMaxNeeds then
		local add = UI.Button( rows, "+ ADD REQUIREMENT", C.accent, function()
			local first
			for _, c in ipairs( CLASSES or {} ) do
				if c.class ~= cls then first = c.class break end
			end
			if not first then return end
			e.needs[#e.needs + 1] = { class = first, level = 5 }
			markDirty()
			E.Rebuild()
		end )
		add:Dock( TOP )
		add:SetTall( S( 30 ) )
		add:DockMargin( 0, S( 2 ), 0, S( 10 ) )
	end
end

function E.Rebuild()
	if not IsValid( E.rows ) then return end
	local scroll = E.rows:GetVBar() and E.rows:GetVBar():GetScroll() or 0
	E.rows:Clear()
	if E.sel then buildClass( E.rows, E.sel ) end
	timer.Simple( 0, function()
		if IsValid( E.rows ) and E.rows:GetVBar() then E.rows:GetVBar():SetScroll( scroll ) end
	end )
end

function E.Open()
	if not E.cfg then return end
	if IsValid( E.frame ) then E.frame:Remove() end
	if LBR.Editor and IsValid( LBR.Editor.menu ) then LBR.Editor.menu:Remove() end

	local fr = UI.Frame( S( 1000 ), S( 720 ), "Classes", "The F3 classes: stats, loadout, unlock. For the whole addon, saved in data/" .. LBR.ClassFile )
	E.frame = fr
	fr:SetKeyboardInputEnabled( true )
	local baseClose = fr.Close
	fr.Close = function( self )
		if E.dirty then
			UI.Query( "You have unsaved class changes.", "Classes",
				"Save and close", function() save() baseClose( self ) end,
				"Close without saving", function() E.dirty = false baseClose( self ) end,
				"Cancel" )
			return
		end
		if IsValid( E.picker ) then E.picker:Remove() end
		baseClose( self )
	end

	local bottom = vgui.Create( "DPanel", fr )
	bottom:Dock( BOTTOM )
	bottom:SetTall( S( 38 ) )
	bottom:DockMargin( 0, S( 10 ), 0, 0 )
	bottom.Paint = function( _, w, h )
		local txt = E.dirty and "Unsaved changes" or ( E.source == "file" and "Using data/" .. LBR.ClassFile or "Using classes.lua (no classes.txt yet)" )
		UI.Text( txt, "LBR_UI_Small", S( 330 ), h / 2, E.dirty and C.accent or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end

	local saveBtn = UI.Button( bottom, "SAVE", C.good, save )
	saveBtn:Dock( LEFT )
	saveBtn:SetWide( S( 150 ) )

	local resetBtn = UI.Button( bottom, "RESET TO DEFAULT", C.bad, function()
		UI.Query( "Delete data/" .. LBR.ClassFile .. " and go back to classes.lua?", "Reset classes", "Reset", function()
			net.Start( "LBR_Classes_Reset" )
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

	// classes on the left
	local left = UI.Scroll( fr )
	left:Dock( LEFT )
	left:SetWide( S( 240 ) )
	left:DockMargin( 0, 0, S( 14 ), 0 )
	for _, c in ipairs( CLASSES or {} ) do
		local b = left:Add( "DButton" )
		b:SetText( "" )
		b:Dock( TOP )
		b:SetTall( S( 46 ) )
		b:DockMargin( 0, 0, S( 6 ), S( 3 ) )
		b.DoClick = function()
			E.sel = c.class
			surface.PlaySound( "ui/buttonclick.wav" )
			if IsValid( E.picker ) then E.picker:Remove() end
			E.Rebuild()
		end
		b.Paint = function( self, w, h )
			local sel = E.sel == c.class
			local e = E.cfg[c.class] or {}
			UI.Box( 0, 0, w, h, ( sel or self:IsHovered() ) and C.rowHover or C.row )
			if sel then UI.Accent( 0, 0, h ) end
			UI.Text( e.name or c.class, "LBR_UI_Text", S( 12 ), S( 6 ), sel and C.accent or C.text )
			UI.Text( ( e.health or 0 ) .. " HP  " .. ( e.armor or 0 ) .. " AR  " .. ( e.run or 100 ) .. "% speed", "LBR_UI_Tiny", S( 12 ), h - S( 18 ), C.dim )
		end
	end

	E.rows = UI.Scroll( fr )
	E.rows:Dock( FILL )

	E.Rebuild()
end
