
CLASSES = {}

local class = {}

function class.Add(classtable)
	table.ForceInsert(CLASSES, classtable)
end

function class.Get(classname)
	for k,v in pairs(CLASSES) do
		if v["class"] == classname then
			return v
		end
	end
end

/*
class.Add({
	name = "Example",
	class = "class_example",
	customcheck = function(ply)
		return ply:IsUserGroup( "vip" ) // this class is only for vips
	end,
	customcheckfailmsg = "You must be VIP to use this class",
	classesneeded = {
		{
			class = "class_sniper", // To use this class, you need to have 10 level on sniper
			level = 10
		},
		{
			class = "class_commando", // And you need to have 5 level on commando
			level = 5
		}
	}
})
*/

class.Add({
	name = "Recruit",
	class = "class_default",
	classesneeded = {},
	premium = false
})

class.Add({
	name = "Russian",
	class = "class_russian",
	classesneeded = {},
	premium = false
})

class.Add({
	name = "Sprinter",
	class = "class_sprinter",
	classesneeded = {
		{
			class = "class_default",
			level = 5
		}
	},
	premium = false
})

class.Add({
	name = "Traceur",
	class = "class_traceur",
	classesneeded = {
		{
			class = "class_default",
			level = 10
		}
	},
	premium = false
})

class.Add({
	name = "Mercenary",
	class = "class_mercenary",
	classesneeded = {
		{
			class = "class_sprinter",
			level = 10
		}
	},
	premium = false
})

class.Add({
	name = "Scout",
	class = "class_scout",
	classesneeded = {
		{
			class = "class_mercenary",
			level = 15
		}
	},
	premium = false
})

class.Add({
	name = "Soldier",
	class = "class_soldier",
	classesneeded = {
		{
			class = "class_scout",
			level = 25
		}
	},
	premium = false
})

class.Add({
	name = "Medic",
	class = "class_medic",
	classesneeded = {
		{
			class = "class_soldier",
			level = 25
		}
	},
	premium = false
})


class.Add({
	name = "Veteran",
	class = "class_veteran",
	classesneeded = {
		{
			class = "class_default",
			level = 15
		},
		{
			class = "class_sprinter",
			level = 15
		},
		{
			class = "class_mercenary",
			level = 15
		},
		{
			class = "class_scout",
			level = 15
		},
		{
			class = "class_soldier",
			level = 15
		}
	}
})

// Shown in the F3 menu. Keep "loadout" in sync with PLAYER:Loadout() in player_class/<class>.lua.
// (player_class/class_officer.lua exists but is not registered above: add a class.Add to enable it.)
CLASS_INFO = {
	class_default   = { desc = "Balanced starter class.", loadout = { "weapon_crowbar" } },
	class_russian   = { desc = "Starts with a pistol, but dies to anything.", loadout = { "weapon_fists", "cw_makarov" } },
	class_sprinter  = { desc = "Fast and light, with a smoke to get away.", loadout = { "cw_extrema_ratio_official", "cw_smoke_grenade" } },
	class_traceur   = { desc = "The fastest runner, but very fragile.", loadout = { "cw_shorty" } },
	class_mercenary = { desc = "Tough and slow, starts with a pistol.", loadout = { "weapon_crowbar", "cw_m1911" } },
	class_scout     = { desc = "Quick, with a knife and a SLAM mine.", loadout = { "cw_extrema_ratio_official", "weapon_slam" } },
	class_soldier   = { desc = "A pistol and a frag grenade from the start.", loadout = { "weapon_crowbar", "cw_p99", "cw_frag_grenade" } },
	class_medic     = { desc = "Extra health and an adrenaline shot.", loadout = { "weapon_crowbar", "sg_adrenaline" } },
	class_veteran   = { desc = "Fast and tough: for those who mastered every class.", loadout = { "weapon_crowbar" } },
	class_officer   = { desc = "Stunstick and a shotgun.", loadout = { "weapon_stunstick", "cw_shorty" } },
}
