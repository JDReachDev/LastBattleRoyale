// Profiler: finds what makes the game slow or stutter.
//
//   lbr_profile 30     (client console; admins also profile the server)
//   lbr_profile_server 30   (server console only)
//
// For N seconds it measures, on the client and on the server:
// - every hook of every addon (Think, HUDPaint, PostDrawTranslucentRenderables...):
//   total time, calls, slowest call;
// - every net message received;
// - Think / Draw / DrawWorldModel... of the scripted entities and weapons
//   (CW 2.0, ArcCW, SCars, our loot...);
// - the frames (client) / ticks (server): average, worst 1%, spikes, and for
//   every spike what Lua code ran in it;
// - Lua memory: garbage made per second, and by every hook / function (the
//   garbage collector can stutter);
// - a timeline every 5 s (fps, slowest frame, frames over 33 / 50 ms, garbage),
//   to see whether the stutter is steady or comes at some moments;
// - for every spike: Lua in it, whether the garbage collector ran, the entities
//   created and the sounds started around it (first load of a model or a sound
//   from the disk stutters with no Lua in the frame);
// - the entities by class.
// The report is saved in garrysmod/data/lastbattleroyale/profile_client.txt and
// profile_server.txt (the server one is sent to the admin who asked for it).
// Nothing runs when no profile is going on.

LBR = LBR or {}

local ENT_FIELDS = { "Think", "Draw", "DrawTranslucent", "DrawWorldModel", "DrawWorldModelTranslucent",
	"ViewModelDrawn", "PreDrawViewModel", "PostDrawViewModel", "DrawHUD", "DrawHUDBackground",
	"CalcView", "GetViewModelPosition", "CalcViewModelView", "Tick", "PhysicsUpdate",
	"PrimaryAttack", "SecondaryAttack", "Reload", "Deploy", "Holster", "Use" }
local MAX_SPIKES = 60

local running = false
local frameId = 0

local gcount = collectgarbage

local function finish( s, st, m0, ... )
	local dt = SysTime() - st
	local dm = gcount( "count" ) - m0
	if dm > 0 then s.kb = s.kb + dm end
	s.t = s.t + dt
	s.n = s.n + 1
	if dt > s.max then s.max = dt end
	if s.fid ~= frameId then s.fid = frameId s.ft = 0 end
	s.ft = s.ft + dt
	return ...
end

local function wrapper( stats, key, fn )
	local s = stats[key]
	if not s then
		s = { key = key, t = 0, n = 0, max = 0, fid = -1, ft = 0, kb = 0 }
		stats[key] = s
	end
	return function( ... )
		local m0 = gcount( "count" )
		local st = SysTime()
		return finish( s, st, m0, fn( ... ) )
	end
end

local function ms( v ) return string.format( "%8.2f", v * 1000 ) end

local function buildReport( realm, seconds, stats, frames, spikes, mem, timeline )
	local out = {}
	local function add( ... ) out[#out + 1] = string.format( ... ) end
	add( "Last Battle Royale profile - %s - %s - %s - %d s", realm, game.GetMap(), os.date( "%Y-%m-%d %H:%M:%S" ), seconds )
	add( "Players: %d   Round state: %d", player.GetCount(), GetGlobalInt( "state", 0 ) )
	add( "" )

	// frames / ticks
	local sorted = table.Copy( frames )
	table.sort( sorted )
	local n = #sorted
	local sum = 0
	for _, v in ipairs( sorted ) do sum = sum + v end
	local avg = n > 0 and sum / n or 0
	local p99 = n > 0 and sorted[math.max( 1, math.floor( n * 0.99 ) )] or 0
	local worst = sorted[n] or 0
	add( "== %s ==", CLIENT and "FRAMES" or "TICKS (tickrate " .. math.Round( 1 / engine.TickInterval() ) .. ")" )
	add( "count %d   average %.2f ms (%.0f per s)   worst 1%% %.2f ms   slowest %.2f ms   spikes %d",
		n, avg * 1000, avg > 0 and 1 / avg or 0, p99 * 1000, worst * 1000, #spikes )
	local over = { 0.02, 0.033, 0.05, 0.1 }
	local counts, lost = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
	for _, v in ipairs( frames ) do
		for i, lim in ipairs( over ) do
			if v > lim then counts[i] = counts[i] + 1 lost[i] = lost[i] + v end
		end
	end
	for i, lim in ipairs( over ) do
		add( "  over %3d ms: %6d frames (%.1f s in them)", lim * 1000, counts[i], lost[i] )
	end
	add( "" )

	// timeline
	add( "== TIMELINE (every 5 s) ==" )
	add( "%7s %7s %8s %8s %6s %6s %9s", "time", "fps", "avg ms", "max ms", ">33ms", ">50ms", "garb MB" )
	for i, b in ipairs( timeline ) do
		if b.n > 0 then
			add( "%5d s %7.0f %8.2f %8.1f %6d %6d %9.1f", ( i - 1 ) * 5, b.n / math.max( b.sum, 0.001 ), b.sum / b.n * 1000, b.max * 1000, b.o33, b.o50, b.kb / 1024 )
		end
	end
	add( "" )

	// memory
	add( "== LUA MEMORY ==" )
	add( "now %.1f MB   garbage made %.2f MB/s   collected %.1f MB in %d s",
		collectgarbage( "count" ) / 1024, mem.alloc / 1024 / seconds, mem.freed / 1024, seconds )
	add( "" )

	// Lua time
	local list = {}
	local luaTotal = 0
	for _, s in pairs( stats ) do
		if s.n > 0 then
			list[#list + 1] = s
			luaTotal = luaTotal + s.t
		end
	end
	add( "== LUA TIME: %.1f ms per second measured (nested calls are counted twice) ==", luaTotal * 1000 / seconds )
	table.sort( list, function( a, b ) return a.t > b.t end )
	add( "%8s %8s %9s %8s %8s %8s  %s", "ms/s", "total", "calls", "avg ms", "max ms", "KB/s", "what" )
	for i = 1, math.min( 50, #list ) do
		local s = list[i]
		add( "%s %s %9d %s %s %8.1f  %s", ms( s.t / seconds ), ms( s.t ), s.n, ms( s.t / s.n ), ms( s.max ), s.kb / seconds, s.key )
	end
	add( "" )

	add( "== GARBAGE MADE (KB per second; a lot of it = garbage collector stutter) ==" )
	table.sort( list, function( a, b ) return a.kb > b.kb end )
	for i = 1, math.min( 25, #list ) do
		local s = list[i]
		if s.kb <= 0 then break end
		add( "%8.1f KB/s  %s  (%.2f KB per call)", s.kb / seconds, s.key, s.kb / s.n )
	end
	add( "" )

	add( "== SLOWEST SINGLE CALLS ==" )
	table.sort( list, function( a, b ) return a.max > b.max end )
	for i = 1, math.min( 25, #list ) do
		local s = list[i]
		add( "%s ms  %s  (%d calls)", ms( s.max ), s.key, s.n )
	end
	add( "" )

	// spikes
	add( "== SPIKES (frame / tick much slower than the others) ==" )
	if #spikes == 0 then add( "none" ) end
	for _, sp in ipairs( spikes ) do
		add( "at %5.1f s: %.1f ms   Lua in it %.1f ms   memory %.1f MB%s", sp.at, sp.dt * 1000, sp.lua * 1000, sp.mem / 1024,
			sp.gc > 0 and string.format( "   GARBAGE COLLECTOR freed %.1f MB", sp.gc / 1024 ) or "" )
		for _, e in ipairs( sp.top ) do add( "      %s ms  %s", ms( e.ft ), e.key ) end
		if #sp.created > 0 then add( "      created: %s", table.concat( sp.created, ", " ) ) end
		if #sp.sounds > 0 then add( "      sounds: %s", table.concat( sp.sounds, ", " ) ) end
	end
	add( "" )

	// entities
	local byClass, total = {}, 0
	for _, ent in ipairs( ents.GetAll() ) do
		local c = ent:GetClass()
		byClass[c] = ( byClass[c] or 0 ) + 1
		total = total + 1
	end
	local classes = {}
	for c, k in pairs( byClass ) do classes[#classes + 1] = { c = c, k = k } end
	table.sort( classes, function( a, b ) return a.k > b.k end )
	add( "== ENTITIES: %d ==", total )
	for i = 1, math.min( 25, #classes ) do add( "%6d  %s", classes[i].k, classes[i].c ) end

	return table.concat( out, "\n" )
end

// runs a profile for `seconds`, then calls done( report text )
function LBR.Profile( seconds, done )
	if running then return false end
	running = true
	local stats = {}
	local restore = {}

	// hooks of every addon (collected first: no changes while iterating)
	local hooks = {}
	for event, list in pairs( hook.GetTable() ) do
		for name, fn in pairs( list ) do
			if isfunction( fn ) then hooks[#hooks + 1] = { event, name, fn } end
		end
	end
	for _, h in ipairs( hooks ) do
		local event, name, fn = h[1], h[2], h[3]
		local w = wrapper( stats, "hook " .. event .. " : " .. tostring( name ), fn )
		hook.Add( event, name, w )
		restore[#restore + 1] = function()
			local cur = hook.GetTable()[event]
			if cur and cur[name] == w then hook.Add( event, name, fn ) end
		end
	end

	// gamemode functions (GM:Think, GM:HUDPaint, GM:PlayerTick...)
	local gm = GAMEMODE
	if gm then
		local fns = {}
		for k, fn in pairs( gm ) do
			if isfunction( fn ) and isstring( k ) then fns[#fns + 1] = { k, fn } end
		end
		for _, e in ipairs( fns ) do
			local k, fn = e[1], e[2]
			local orig = rawget( gm, k )
			local w = wrapper( stats, "GM:" .. k, fn )
			gm[k] = w
			restore[#restore + 1] = function()
				if gm[k] == w then gm[k] = orig end
			end
		end
	end

	// net messages
	for name, fn in pairs( table.Copy( net.Receivers ) ) do
		if isfunction( fn ) then
			local w = wrapper( stats, "net " .. name, fn )
			net.Receivers[name] = w
			restore[#restore + 1] = function()
				if net.Receivers[name] == w then net.Receivers[name] = fn end
			end
		end
	end

	// scripted entities and weapons
	for _, ent in ipairs( ents.GetAll() ) do
		if IsValid( ent ) and ent:IsScripted() then
			local tbl = ent:GetTable()
			for _, f in ipairs( ENT_FIELDS ) do
				local fn = tbl and tbl[f]
				if isfunction( fn ) then
					local orig = rawget( tbl, f )
					local w = wrapper( stats, ent:GetClass() .. ":" .. f, fn )
					tbl[f] = w
					restore[#restore + 1] = function()
						if IsValid( ent ) and ent:GetTable()[f] == w then ent:GetTable()[f] = orig end
					end
				end
			end
		end
	end

	// frames (client) / ticks (server)
	local frames, spikes, timeline = {}, {}, {}
	local mem = { alloc = 0, freed = 0 }
	// entities created and sounds started in the last 0.3 s (shown with the spikes)
	local recent = {}
	local function note( kind, text )
		recent[#recent + 1] = { t = SysTime(), kind = kind, text = text }
		if #recent > 200 then table.remove( recent, 1 ) end
	end
	hook.Add( "OnEntityCreated", "LBR_ProfileCreated", function( ent )
		if IsValid( ent ) then note( "c", ent:GetClass() ) end
	end )
	hook.Add( "EntityEmitSound", "LBR_ProfileSound", function( data )
		if data and data.SoundName then note( "s", data.SoundName ) end
	end )
	local startTime = SysTime()
	local last = SysTime()
	local memLast = collectgarbage( "count" )
	local avg
	local frameHook = CLIENT and "Think" or "Tick"
	local floor = CLIENT and 0.033 or engine.TickInterval() * 2
	hook.Add( frameHook, "LBR_ProfileFrame", function()
		local now = SysTime()
		local dt = now - last
		last = now
		frames[#frames + 1] = dt
		avg = avg and ( avg * 0.95 + dt * 0.05 ) or dt
		local m = collectgarbage( "count" )
		local gc = 0
		if m >= memLast then mem.alloc = mem.alloc + ( m - memLast ) else gc = memLast - m mem.freed = mem.freed + gc end
		local bi = math.floor( ( now - startTime ) / 5 ) + 1
		local b = timeline[bi]
		if not b then
			b = { n = 0, sum = 0, max = 0, o33 = 0, o50 = 0, kb = 0 }
			timeline[bi] = b
		end
		b.n = b.n + 1
		b.sum = b.sum + dt
		if dt > b.max then b.max = dt end
		if dt > 0.033 then b.o33 = b.o33 + 1 end
		if dt > 0.05 then b.o50 = b.o50 + 1 end
		if m > memLast then b.kb = b.kb + ( m - memLast ) end
		memLast = m
		if dt > math.max( avg * 2.5, floor ) and #spikes < MAX_SPIKES and #frames > 5 then
			local top, lua = {}, 0
			for _, s in pairs( stats ) do
				if s.fid == frameId and s.ft > 0 then
					top[#top + 1] = { key = s.key, ft = s.ft }
					lua = lua + s.ft
				end
			end
			table.sort( top, function( a, b ) return a.ft > b.ft end )
			for i = #top, 9, -1 do top[i] = nil end
			local created, sounds, seen = {}, {}, {}
			for _, r in ipairs( recent ) do
				if now - r.t < dt + 0.3 and not seen[r.kind .. r.text] and #created + #sounds < 16 then
					seen[r.kind .. r.text] = true
					if r.kind == "c" then created[#created + 1] = r.text else sounds[#sounds + 1] = r.text end
				end
			end
			spikes[#spikes + 1] = { at = now - startTime, dt = dt, lua = lua, mem = m, top = top, gc = gc, created = created, sounds = sounds }
		end
		frameId = frameId + 1
	end )

	timer.Simple( seconds, function()
		hook.Remove( frameHook, "LBR_ProfileFrame" )
		hook.Remove( "OnEntityCreated", "LBR_ProfileCreated" )
		hook.Remove( "EntityEmitSound", "LBR_ProfileSound" )
		for _, r in ipairs( restore ) do pcall( r ) end
		running = false
		local ok, text = pcall( buildReport, SERVER and "SERVER" or "CLIENT", seconds, stats, frames, spikes, mem, timeline )
		done( ok and text or ( "profile failed: " .. tostring( text ) ) )
	end )
	return true
end

local function save( name, text )
	file.CreateDir( "lastbattleroyale" )
	file.Write( "lastbattleroyale/" .. name, text )
end

if SERVER then
	util.AddNetworkString( "LBR_Profile" )

	local function allowed( ply )
		return not IsValid( ply ) or ply:IsAdmin() or game.SinglePlayer() or ply:IsListenServerHost()
	end

	net.Receive( "LBR_Profile", function( _, ply )
		if not allowed( ply ) then return end
		local seconds = math.Clamp( net.ReadUInt( 9 ), 5, 300 )
		LBR.Profile( seconds, function( text )
			save( "profile_server.txt", text )
			if not IsValid( ply ) then return end
			local data = util.Compress( text )
			if not data or #data > 60000 then return end
			net.Start( "LBR_Profile" )
				net.WriteUInt( #data, 16 )
				net.WriteData( data, #data )
			net.Send( ply )
		end )
	end )

	concommand.Add( "lbr_profile_server", function( ply, _, args )
		if IsValid( ply ) then return end // server console only
		local seconds = math.Clamp( math.floor( tonumber( args[1] ) or 30 ), 5, 300 )
		print( "[LBR] Profiling the server for " .. seconds .. " s..." )
		LBR.Profile( seconds, function( text )
			save( "profile_server.txt", text )
			print( "[LBR] Saved in data/lastbattleroyale/profile_server.txt" )
		end )
	end )
else
	local function announce( msg )
		chat.AddText( Color( 255, 210, 70 ), "[LBR] ", Color( 236, 239, 245 ), msg )
		print( "[LBR] " .. msg )
	end

	net.Receive( "LBR_Profile", function()
		local size = net.ReadUInt( 16 )
		local text = util.Decompress( net.ReadData( size ), 1024 * 1024 )
		if not text then return end
		save( "profile_server.txt", text )
		announce( "Server profile saved: garrysmod/data/lastbattleroyale/profile_server.txt" )
	end )

	concommand.Add( "lbr_profile", function( _, _, args )
		local seconds = math.Clamp( math.floor( tonumber( args[1] ) or 30 ), 5, 300 )
		if not LBR.Profile( seconds, function( text )
			save( "profile_client.txt", text )
			announce( "Client profile saved: garrysmod/data/lastbattleroyale/profile_client.txt" )
			MsgN( string.sub( text, 1, 3000 ) )
		end ) then
			announce( "A profile is already running" )
			return
		end
		local lp = LocalPlayer()
		if IsValid( lp ) and ( lp:IsAdmin() or game.SinglePlayer() ) then
			net.Start( "LBR_Profile" )
				net.WriteUInt( seconds, 9 )
			net.SendToServer()
			announce( "Profiling client and server for " .. seconds .. " s: play normally" )
		else
			announce( "Profiling the client for " .. seconds .. " s: play normally" )
		end
	end )
end
