if myHero.charName ~= "Ahri" then return end

--// requirements
require "DamageLib"

--// spelldata
local Q = { Range = 880, Delay = 0.25, Speed = 1700, Width = 100}
local W = { Range = 700, Delay = 0.25}
local E = { Range = 925, Delay = 0.25, Speed = 1600, Width = 100}
local R = { Range = 425, Delay = 0}

--// needs
local _EnemyHeroes
local function GetEnemyHeroes()
	if _EnemyHeroes then return _EnemyHeroes end
	_EnemyHeroes = {}
	for i = 1, Game.HeroCount() do
		local unit = Game.Hero(i)
		if unit.isEnemy then
			table.insert(_EnemyHeroes, unit)
		end
	end
	return _EnemyHeroes
end

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

function ValidTarget(target, range)
	range = range and range or math.huge
	return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range
end

local function IsImmobileTarget(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 11 or buff.type == 29 or buff.type == 24 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false	
end

function PercentHP(target)
    return 100 * target.health / target.maxHealth
end

function PercentMP(target)
    return 100 * target.mana / target.maxMana
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
end

local function GetTarget(range)
	local target = nil
	if _G.SDK and _G.SDK.Orbwalker then
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = GOS:GetTarget(range)
	end
	return target
end

local function GetMode()
	if _G.SDK and _G.SDK.Orbwalker then
		if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			return "Combo"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			return "Harass"	
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
			return "Clear"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
			return "Lasthit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		end
	else
		return GOS.GetMode()
	end
end

function HeroesAround(pos, range, team)
	local Count = 0
	for i = 1, Game.HeroCount() do
		local minion = Game.Hero(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

function MinionsAround(pos, range, team)
	local Count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

local HKITEM = {
	[ITEM_1] = HK_ITEM_1,
	[ITEM_2] = HK_ITEM_2,
	[ITEM_3] = HK_ITEM_3,
	[ITEM_4] = HK_ITEM_4,
	[ITEM_5] = HK_ITEM_5,
	[ITEM_6] = HK_ITEM_6,
	[ITEM_7] = HK_ITEM_7,
}

--// damages
local function Qdmg(target)
    local level = myHero:GetSpellData(_Q).level
	if Ready(_Q) then
    	return CalcMagicalDamage(myHero, target, (15 + 25 * level + 0.35 * myHero.ap))
	end
	return 0
end

local function Wdmg(target)
    local level = myHero:GetSpellData(_W).level
	if Ready(_W) then
    	return CalcMagicalDamage(myHero, target, (15 + 25 * level + 0.3 * myHero.ap))
	end
	return 0
end

local function Edmg(target)
    local level = myHero:GetSpellData(_E).level
	if Ready(_E) then
        local firstmine = CalcMagicalDamage(myHero, target, (25 + 35 * level + 0.6 * myHero.ap))
    	return firstmine + (firstmine * 0.4) * 2
	end
	return 0
end

local function Rdmg(target)
    local level = myHero:GetSpellData(_R).level
	if Ready(_R) then
    	return CalcMagicalDamage(myHero, target, (30 + 40 * level + 0.25 * myHero.ap))
	end
	return 0
end

local function Idmg(target)
	if (myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1))
	or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2)) then
		return 50 + 20 * myHero.levelData.lvl
	end
	return 0
end

local function BSdmg(target)
	if (myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1))
	or (myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2)) then
		return 20 + 8 * myHero.levelData.lvl
	end
	return 0
end

local function RSdmg(target)
	if (myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1))
	or (myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2)) then
		return 54 + 6 * myHero.levelData.lvl
	end
	return 0
end

local function NoPotion()
	for i = 0, 63 do 
	local buff = myHero:GetBuff(i)
		if buff.type == 13 and Game.Timer() < buff.expireTime then 
			return false
		end
	end
	return true
end

local sqrt = math.sqrt

local function GetDistanceSqr(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return (dx * dx + dz * dz)
end

local function GetDistance(p1, p2)
    return sqrt(GetDistanceSqr(p1, p2))
end

local function GetDistance2D(p1,p2)
    return sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

local function ClosestToMouse(p1, p2) 
	if GetDistance(mousePos, p1) > GetDistance(mousePos, p2) then return p2 else return p1 end
end

local function CircleCircleIntersection(c1, c2, r1, r2) 
	local D = GetDistance(c1, c2)
	if D > r1 + r2 or D <= math.abs(r1 - r2) then return nil end 
	local A = (r1 * r2 - r2 * r1 + D * D) / (2 * D) 
	local H = math.sqrt(r1 * r1 - A * A)
	local Direction = (c2 - c1):Normalized() 
	local PA = c1 + A * Direction 
	local S1 = PA + H * Direction:Perpendicular() 
	local S2 = PA - H * Direction:Perpendicular() 
	return S1, S2 
end

--// Menu
local Ahri = MenuElement({type = MENU, id = "Ahri", name = "HD Ahri"})

Ahri:MenuElement({id = "Script", name = "Ahri", drop = {"HD v1"}})
Ahri:MenuElement({name = " ", drop = {"Champion Core"}})
Ahri:MenuElement({type = MENU, id = "C", name = "Combo"})
Ahri:MenuElement({type = MENU, id = "H", name = "Harass"})
Ahri:MenuElement({type = MENU, id = "LC", name = "LaneClear"})
Ahri:MenuElement({type = MENU, id = "JC", name = "JungleClear"})
Ahri:MenuElement({type = MENU, id = "F", name = "Flee"})
Ahri:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
Ahri:MenuElement({name = " ", drop = {"Champion Utility"}})
Ahri:MenuElement({type = MENU, id = "K", name = "Keys"})
Ahri:MenuElement({type = MENU, id = "MM", name = "Mana"})
Ahri:MenuElement({type = MENU, id = "D", name = "Drawings"})
Ahri:MenuElement({name = " ", drop = {"Extra Utility"}})
Ahri:MenuElement({type = MENU, id = "A", name = "Activator"})
Ahri:MenuElement({type = MENU, id = "Lv", name = "Auto Leveler"})

Ahri.C:MenuElement({id = "Q", name = "Q: Orb of Deception", value = true})
Ahri.C:MenuElement({id = "W", name = "W: Fox-Fire", value = true})
Ahri.C:MenuElement({id = "E", name = "E: Charm", value = true})
Ahri.C:MenuElement({id = "R", name = "R: Spirit Rush [Hover for Info]", value = true, tooltip = "Gapclose mode if out of range and Side mode if near enemy"})

Ahri.H:MenuElement({id = "Q", name = "Q: Orb of Deception", value = true})
Ahri.H:MenuElement({id = "W", name = "W: Fox-Fire", value = true})
Ahri.H:MenuElement({id = "E", name = "E: Charm", value = true})

Ahri.LC:MenuElement({id = "Q", name = "Q: Orb of Deception", value = true})
Ahri.LC:MenuElement({id = "QMin", name = "Minions to Q", value = 5, min = 1, max = 7})
Ahri.LC:MenuElement({id = "W", name = "W: Fox-Fire", value = true})
Ahri.LC:MenuElement({id = "WMin", name = "Minions to W", value = 3, min = 1, max = 3})

Ahri.JC:MenuElement({id = "Q", name = "Q: Orb of Deception", value = true})
Ahri.JC:MenuElement({id = "W", name = "W: Fox-Fire", value = true})
Ahri.JC:MenuElement({id = "E", name = "E: Charm", value = false})

Ahri.F:MenuElement({id = "E", name = "E: Charm", value = true})
Ahri.F:MenuElement({id = "R", name = "R: Spirit Rush", drop = {"Walljump","Normal","Disabled"}})
Ahri.F:MenuElement({id = "RS", name = "Use R only if already active", value = true})

Ahri.K:MenuElement({id = "Clear", name = "Spell Clear", key = string.byte("A"), toggle = true})
Ahri.K:MenuElement({id = "Harass", name = "Spell Harass", key = string.byte("S"), toggle = true})

Ahri.KS:MenuElement({id = "Q", name = "Q: Orb of Deception", value = true})
Ahri.KS:MenuElement({id = "E", name = "E: Charm", value = true})

Ahri.MM:MenuElement({id = "C", name = "Mana % to Combo", value = 0, min = 0, max = 100})
Ahri.MM:MenuElement({id = "H", name = "Mana % to Harass", value = 60, min = 0, max = 100})
Ahri.MM:MenuElement({id = "LC", name = "Mana % to Lane", value = 55, min = 0, max = 100})
Ahri.MM:MenuElement({id = "JC", name = "Mana % to Jungle", value = 30, min = 0, max = 100})
Ahri.MM:MenuElement({id = "F", name = "Mana % to Flee", value = 5, min = 0, max = 100})
Ahri.MM:MenuElement({id = "KS", name = "Mana % to KS", value = 0, min = 0, max = 100})

Ahri.A:MenuElement({type = MENU, id = "P", name = "Potions"})
Ahri.A.P:MenuElement({id = "Pot", name = "All Potions", value = true})
Ahri.A.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
Ahri.A:MenuElement({type = MENU, id = "I", name = "Items"})
Ahri.A.I:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
Ahri.A.I:MenuElement({id = "Proto", name = "Hextec Items (all)", value = true})
Ahri.A:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
		Ahri.A.S:MenuElement({id = "Smite", name = "Smite in Combo [?]", value = true, tooltip = "If Combo will kill"})
		Ahri.A.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		Ahri.A.S:MenuElement({id = "Heal", name = "Auto Heal", value = true})
		Ahri.A.S:MenuElement({id = "HealHP", name = "Health % to Heal", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		Ahri.A.S:MenuElement({id = "Barrier", name = "Auto Barrier", value = true})
		Ahri.A.S:MenuElement({id = "BarrierHP", name = "Health % to Barrier", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
		Ahri.A.S:MenuElement({id = "Ignite", name = "Ignite in Combo", value = true})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
		Ahri.A.S:MenuElement({id = "Exh", name = "Exhaust in Combo [?]", value = true, tooltip = "If Combo will kill"})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		Ahri.A.S:MenuElement({id = "Cleanse", name = "Auto Cleanse", value = true})
		Ahri.A.S:MenuElement({id = "Blind", name = "Blind", value = false})
		Ahri.A.S:MenuElement({id = "Charm", name = "Charm", value = true})
		Ahri.A.S:MenuElement({id = "Flee", name = "Flee", value = true})
		Ahri.A.S:MenuElement({id = "Slow", name = "Slow", value = false})
		Ahri.A.S:MenuElement({id = "Root", name = "Root/Snare", value = true})
		Ahri.A.S:MenuElement({id = "Poly", name = "Polymorph", value = true})
		Ahri.A.S:MenuElement({id = "Silence", name = "Silence", value = true})
		Ahri.A.S:MenuElement({id = "Stun", name = "Stun", value = true})
		Ahri.A.S:MenuElement({id = "Taunt", name = "Taunt", value = true})
	end
end, 2)
Ahri.A.S:MenuElement({type = SPACE, id = "Note", name = "Note: Ghost/TP/Flash is not supported"})

Ahri.D:MenuElement({id = "Q", name = "Q: Orb of Deception", value = true})
Ahri.D:MenuElement({id = "W", name = "W: Fox-Fire", value = true})
Ahri.D:MenuElement({id = "E", name = "E: Charm", value = true})
Ahri.D:MenuElement({id = "R", name = "R: Spirit Rush", value = true})
Ahri.D:MenuElement({id = "T", name = "Spell Toggle", value = true})
Ahri.D:MenuElement({id = "Dmg", name = "Damage HP bar", value = true})

Ahri.Lv:MenuElement({id = "Enabled", name = "Enable", value = true})
Ahri.Lv:MenuElement({id = "Block", name = "Block on Level 1", value = true})
Ahri.Lv:MenuElement({id = "Order", name = "Skill Priority", drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

local _OnVision = {}
function OnVision(unit)
	if _OnVision[unit.networkID] == nil then _OnVision[unit.networkID] = {state = unit.visible , tick = GetTickCount(), pos = unit.pos} end
	if _OnVision[unit.networkID].state == true and not unit.visible then _OnVision[unit.networkID].state = false _OnVision[unit.networkID].tick = GetTickCount() end
	if _OnVision[unit.networkID].state == false and unit.visible then _OnVision[unit.networkID].state = true _OnVision[unit.networkID].tick = GetTickCount() end
	return _OnVision[unit.networkID]
end

--// script
Callback.Add("Tick", function() AutoLevel() OnVisionF() Tick() end)
Callback.Add("Draw", function() Drawings() end)

function AutoLevel()
	if Ahri.Lv.Enabled:Value() == false then return end
	local Sequence = {
		[1] = { HK_Q, HK_W, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_W, HK_Q, HK_W, HK_R, HK_W, HK_W, HK_E, HK_E, HK_R, HK_E, HK_E },
		[2] = { HK_Q, HK_E, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_E, HK_Q, HK_E, HK_R, HK_E, HK_E, HK_W, HK_W, HK_R, HK_W, HK_W },
		[3] = { HK_W, HK_Q, HK_E, HK_W, HK_W, HK_R, HK_W, HK_Q, HK_W, HK_Q, HK_R, HK_Q, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_E },
		[4] = { HK_W, HK_E, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_E, HK_W, HK_E, HK_R, HK_E, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
		[5] = { HK_E, HK_Q, HK_W, HK_E, HK_E, HK_R, HK_E, HK_Q, HK_E, HK_Q, HK_R, HK_Q, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_W },
		[6] = { HK_E, HK_W, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_W, HK_E, HK_W, HK_R, HK_W, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
	}
	local Slot = nil
	local Tick = 0
	local SkillPoints = myHero.levelData.lvl - (myHero:GetSpellData(_Q).level + myHero:GetSpellData(_W).level + myHero:GetSpellData(_E).level + myHero:GetSpellData(_R).level)
	local level = myHero.levelData.lvl
	local Check = Sequence[Ahri.Lv.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if Ahri.Lv.Block:Value() and level == 1 then return end
		if GetTickCount() - Tick > 800 and Check ~= nil then
			Control.KeyDown(HK_LUS)
			Control.KeyDown(Check)
			Slot = Check
			Tick = GetTickCount()
		end
	end
	if Control.IsKeyDown(HK_LUS) then
		Control.KeyUp(HK_LUS)
	end
	if Slot and Control.IsKeyDown(Slot) then
		Control.KeyUp(Slot)
	end
end

local visionTick = GetTickCount()
function OnVisionF()
	if GetTickCount() - visionTick > 100 then
		for i,v in pairs(GetEnemyHeroes()) do
			OnVision(v)
		end
	end
end

local _OnWaypoint = {}
function OnWaypoint(unit)
	if _OnWaypoint[unit.networkID] == nil then _OnWaypoint[unit.networkID] = {pos = unit.posTo , speed = unit.ms, time = Game.Timer()} end
	if _OnWaypoint[unit.networkID].pos ~= unit.posTo then 
		_OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo , speed = unit.ms, time = Game.Timer()}
			DelayAction(function()
				local time = (Game.Timer() - _OnWaypoint[unit.networkID].time)
				local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
				if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos,_OnWaypoint[unit.networkID].pos) > 200 then
					_OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
				end
			end,0.05)
	end
	return _OnWaypoint[unit.networkID]
end

local function GetPred(unit, speed, delay)
	local speed = speed or math.huge
	local delay = delay or 0.25
	local unitSpeed = unit.ms
	if OnWaypoint(unit).speed > unitSpeed then unitSpeed = OnWaypoint(unit).speed end
	if OnVision(unit).state == false then
		local unitPos = unit.pos + Vector(unit.pos,unit.posTo):Normalized() * ((GetTickCount() - OnVision(unit).tick)/1000 * unitSpeed)
		local predPos = unitPos + Vector(unit.pos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(myHero.pos,unitPos)/speed)))
		if GetDistance(unit.pos,predPos) > GetDistance(unit.pos,unit.posTo) then predPos = unit.posTo end
		return predPos
	else
		if unitSpeed > unit.ms then
			local predPos = unit.pos + Vector(OnWaypoint(unit).startPos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(myHero.pos,unit.pos)/speed)))
			if GetDistance(unit.pos,predPos) > GetDistance(unit.pos,unit.posTo) then predPos = unit.posTo end
			return predPos
		elseif IsImmobileTarget(unit) then
			return unit.pos
		else
			return unit:GetPrediction(speed,delay)
		end
	end
end

local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}

local function CustomCast(spell, pos, delay)
	if pos == nil then return end
	if _G.EOWLoaded or _G.SDK then
		Control.CastSpell(spell, pos)
	elseif _G.GOS then
		local ticker = GetTickCount()
		if castSpell.state == 0 and ticker - castSpell.casting > delay + Game.Latency() and pos:ToScreen().onScreen then
			castSpell.state = 1
			castSpell.mouse = mousePos
			castSpell.tick = ticker
		end
		if castSpell.state == 1 then
			if ticker - castSpell.tick < Game.Latency() then
				Control.SetCursorPos(pos)
				Control.KeyDown(spell)
				Control.KeyUp(spell)
				castSpell.casting = ticker + delay
				DelayAction(function()
					if castSpell.state == 1 then
						Control.SetCursorPos(castSpell.mouse)
						castSpell.state = 0
					end
				end, Game.Latency()/1000)
			end
			if ticker - castSpell.casting > Game.Latency() then
				Control.SetCursorPos(castSpell.mouse)
				castSpell.state = 0
			end
		end
	end
end

function Tick()
    local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
	elseif Mode == "Clear" then
		Lane()
        Jungle()
	elseif Mode == "Harass" then
		Harass()
    elseif Mode == "Flee" then
        Flee()
	end
		Killsteal()
        Summoners()
        Activator()
end

function Combo()
    if Ahri.MM.C:Value() > PercentMP(myHero) then return end
    local target = GetTarget(E.Range)
    if target == nil then return end
    if Ready(_R) and ValidTarget(target, E.Range) then
        if Ahri.C.R:Value() and Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) > target.health then
            if myHero.pos:DistanceTo(target.pos) > 700 then
				Control.CastSpell(HK_R, target)
			else
				local c1, c2, r1, r2 = Vector(myHero.pos), Vector(target.pos), myHero.range, 525 
				local O1, O2 = CircleCircleIntersection(c1, c2, r1, r2) 
				if O1 or O2 then
					local pos = c1:Extended(Vector(ClosestToMouse(O1, O2)), 425)
					Control.CastSpell(HK_R, pos) 
				end
			end
        end
    end
	if Ready(_E) and ValidTarget(target, E.Range) then
        if Ahri.C.E:Value() and target:GetCollision(E.Width, E.Speed, E.Delay) == 0 then
            local pos = GetPred(target, E.Speed, 0.25 + (Game.Latency()/1000))
			CustomCast(HK_E, pos, 250)
        end
    end
	if Ready(_Q) and ValidTarget(target, Q.Range) then
        if Ahri.C.Q:Value() then
            local pos = GetPred(target, Q.Speed, 0.25 + (Game.Latency()/1000))
			CustomCast(HK_Q, pos, 250)
        end
    end
    if Ready(_W) and ValidTarget(target, W.Range) then
        if Ahri.C.W:Value() then
            Control.CastSpell(HK_W)
        end
    end
end

function Lane()
	if Ahri.K.Clear:Value() == false then return end
    if Ahri.MM.LC:Value() > PercentMP(myHero) then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 200 then
            if Ready(_Q) and ValidTarget(minion, Q.Range) then
                if Ahri.LC.Q:Value() then
                    if minion:GetCollision(Q.Width, Q.Speed, E.Speed) >= Ahri.LC.QMin:Value() then
                        local pos = GetPred(minion, Q.Speed, 0.25 + (Game.Latency()/1000))
						CustomCast(HK_Q, pos, 250)
                    end
                end
            end
            if Ready(_W) and ValidTarget(minion, W.Range) then
		if Ahri.LC.W:Value() then
                	if MinionsAround(myHero.pos, 700, 200) >= Ahri.LC.WMin:Value() then
                    		Control.CastSpell(HK_W, BestPos)
			end
                end
            end
        end
    end
end

function Jungle()
		if Ahri.K.Clear:Value() == false then return end
    if Ahri.MM.JC:Value() > PercentMP(myHero) then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 300 then
            if Ready(_Q) and ValidTarget(minion, Q.Range) then
                if Ahri.JC.Q:Value() then
                    local pos = GetPred(minion, Q.Speed, 0.25 + (Game.Latency()/1000))
					CustomCast(HK_Q, pos, 250)
                end
            end
            if Ready(_W) and ValidTarget(minion, W.Range) then
                if Ahri.JC.W:Value() then
                    Control.CastSpell(HK_W, minion.pos)
                end
            end
            if Ready(_E) and ValidTarget(minion, E.Range) then
                if Ahri.JC.E:Value() then
                    Control.CastSpell(HK_E, minion.pos)
                end
            end
        end
    end
end

function Harass()
	if Ahri.K.Harass:Value() == false then return end
    if Ahri.MM.H:Value() > PercentMP(myHero) then return end
    local target = GetTarget(E.Range)
    if target == nil then return end
    if Ready(_E) and ValidTarget(target, E.Range) then
        if Ahri.H.E:Value() and target:GetCollision(E.Width, E.Speed, E.Delay) == 0 then
            local pos = GetPred(target, E.Speed, 0.25 + (Game.Latency()/1000))
			CustomCast(HK_E, pos, 250)
        end
    end
	if Ready(_Q) and ValidTarget(target, Q.Range) then
        if Ahri.H.Q:Value() then
            local pos = GetPred(target, Q.Speed, 0.25 + (Game.Latency()/1000))
			CustomCast(HK_Q, pos, 250)
        end
    end
    if Ready(_W) and ValidTarget(target, W.Range) then
        if Ahri.H.W:Value() then
            Control.CastSpell(HK_W)
        end
    end
end

function Flee()
    if Ahri.MM.F:Value() > PercentMP(myHero) then return end
    local target = GetTarget(E.Range)
    if target == nil then return end
    if Ready(_E) and ValidTarget(target, E.Range) then
        if Ahri.F.E:Value() then
            local pos = GetPred(target, E.Speed, 0.25 + (Game.Latency()/1000))
			CustomCast(HK_E, pos, 250)
        end
    end
end

function Killsteal()
    if Ahri.MM.KS:Value() > PercentMP(myHero) then return end
    local target = GetTarget(E.Range)
    if target == nil then return end
    if Ready(_E) and ValidTarget(target, E.Range) and target:GetCollision(E.Width, E.Speed, E.Delay) == 0 then
        if Ahri.KS.E:Value() and Edmg(target) > target.health then
            local pos = GetPred(target, E.Speed, 0.25 + (Game.Latency()/1000))
			CustomCast(HK_E, pos, 250)
        end
    end
	if Ready(_Q) and ValidTarget(target, Q.Range) then
        if Ahri.KS.Q:Value() and Qdmg(target) > target.health then
            local pos = GetPred(target, Q.Speed, 0.25 + (Game.Latency()/1000))
			CustomCast(HK_Q, pos, 250)
        end
    end
end

function Summoners()
	local target = GetTarget(1500)
    if target == nil then return end
	if GetMode() == "Combo" then
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if Ahri.A.S.Smite:Value() then
				local RedDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + RSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				local BlueDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + BSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if Ahri.A.S.Ignite:Value() then
				local IgDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + Idmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			if Ahri.A.S.Exh:Value() then
				local Damage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" and Ready(SUMMONER_1) and Damage > target.health
				and myHero.pos:DistanceTo(target.pos) < 650 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" and Ready(SUMMONER_1) and Damage > target.health
				and myHero.pos:DistanceTo(target.pos) < 650 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if Ahri.A.S.Heal:Value() then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < Ahri.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < Ahri.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if Ahri.A.S.Barrier:Value() then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < Ahri.A.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < Ahri.A.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		if Ahri.A.S.Cleanse:Value() then
			for i = 0, myHero.buffCount do
			local buff = myHero:GetBuff(i);
				if buff.count > 0 then
					if ((buff.type == 5 and Ahri.A.S.Stun:Value())
					or (buff.type == 7 and  Ahri.A.S.Silence:Value())
					or (buff.type == 8 and  Ahri.A.S.Taunt:Value())
					or (buff.type == 9 and  Ahri.A.S.Poly:Value())
					or (buff.type == 10 and  Ahri.A.S.Slow:Value())
					or (buff.type == 11 and  Ahri.A.S.Root:Value())
					or (buff.type == 21 and  Ahri.A.S.Flee:Value())
					or (buff.type == 22 and  Ahri.A.S.Charm:Value())
					or (buff.type == 25 and  Ahri.A.S.Blind:Value())
					or (buff.type == 28 and  Ahri.A.S.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) then
							Control.CastSpell(HK_SUMMONER_2)
						end
					end
				end
			end
		end
	end
end

function Activator()
	local target = GetTarget(900)
    if target == nil then return end
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
	end

	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and myHero:GetSpellData(Potion).currentCd == 0 and Ahri.A.P.Pot:Value() and PercentHP(myHero) < Ahri.A.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
	end

	if GetMode() == "Combo" then
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and Ahri.A.I.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end

		local Proto = items[3152] or items[3146] or items[3146] or items[3030]
		if Proto and myHero:GetSpellData(Proto).currentCd == 0 and Ahri.A.I.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Proto], target.pos)
		end
	end
end

function Drawings()
    if myHero.dead then return end
	if Ahri.D.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 222, 255)) end
    if Ahri.D.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 255, 200, 000)) end
	if Ahri.D.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 246, 000, 255)) end
	if Ahri.D.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 000, 043, 255)) end
	if Ahri.D.T:Value() then
		local textPosC = myHero.pos:To2D()
		if Ahri.K.Clear:Value() then
			Draw.Text("Clear: On", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
		local textPosH = myHero.pos:To2D()
		if Ahri.K.Harass:Value() then
			Draw.Text("Harass: On", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
	if Ahri.D.Dmg:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead and enemy.visible then
				local barPos = enemy.hpBar
				local health = enemy.health
				local maxHealth = enemy.maxHealth
				local Qdmg = Qdmg(enemy)
				local Wdmg = Wdmg(enemy)
				local Edmg = Edmg(enemy)
				local Rdmg = Rdmg(enemy)
				local Damage = Qdmg + Wdmg + Edmg + Rdmg
				if Damage < health then
					Draw.Rect(barPos.x + (((health - Qdmg) / maxHealth) * 100), barPos.y, (Qdmg / maxHealth )*100, 10, Draw.Color(170, 000, 222, 255))
					Draw.Rect(barPos.x + (((health - (Qdmg + Wdmg)) / maxHealth) * 100), barPos.y, (Wdmg / maxHealth )*100, 10, Draw.Color(170, 255, 200, 000))
					Draw.Rect(barPos.x + (((health - (Qdmg + Wdmg + Edmg)) / maxHealth) * 100), barPos.y, (Edmg / maxHealth )*100, 10, Draw.Color(170, 246, 000, 255))
					Draw.Rect(barPos.x + (((health - (Qdmg + Wdmg + Edmg + Rdmg)) / maxHealth) * 100), barPos.y, (Rdmg / maxHealth )*100, 10, Draw.Color(170, 000, 043, 255))
				else
    				Draw.Rect(barPos.x, barPos.y, (health / maxHealth ) * 100, 10, Draw.Color(170, 000, 255, 000))
				end
			end
		end
	end
end

