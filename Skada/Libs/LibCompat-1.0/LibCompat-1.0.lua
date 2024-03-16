--
-- **LibCompat-1.0** provides few handy functions that can be embed to addons.
-- This library was originally created for Skada as of 1.8.50.
-- @author: Kader B (https://github.com/bkader/LibCompat-1.0)
--

local MAJOR, MINOR = "LibCompat-1.0-Skada", 37
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.embeds = lib.embeds or {}
lib.EmptyFunc = Multibar_EmptyFunc

local _G, pairs, type, max = _G, pairs, type, math.max
local setmetatable, rawset = setmetatable, rawset
local format, tonumber = format or string.format, tonumber
local _

local Dispatch
local GetUnitIdFromGUID

-------------------------------------------------------------------------------

local Units
do
	-- solo, group, pets and targets
	local solo = {"player", "pet"}
	local group = {player = true}
	local grouppet = {playerpet = true}
	local target = {"target", "targettarget", "pettarget", "pettargettarget", "focus", "focustarget", "mouseover", "mouseovertarget"}

	-- party
	local party = {"player"}
	local partypet = {"pet"}
	for i = 1, 4 do
		local unit = format("party%d", i)
		party[i + 1] = unit
		group[unit] = true

		unit = format("partypet%d", i)
		partypet[i + 1] = unit
		grouppet[unit] = true

		target[#target + 1] = format("party%dtarget", i)
		target[#target + 1] = format("partypet%dtarget", i)
	end

	-- raid
	local raid = {"player"}
	local raidpet = {"pet"}
	for i = 1, 40 do
		local unit = format("raid%d", i)
		raid[i + 1] = unit
		group[unit] = true

		unit = format("raidpet%d", i)
		raidpet[i + 1] = unit
		grouppet[unit] = true

		target[#target + 1] = format("raid%dtarget", i)
		target[#target + 1] = format("raidpet%dtarget", i)
	end

	-- arena
	local arena = {}
	local arenapet = {}
	for i = 1, 5 do
		arena[i] = format("arena%d", i)
		arenapet[i] = format("arenapet%d", i)
		target[#target + 1] = format("arena%dtarget", i)
		target[#target + 1] = format("arenapet%dtarget", i)
	end

	-- boss
	local boss = {}
	for i = 1, 5 do
		boss[i] = format("boss%d", i)
		target[#target + 1] = format("boss%dtarget", i)
	end

	lib.Units = {
		-- solo and targets
		solo = solo,
		group = group,
		grouppet = grouppet,
		target = target,
		-- party units and pets
		party = party,
		partypet = partypet,
		-- raid units and pets
		raid = raid,
		raidpet = raidpet,
		-- arena units and pets
		arena = arena,
		arenapet = arenapet,
		-- boss units
		boss = boss
	}
	Units = lib.Units
end

-------------------------------------------------------------------------------

do
	local wipe, select, tconcat = wipe, select, table.concat
	local temp = {}
	local function _print(...)
		wipe(temp)
		for i = 1, select("#", ...) do
			temp[#temp + 1] = select(i, ...)
		end
		DEFAULT_CHAT_FRAME:AddMessage(tconcat(temp, " "))
	end

	function Dispatch(func, ...)
		if type(func) ~= "function" then
			_print("\124cffff9900Error\124r: Dispatch requires a function.")
			return
		end
		return func(...)
	end


	local pcall = pcall
	local function QuickDispatch(func, ...)
		if type(func) ~= "function" then return end
		local ok, err = pcall(func, ...)
		if not ok then
			_print("\124cffff9900Error\124r:" .. (err or "<no error given>"))
			return
		end
		return true
	end

	lib.Dispatch = Dispatch
	lib.QuickDispatch = QuickDispatch
end

-------------------------------------------------------------------------------

do
	local UnitExists, UnitAffectingCombat, UnitIsDeadOrGhost = _G.UnitExists, _G.UnitAffectingCombat, _G.UnitIsDeadOrGhost
	local UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax = _G.UnitHealth, _G.UnitHealthMax, _G.UnitPower, _G.UnitPowerMax
	local GetNumRaidMembers, GetNumPartyMembers = _G.GetNumRaidMembers, _G.GetNumPartyMembers
	local GetNumGroupMembers, GetNumSubgroupMembers = _G.GetNumGroupMembers, _G.GetNumSubgroupMembers
	local IsInGroup, IsInRaid = _G.IsInGroup, _G.IsInRaid

	local function GetGroupTypeAndCount()
		if IsInRaid() then
			return "raid", 1, GetNumGroupMembers()
		elseif IsInGroup() then
			return "party", 0, GetNumSubgroupMembers()
		else
			return "solo", 0, 0
		end
	end

	local UnitIterator
	do
		local nmem, step, count

		local function SelfIterator(excPets)
			while step do
				local unit, owner
				if step == 1 then
					unit, owner, step = "player", nil, 2
				elseif step == 2 then
					if not excPets then
						unit, owner = "pet", "player"
					end
					step = nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		local party = Units.party
		local partypet = Units.partypet
		local function PartyIterator(excPets)
			while step do
				local unit, owner
				if step <= 2 then
					unit, owner = SelfIterator(excPets)
					step = step or 3
				elseif step == 3 then
					unit, owner, step = party[count], nil, 4
				elseif step == 4 then
					if not excPets then
						unit, owner = partypet[count], party[count]
					end
					count = count + 1
					step = count <= nmem and 3 or nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		local raid = Units.raid
		local raidpet = Units.raidpet
		local function RaidIterator(excPets)
			while step do
				local unit, owner
				if step == 1 then
					unit, owner, step = raid[count], nil, 2
				elseif step == 2 then
					if not excPets then
						unit, owner = raidpet[count], raid[count]
					end
					count = count + 1
					step = count <= nmem and 1 or nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		function UnitIterator(excPets)
			nmem, step = GetNumGroupMembers(), 1
			if nmem == 0 then
				return SelfIterator, excPets
			end
			count = 1
			if IsInRaid() then
				return RaidIterator, excPets
			end
			return PartyIterator, excPets
		end
	end

	local function IsGroupDead()
		for unit in UnitIterator(true) do
			if not UnitIsDeadOrGhost(unit) then
				return false
			end
		end
		return true
	end

	local function IsGroupInCombat()
		for unit in UnitIterator() do
			if UnitAffectingCombat(unit) then
				return true
			end
		end
		return false
	end

	local function GroupIterator(func, ...)
		for unit, owner in UnitIterator() do
			Dispatch(func, unit, owner, ...)
		end
	end

	do
		local function FindUnitId(guid, units)
			if not units then return end
			for _, unit in next, units do
				if UnitExists(unit) and UnitGUID(unit) == guid then
					return unit
				end
			end
		end

		function GetUnitIdFromGUID(guid, grouped)
			-- start with group members
			if grouped then
				local unit = FindUnitId(guid, Units[IsInRaid() and "raid" or IsInGroup() and "party" or "solo"])
				unit = unit or FindUnitId(guid, Units[IsInRaid() and "raidpet" or IsInGroup() and "partypet" or "solo"])
				return unit or FindUnitId(guid, Units.target)
			end

			local unit = not grouped and FindUnitId(guid, Units.target)
			unit = unit or FindUnitId(guid, Units[IsInRaid() and "raid" or IsInGroup() and "party" or "solo"])
			return unit or FindUnitId(guid, Units[IsInRaid() and "raidpet" or IsInGroup() and "partypet" or "solo"])
		end
	end

	local function GetClassFromGUID(guid)
		local unit = GetUnitIdFromGUID(guid)
		local class
		if unit and unit:find("pet") then
			class = "PET"
		elseif unit and unit:find("boss") then
			class = "BOSS"
		elseif unit then
			_, class = UnitClass(unit)
		end
		return class, unit
	end

	local GetCreatureId = setmetatable({}, {
		__mode = "kv", -- make it weak
		__index = function(self, guid)
			if guid then
				local id = tonumber(guid:sub(7, 10), 16) or 0
				rawset(self, guid, id) -- cache it
				return id
			end
			return 0
		end,
		__newindex = function(self, guid, id)
			rawset(self, guid, id)
		end,
		__call = function(self, guid)
			return self[guid]
		end
	})

	local unknownUnits = {[_G.UKNOWNBEING] = true, [_G.UNKNOWNOBJECT] = true}

	local function UnitHealthInfo(unit, guid)
		unit = (unit and not unknownUnits[unit]) and unit or (guid and GetUnitIdFromGUID(guid))
		local percent, health, maxhealth
		if unit and UnitExists(unit) then
			health, maxhealth = UnitHealth(unit), UnitHealthMax(unit)
			if health and maxhealth then
				percent = 100 * health / max(1, maxhealth)
			end
		end
		return percent, health, maxhealth
	end

	local function UnitPowerInfo(unit, guid, powerType)
		unit = (unit and not unknownUnits[unit]) and unit or (guid and GetUnitIdFromGUID(guid))
		local percent, power, maxpower
		if unit and UnitExists(unit) then
			power, maxpower = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
			if power and maxpower then
				percent = 100 * power / max(1, maxpower)
			end
		end
		return percent, power, maxpower
	end

	lib.GetGroupTypeAndCount = GetGroupTypeAndCount
	lib.IsGroupDead = IsGroupDead
	lib.IsGroupInCombat = IsGroupInCombat
	lib.GroupIterator = GroupIterator
	lib.UnitIterator = UnitIterator
	lib.GetUnitIdFromGUID = GetUnitIdFromGUID
	lib.GetClassFromGUID = GetClassFromGUID
	lib.GetCreatureId = GetCreatureId
	lib.UnitHealthInfo = UnitHealthInfo
	lib.UnitPowerInfo = UnitPowerInfo
end

-------------------------------------------------------------------------------
-- Specs and Roles

do
	local rawget = rawget
	local UnitExists, UnitGUID = UnitExists, UnitGUID
	local LGT = LibStub("LibGroupInSpecT-1.0")
	local GetUnitSpec, GetUnitRole = {}, {}

	GetUnitSpec = setmetatable(GetUnitSpec, {
		__index = function(self, guid)
			local info = LGT:GetCachedInfo(guid)
			local spec = info and info.global_spec_id or nil
			if spec then
				rawset(self, guid, spec)
				if info.spec_role and not rawget(GetUnitRole, guid) then
					rawset(GetUnitRole, guid, info.spec_role)
				end
			end
			return spec
		end,
		__newindex = function(self, guid, spec)
			rawset(self, guid, spec)
		end,
		__call = function(self, guid)
			return self[guid]
		end
	})

	GetUnitRole = setmetatable(GetUnitRole, {
		__index = function(self, guid)
			local info = LGT:GetCachedInfo(guid)
			local role = info and info.spec_role or nil
			if role then
				rawset(self, guid, role)
				if info.global_spec_id and not rawget(GetUnitSpec, guid) then
					rawset(GetUnitSpec, guid, info.global_spec_id)
				end
			end
			return role
		end,
		__newindex = function(self, guid, role)
			rawset(self, guid, role)
		end,
		__call = function(self, guid)
			return self[guid]
		end
	})

	LGT:RegisterCallback("GroupInSpecT_Update", function(_, guid, _, info)
		if not guid or not info then return end
		rawset(GetUnitSpec, guid, info.global_spec_id or rawget(GetUnitSpec, guid))
		rawset(GetUnitRole, guid, info.spec_role or rawget(GetUnitRole, guid))
	end)

	LGT:RegisterCallback("GroupInSpecT_Remove", function(_, guid)
		if not guid then return end
		rawset(GetUnitSpec, guid, nil)
		rawset(GetUnitRole, guid, nil)
	end)

	lib.GetUnitSpec = GetUnitSpec
	lib.GetUnitRole = GetUnitRole
end

-------------------------------------------------------------------------------
-- Pvp

do
	local IsInInstance, instanceType = IsInInstance, nil

	local function IsInPvP()
		_, instanceType = IsInInstance()
		return (instanceType == "pvp" or instanceType == "arena")
	end

	lib.IsInPvP = IsInPvP
end

-------------------------------------------------------------------------------

local mixins = {
	"Units",
	"EmptyFunc",
	"Dispatch",
	"QuickDispatch",
	-- roster util
	"IsInPvP",
	"GetGroupTypeAndCount",
	"IsGroupDead",
	"IsGroupInCombat",
	"GroupIterator",
	"UnitIterator",
	-- unit util
	"GetUnitIdFromGUID",
	"GetClassFromGUID",
	"GetCreatureId",
	"UnitHealthInfo",
	"UnitPowerInfo",
	"GetUnitSpec",
	"GetUnitRole"
}

function lib:Embed(target)
	for _, v in pairs(mixins) do
		target[v] = self[v]
	end
	self.embeds[target] = true
	return target
end

for addon in pairs(lib.embeds) do
	lib:Embed(addon)
end
