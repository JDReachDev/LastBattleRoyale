// Server side of the F3 class menu: sends the level / EXP of every class
// (saved in PData) so the menu can show progress and what is unlocked.

util.AddNetworkString( "LBR_ClassInfo" )

local function classLevel( ply, cls )
	// the class in use has live values, the others are saved in PData
	if player_manager.GetPlayerClass( ply ) == cls and ply.GetLevel then
		return tonumber( ply:GetLevel() ) or 0, tonumber( ply:GetEXP() ) or 0
	end
	return tonumber( ply:GetPData( cls .. "_level", 0 ) ) or 0, tonumber( ply:GetPData( cls .. "_exp", 0 ) ) or 0
end

function LBR_SendClassInfo( ply )
	net.Start( "LBR_ClassInfo" )
		net.WriteString( player_manager.GetPlayerClass( ply ) or "" ) // class in use
		net.WriteString( ply.class or "" )                             // class for the next round
		net.WriteBool( ply.Premium == true )
		net.WriteUInt( #CLASSES, 8 )
		for _, c in ipairs( CLASSES ) do
			local lvl, exp = classLevel( ply, c.class )
			net.WriteString( c.class )
			net.WriteUInt( math.Clamp( lvl, 0, 65535 ), 16 )
			net.WriteUInt( math.Clamp( exp, 0, 2 ^ 31 ), 32 )
		end
	net.Send( ply )
end

net.Receive( "LBR_ClassInfo", function( len, ply )
	if ( ply.LBR_NextClassInfo or 0 ) > CurTime() then return end
	ply.LBR_NextClassInfo = CurTime() + 0.25
	LBR_SendClassInfo( ply )
end )
