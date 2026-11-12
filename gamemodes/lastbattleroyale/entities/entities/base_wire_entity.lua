// Placeholder for Wiremod's base_wire_entity.
// WAC Aircraft's seat connector (a Sandbox tool entity) does
// include( "entities/base_wire_entity.lua" ): without Wiremod the file is missing
// and the game prints "Couldn't include file 'entities/base_wire_entity.lua'" at
// every start. The helicopters do not use it. Like Wiremod's file, it makes an
// entity based on base_gmodentity; with Wiremod installed its own file is used.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Wire Entity"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.IsWire = true
