
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
