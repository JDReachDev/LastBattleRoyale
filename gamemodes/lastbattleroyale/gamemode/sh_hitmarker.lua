// Hitmarkers: Battlefield 6 Hitmarkers (Workshop 3550189961, by Darsu).
// "Dynamic position" (markers drawn where the bullet hit instead of on the
// crosshair) is always off, on the server and on every client:
// - server: its settings are enforced for everyone (bf6_override_enabled 1)
//   with bf6_override_hitmarker_dynamic 0;
// - client: bf6_hitmarker_dynamic 0, in case the override is turned off.
// Nothing happens if the addon is not installed.

if SERVER then
	local function forceServer()
		if not ConVarExists( "bf6_override_enabled" ) then return end
		if GetConVarNumber( "bf6_override_enabled" ) ~= 1 then
			RunConsoleCommand( "bf6_override_enabled", "1" )
		end
		if GetConVarNumber( "bf6_override_hitmarker_dynamic" ) ~= 0 then
			RunConsoleCommand( "bf6_override_hitmarker_dynamic", "0" )
		end
	end

	hook.Add( "InitPostEntity", "LBR_Hitmarker", forceServer )
	cvars.AddChangeCallback( "bf6_override_enabled", function() timer.Simple( 0, forceServer ) end, "LBR_Hitmarker" )
	cvars.AddChangeCallback( "bf6_override_hitmarker_dynamic", function() timer.Simple( 0, forceServer ) end, "LBR_Hitmarker" )
else
	local function forceClient()
		if not ConVarExists( "bf6_hitmarker_dynamic" ) then return end
		if GetConVarNumber( "bf6_hitmarker_dynamic" ) ~= 0 then
			RunConsoleCommand( "bf6_hitmarker_dynamic", "0" )
		end
	end

	hook.Add( "InitPostEntity", "LBR_Hitmarker", forceClient )
	cvars.AddChangeCallback( "bf6_hitmarker_dynamic", function() timer.Simple( 0, forceClient ) end, "LBR_Hitmarker" )
end
