local load_time_start = os.clock()

-- water levels which belong to sea
local levels = {}

local newlevel
-- increases water height from pos
local function increase_height(pos)
	for i = pos.y+1, newlevel do
		pos.y = i
		local nd = minetest.get_node(pos).name
		if nd == "default:water_flowing"
		or nd == "air" then
			minetest.set_node(pos, {name = "default:water_source"})
		else
			return
		end
	end
end

-- decreases water height from pos
local function decrease_height(pos)
	for i = pos.y, newlevel+1, -1 do
		pos.y = i
		local nd = minetest.get_node(pos).name
		if nd == "default:water_source" then
			minetest.remove_node(pos)
		else
			return
		end
	end
end

local change_height
-- sets the height change function
local function update_funcs(y)
	if newlevel > y then
		change_height = increase_height
	elseif newlevel < y then
		change_height = decrease_height
	end
end

local startlev
-- updates water level value
local function update_levels()
	startlev = tonumber(minetest.setting_get("water_level")) or 1
	newlevel = tonumber(minetest.setting_get("water_level_new")) or startlev
	levels[startlev] = true
	levels[newlevel] = true
	--save_levels()
end
update_levels()

-- override water level setting that the newest values are known
local set_setting = core.setting_set
function core.setting_set(name, v, ...)
	if name == "water_level"
	or name == "water_level_new" then
		v = tonumber(v) or startlev
		local rv = set_setting(name, v, ...)
		update_levels()
		return rv
	end
	return set_setting(name, v, ...)
end

-- not every water source should be changeable
local function water_changeable(pos)
	if minetest.get_node(pos).name ~= "default:water_source" then
		return false
	end
	if minetest.find_node_near(pos, 1, {"air", "default:water_flowing"}) then
		return true
	end
	return false
end

-- table iteration instead of recursion
local function level_water(pos)
	update_funcs(pos.y)
	local tab = {pos}
	local tab_avoid = {[pos.x.." "..pos.y.." "..pos.z] = true}
	local num = 2
	while tab[1] do
		for n,p in pairs(tab) do
			for i = -1,1,2 do
				for _,p2 in pairs({
					{x=p.x+i, y=p.y, z=p.z},
					{x=p.x, y=p.y, z=p.z+i},
				}) do
					local pstr = p2.x.." "..p2.y.." "..p2.z
					if not tab_avoid[pstr]
					and water_changeable(p2) then
						change_height(p2)
						tab_avoid[pstr] = true
						num = num+1
						table.insert(tab, p2)
						--[[if max
						and num > max then
							return false
						end--]]
					end
				end
			end
			tab[n] = nil
		end
	end
	return num
end

-- change water heights with abm
minetest.register_abm({
	nodenames = {"default:water_source"},
	neighbors = {"air", "default:water_flowing"},
	interval = 1,
	chance = 1,
	action = function(pos)
		if not levels[pos.y]
		or newlevel == pos.y then
			return
		end
		level_water(pos)
	end,
})


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[water_level_change] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
