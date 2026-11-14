AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

// Supply drop: E starts opening it (a bar fills up, SUPPLY_DROP.time seconds,
// also in the Loot editor). Stay close and alive until it is full; then the loot
// comes out around the crate: purple and blue weapons, armor, medkits... (what
// SUPPLY_DROP / the Loot editor says). Anyone can take it.

local OPEN_RANGE = 160

function ENT:Initialize()
	self:SetModel("models/blacksnow/supplycrate.mdl")
	self:SetGravity( 100 )
	self:SetHealth( 6000 )
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if phys and phys:IsValid() then
		phys:Wake()
	end
end

function ENT:PhysicsCollide(data, physobj)
end

local function cfg()
	return LBR.SupplyConfig or LBR.LootCleanSupply( SUPPLY_DROP )
end

local function pick( pool )
	pool = pool or {}
	for _ = 1, 8 do
		local class = pool[math.random( #pool )]
		if class and ( weapons.GetStored( class ) or scripted_ents.GetStored( class ) ) then return class end
	end
end

function ENT:Use( activator )
	if self.LBR_Looted or self:GetOpenEnd() > 0 then return end
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:Team() ~= TEAM_CONT then return end
	local t = cfg().time
	self.Opener = activator
	self:SetOpener( activator )
	self:SetOpenStart( CurTime() )
	self:SetOpenEnd( CurTime() + math.max( t, 0.1 ) )
	self:EmitSound( "items/ammocrate_open.wav", 70, 100 )
end

function ENT:Think()
	local ending = self:GetOpenEnd()
	if ending > 0 and not self.LBR_Looted then
		local p = self.Opener
		if not IsValid( p ) or not p:Alive() or p:Team() ~= TEAM_CONT or p:GetPos():Distance( self:GetPos() ) > OPEN_RANGE then
			// stopped: anyone can start again
			self:SetOpenEnd( 0 )
			self:SetOpener( NULL )
			self.Opener = nil
			if IsValid( p ) then LBR.Notify( p, "Supply drop: you moved away", "bad", 2 ) end
		elseif CurTime() >= ending then
			self:Open()
			return
		end
	end
	self:NextThink( CurTime() + 0.1 )
	return true
end

function ENT:Open()
	self.LBR_Looted = true
	local c = cfg()
	local list = {}
	for _ = 1, c.purple do list[#list + 1] = pick( ITEMS.PURPLE ) end
	for _ = 1, c.blue do
		list[#list + 1] = math.random( 100 ) <= c.purple_chance and pick( ITEMS.PURPLE ) or pick( ITEMS.BLUE )
	end
	for _, class in ipairs( c.items ) do list[#list + 1] = class end

	local center = self:WorldSpaceCenter()
	local base = self:GetPos() + Vector( 0, 0, 10 )
	local n = #list
	for i, class in ipairs( list ) do
		local it = ents.Create( class )
		if IsValid( it ) then
			// in a ring around the crate, not inside a wall
			local a = ( i / math.max( n, 1 ) ) * math.pi * 2
			local pos = base + Vector( math.cos( a ) * 55, math.sin( a ) * 55, 0 )
			local tr = util.TraceLine( { start = center, endpos = pos, mask = MASK_SOLID_BRUSHONLY } )
			if tr.Hit then pos = tr.HitPos + tr.HitNormal * 12 end
			it:SetPos( pos )
			it:SetAngles( Angle( 0, math.random( 0, 359 ), 0 ) )
			it:Spawn()
			it.kanadelootable = true
			it.LBR_Ammo = LBR.LootAmmo and LBR.LootAmmo[class]
			local phys = it:GetPhysicsObject()
			if IsValid( phys ) then phys:SetVelocity( ( pos - center ):GetNormalized() * 60 + Vector( 0, 0, 120 ) ) end
		end
	end

	// purple magazines, in their box on top of the crate spot
	if ( c.purple_clips or 0 ) > 0 and LBR.ClipBox then
		LBR.ClipBox( "purple", c.purple_clips, base + Vector( 0, 0, 12 ), Vector( 0, 0, 120 ), 0 )
	end

	self:EmitSound( "items/ammo_pickup.wav", 75, 90 )
	local p = self.Opener
	if IsValid( p ) then LBR.Notify( p, "Supply drop opened", "good", 2 ) end
	local ed = EffectData()
	ed:SetOrigin( center )
	util.Effect( "cball_explode", ed )
	self:Remove()
end
