// Map vote at the end of the match + admin map menu (F2).
// Vote candidates: only maps installed on the server that are playable, i.e. with a valid
// config in data/lastbattleroyale/maps/ (made with the F8 editor) or a built-in one (config.lua).
// The admin menu lists every installed map and says which ones are configured.

util.AddNetworkString( "LBR_MapVoteStart" )
util.AddNetworkString( "LBR_MapVote" )
util.AddNetworkString( "LBR_MapVoteUpdate" )
util.AddNetworkString( "LBR_MapVoteEnd" )
util.AddNetworkString( "LBR_MapList" )
util.AddNetworkString( "LBR_ChangeMap" )

local cvVote   = CreateConVar( "lbr_mapvote", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Map vote at the end of the match (only configured maps)" )
local cvRounds = CreateConVar( "lbr_mapvote_rounds", "1", { FCVAR_ARCHIVE }, "Matches on the same map before the vote" )
local cvTime   = CreateConVar( "lbr_mapvote_time", "20", { FCVAR_ARCHIVE }, "Seconds to vote" )
local cvMaps   = CreateConVar( "lbr_mapvote_maps", "8", { FCVAR_ARCHIVE }, "Max maps in the vote (the current map is always one of them)" )

local STATUS_NONE, STATUS_BROKEN, STATUS_CUSTOM, STATUS_BUILTIN = 0, 1, 2, 3

------------------------------------------------------------------------
// Map status
------------------------------------------------------------------------

local cache = {} // map -> { time = file time, status, info }

// status, info (errors when it can not be played)
function LBR.MapStatus( map )
	map = string.lower( map )
	local path = LBR.MapFileName( map )
	if file.Exists( path, "DATA" ) then
		local t = file.Time( path, "DATA" )
		local c = cache[map]
		if c and c.time == t then return c.status, c.info end
		local status, info
		local cfg, err = LBR.MapConfigFromJSON( file.Read( path, "DATA" ) )
		if cfg then
			local errors = LBR.ValidateMapConfig( cfg )
			if #errors == 0 then
				status = LBR.BuiltinMaps[map] and STATUS_BUILTIN or STATUS_CUSTOM
				info = ""
			else
				status, info = STATUS_BROKEN, table.concat( errors, ", " )
			end
		else
			status, info = STATUS_BROKEN, "Broken file: " .. tostring( err )
		end
		// same fallback as LoadCurrentMapConfig: a broken file falls back to the built-in config
		if status == STATUS_BROKEN and not cfg and LBR.BuiltinMaps[map] then
			local b = LBR.SanitizeMapConfig( LBR.BuiltinMaps[map] )
			if b and #LBR.ValidateMapConfig( b ) == 0 then status, info = STATUS_BUILTIN, "" end
		end
		cache[map] = { time = t, status = status, info = info }
		return status, info
	end
	if LBR.BuiltinMaps[map] then
		local b = LBR.SanitizeMapConfig( LBR.BuiltinMaps[map] )
		if b and #LBR.ValidateMapConfig( b ) == 0 then return STATUS_BUILTIN, "" end
		return STATUS_BROKEN, "Built-in config is incomplete"
	end
	return STATUS_NONE, "Not configured"
end

function LBR.InstalledMaps()
	local out = {}
	for _, f in ipairs( file.Find( "maps/*.bsp", "GAME" ) ) do
		out[#out + 1] = string.lower( string.StripExtension( f ) )
	end
	table.sort( out )
	return out
end

function LBR.PlayableMaps()
	local out = {}
	for _, map in ipairs( LBR.InstalledMaps() ) do
		local status = LBR.MapStatus( map )
		if status == STATUS_CUSTOM or status == STATUS_BUILTIN then out[#out + 1] = map end
	end
	return out
end

local function isAdmin( ply )
	return not IsValid( ply ) or ply:IsAdmin() or ( LBR.CanEdit and LBR.CanEdit( ply ) )
end

------------------------------------------------------------------------
// Map change
------------------------------------------------------------------------

function LBR.ChangeMap( map, delay )
	map = string.lower( map )
	if not file.Exists( "maps/" .. map .. ".bsp", "GAME" ) then return false end
	PrintMessage( HUD_PRINTTALK, "Changing map to " .. map .. "..." )
	SetGlobalString( "LBR_NextMap", map )
	timer.Create( "LBR_ChangeMap", delay or 3, 1, function()
		RunConsoleCommand( "changelevel", map )
	end )
	return true
end

------------------------------------------------------------------------
// Vote
------------------------------------------------------------------------

local vote // { maps = {}, votes = { [steamid] = index }, endTime }

local function tally()
	local counts = {}
	for i = 1, #vote.maps do counts[i] = 0 end
	for sid, idx in pairs( vote.votes ) do
		if counts[idx] and IsValid( player.GetBySteamID64( sid ) ) then counts[idx] = counts[idx] + 1 end
	end
	return counts
end

local function sendCounts()
	local counts = tally()
	net.Start( "LBR_MapVoteUpdate" )
		net.WriteUInt( #counts, 8 )
		for i = 1, #counts do net.WriteUInt( counts[i], 8 ) end
	net.Broadcast()
end

local function finishVote()
	if not vote then return end
	local counts = tally()
	local best, bestN = {}, -1
	for i, n in ipairs( counts ) do
		if n > bestN then best, bestN = { i }, n
		elseif n == bestN then best[#best + 1] = i end
	end
	local current = string.lower( game.GetMap() )
	local winner
	if bestN <= 0 then
		winner = current // nobody voted: stay
	else
		// on a tie the current map wins, otherwise a random one of the tied maps
		for _, i in ipairs( best ) do if vote.maps[i] == current then winner = current end end
		winner = winner or vote.maps[best[math.random( #best )]]
	end
	vote = nil
	SetGlobalBool( "LBR_MapVote", false )

	net.Start( "LBR_MapVoteEnd" )
		net.WriteString( winner )
	net.Broadcast()

	if winner ~= current and LBR.ChangeMap( winner, 4 ) then return end
	PrintMessage( HUD_PRINTTALK, "Map vote: staying on " .. current .. "." )
	LBR.RoundsThisMap = 0
	ReturnToLobby()
end

// Called by EndRound. Returns true when a vote started (it calls ReturnToLobby itself).
function LBR.MapVoteAtRoundEnd()
	LBR.RoundsThisMap = ( LBR.RoundsThisMap or 0 ) + 1
	if not cvVote:GetBool() then return false end
	if LBR.RoundsThisMap < math.max( cvRounds:GetInt(), 1 ) then return false end
	return LBR.StartMapVote()
end

function LBR.StartMapVote( duration )
	if vote then return true end
	local current = string.lower( game.GetMap() )
	local maps = {}
	for _, m in ipairs( LBR.ShuffledCopy( LBR.PlayableMaps() ) ) do
		if m ~= current then maps[#maps + 1] = m end
	end
	if #maps == 0 then return false end // only this map is configured: nothing to vote
	local max = math.max( cvMaps:GetInt(), 2 )
	while #maps > max - 1 do table.remove( maps ) end
	table.sort( maps )
	table.insert( maps, 1, current )

	duration = duration or math.max( cvTime:GetInt(), 5 )
	vote = { maps = maps, votes = {}, endTime = CurTime() + duration }
	SetGlobalBool( "LBR_MapVote", true )
	SetGlobalFloat( "LBR_PhaseEnd", vote.endTime )

	net.Start( "LBR_MapVoteStart" )
		net.WriteFloat( vote.endTime )
		net.WriteString( current )
		net.WriteUInt( #maps, 8 )
		for _, m in ipairs( maps ) do
			net.WriteString( m )
			net.WriteBool( LBR.BuiltinMaps[m] ~= nil )
		end
	net.Broadcast()

	timer.Remove( "timer_postround" )
	timer.Create( "LBR_MapVote", duration, 1, finishVote )
	PrintMessage( HUD_PRINTTALK, "Vote the next map! (" .. duration .. " seconds)" )
	return true
end

net.Receive( "LBR_MapVote", function( len, ply )
	if not vote then return end
	local idx = net.ReadUInt( 8 )
	if not vote.maps[idx] then return end
	if ( ply.LBR_NextMapVote or 0 ) > CurTime() then return end
	ply.LBR_NextMapVote = CurTime() + 0.3
	vote.votes[ply:SteamID64()] = idx
	sendCounts()
end )

// late joiners see the vote too
hook.Add( "PlayerInitialSpawn", "LBR_MapVote", function( ply )
	if not vote then return end
	timer.Simple( 3, function()
		if not vote or not IsValid( ply ) then return end
		net.Start( "LBR_MapVoteStart" )
			net.WriteFloat( vote.endTime )
			net.WriteString( string.lower( game.GetMap() ) )
			net.WriteUInt( #vote.maps, 8 )
			for _, m in ipairs( vote.maps ) do
				net.WriteString( m )
				net.WriteBool( LBR.BuiltinMaps[m] ~= nil )
			end
		net.Send( ply )
	end )
end )

concommand.Add( "lbr_mapvote_start", function( ply )
	if not isAdmin( ply ) then return end
	local function reply( msg ) if IsValid( ply ) then ply:ChatPrint( msg ) else print( msg ) end end
	if GetState() ~= STATE_NONE and GetState() ~= STATE_POST then
		reply( "Wait for the end of the match to start a map vote." )
		return
	end
	if not LBR.StartMapVote() then reply( "No other configured map to vote." ) end
end )

------------------------------------------------------------------------
// Admin map menu (F2)
------------------------------------------------------------------------

net.Receive( "LBR_MapList", function( len, ply )
	if not isAdmin( ply ) then return end
	if ( ply.LBR_NextMapList or 0 ) > CurTime() then return end
	ply.LBR_NextMapList = CurTime() + 1
	local maps = LBR.InstalledMaps()
	net.Start( "LBR_MapList" )
		net.WriteUInt( #maps, 16 )
		for _, m in ipairs( maps ) do
			local status, info = LBR.MapStatus( m )
			net.WriteString( m )
			net.WriteUInt( status, 2 )
			net.WriteString( string.Left( info or "", 200 ) )
		end
	net.Send( ply )
end )

net.Receive( "LBR_ChangeMap", function( len, ply )
	if not isAdmin( ply ) then return end
	local map = net.ReadString()
	if not LBR.ChangeMap( map, 3 ) then
		ply:ChatPrint( "Map " .. map .. " is not installed on the server." )
	end
end )

concommand.Add( "lbr_changemap", function( ply, cmd, args )
	if not isAdmin( ply ) then return end
	local map = args[1]
	local function reply( msg ) if IsValid( ply ) then ply:ChatPrint( msg ) else print( msg ) end end
	if not map then reply( "Usage: lbr_changemap <map>" ) return end
	if not LBR.ChangeMap( map, 3 ) then reply( "Map " .. map .. " is not installed on the server." ) end
end )
