if myHero.charName ~= "Ekko" then return end

require "DamageLib"
require "MapPositionGOS"

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function PercentHP(target)
    return 100 * target.health / target.maxHealth
end

local function PercentMP(target)
    return 100 * target.mana / target.maxMana
end

local function IsImmune(unit)
    for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and PercentHP(unit) <= 10 then
            return true
        end
        if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then 
            return true
        end
    end
    return false
end

local sqrt = math.sqrt

local function GetDistanceSqr(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return (dx * dx + dz * dz)
end

local function GetDistance(p1, p2)
    return p1:DistanceTo(p2)
end

local function GetDistance2D(p1,p2)
    return sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
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

local function IsValidTarget(target, range)
	range = range and range or math.huge
	return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range and IsImmune(target) == false
end

local Q = {range = 1075, speed = myHero:GetSpellData(_Q).speed, delay = 0.25, width = myHero:GetSpellData(_Q).width}
local W = {range = 1600, speed = myHero:GetSpellData(_W).speed, delay = 0.25, width = myHero:GetSpellData(_W).width, radius = 400}
local E = {range = 750}

local HKITEM = {
	[ITEM_1] = HK_ITEM_1,
	[ITEM_2] = HK_ITEM_2,
	[ITEM_3] = HK_ITEM_3,
	[ITEM_4] = HK_ITEM_4,
	[ITEM_5] = HK_ITEM_5,
	[ITEM_6] = HK_ITEM_6,
	[ITEM_7] = HK_ITEM_7,
}

local function Qdmg(target)
    return 0
end

local function Wdmg(target)
    
    return 0
end

local function Edmg(target)
    return 0
end

local function Rdmg(target)
    local level = myHero:GetSpellData(_R).level
	if Ready(_R) then
    	return CalcMagicalDamage(myHero, target, (150 * level + 1.5 * myHero.ap))
	end
	return 0
end

local function IGdmg(target)
    return 70 + 20 * myHero.levelData.lvl
end

local function HeroesAround(pos, range, team)
	local Count = 0
	for i = 1, Game.HeroCount() do
		local minion = Game.Hero(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

local function MinionsAround(pos, range, team)
	local Count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

local function GetTarget(range)
	local target = nil 
	if _G.EOWLoaded then
		target = EOW:GetTarget(range)
	elseif _G.SDK and _G.SDK.Orbwalker then 
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = _G.GOS:GetTarget(range)
	end
	return target
end

local function NoPotion()
	for i = 0, myHero.buffCount do 
	local buff = myHero:GetBuff(i)
		if buff.type == 13 and Game.Timer() < buff.expireTime then 
			return false
		end
	end
	return true
end

local function GetMode()
	if _G.EOWLoaded then
        if EOW.CurrentMode == 1 then
            return "Combo"
        elseif EOW.CurrentMode == 2 then
            return "Harass"
        elseif EOW.CurrentMode == 3 then
            return "Lasthit"
        elseif EOW.CurrentMode == 4 then
            return "Clear"
        end
	elseif _G.SDK and _G.SDK.Orbwalker then
		if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			return "Combo"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			return "Harass"	
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
			return "Clear"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
			return "LastHit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		end
	else
		return GOS:GetMode()
	end
end

local function EnableOrb(bool)
	if Orb == 1 then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif Orb == 2 then
		_G.SDK.Orbwalker:SetMovement(bool)
		_G.SDK.Orbwalker:SetAttack(bool)
	else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
end

local abs = math.abs 
local deg = math.deg 
local acos = math.acos
function IsFacing(target)
    local V = Vector((target.pos - myHero.pos))
    local D = Vector(target.dir)
    local Angle = 180 - deg(acos(V*D/(V:Len()*D:Len())))
    if abs(Angle) < 80 then 
        return true  
    end
    return false
end

local RepoEkko = MenuElement({type = MENU, id = "RepoEkko", name = "Roman Repo 7.24", leftIcon = "https://raw.githubusercontent.com/RomanovHD/GOSext/master/Repository/Screenshot_1.png"})

RepoEkko:MenuElement({id = "Me", name = "Ekko", drop = {"v1.0"}})
RepoEkko:MenuElement({id = "Core", name = " ", drop = {"Champion Core"}})
RepoEkko:MenuElement({id = "Combo", name = "Combo", type = MENU})
	RepoEkko.Combo:MenuElement({id = "Q", name = "Q - Timewinder", value = true})
	RepoEkko.Combo:MenuElement({id = "W", name = "W - Parallel Convergence", value = true})
	RepoEkko.Combo:MenuElement({id = "E", name = "E - Phase Dive", value = true})

RepoEkko:MenuElement({id = "Harass", name = "Harass", type = MENU})
    RepoEkko.Harass:MenuElement({id = "Q", name = "Q - Timewinder", value = true})
	RepoEkko.Harass:MenuElement({id = "W", name = "W - Parallel Convergence", value = true})
    RepoEkko.Harass:MenuElement({id = "E", name = "E - Phase Dive", value = true})

RepoEkko:MenuElement({id = "Clear", name = "Clear", type = MENU})
    RepoEkko.Clear:MenuElement({id = "Q", name = "Q - Timewinder", value = true})
	RepoEkko.Clear:MenuElement({id = "X", name = "Minions", value = 5, min = 1, max = 7})
	RepoEkko.Clear:MenuElement({id = "E", name = "E - Phase Dive [jungle]", value = true})
	RepoEkko.Clear:MenuElement({id = "MP", name = "Min mana", value = 35, min = 0, max = 100})
    RepoEkko.Clear:MenuElement({id = "Key", name = "Enable/Disable", key = string.byte("A"), toggle = true})

RepoEkko:MenuElement({id = "Killsteal", name = "Killsteal", type = MENU})
	RepoEkko.Killsteal:MenuElement({id = "R", name = "R - Chronobreak", value = true})

RepoEkko:MenuElement({id = "Flee", name = "Flee", type = MENU})
	RepoEkko.Flee:MenuElement({id = "Q", name = "Q - Timewinder", value = true})
    RepoEkko.Flee:MenuElement({id = "E", name = "E - Phase Dive", value = true})

RepoEkko:MenuElement({id = "Utility", name = " ", drop = {"Champion Utility"}})
RepoEkko:MenuElement({id = "Leveler", name = "Auto Leveler", type = MENU})
    RepoEkko.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
    RepoEkko.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
    RepoEkko.Leveler:MenuElement({id = "Order", name = "Skill Priority", value = 1, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

RepoEkko:MenuElement({type = MENU, id = "Activator", name = "Activator"})
	RepoEkko.Activator:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
	RepoEkko.Activator.CS:MenuElement({id = "Blind", name = "Blind", value = false})
	RepoEkko.Activator.CS:MenuElement({id = "Charm", name = "Charm", value = true})
	RepoEkko.Activator.CS:MenuElement({id = "Flee", name = "Flee", value = true})
	RepoEkko.Activator.CS:MenuElement({id = "Slow", name = "Slow", value = false})
	RepoEkko.Activator.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
	RepoEkko.Activator.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
	RepoEkko.Activator.CS:MenuElement({id = "Silence", name = "Silence", value = true})
	RepoEkko.Activator.CS:MenuElement({id = "Stun", name = "Stun", value = true})
	RepoEkko.Activator.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
	RepoEkko.Activator:MenuElement({type = MENU, id = "P", name = "Potions"})
	RepoEkko.Activator.P:MenuElement({id = "Pot", name = "All Potions", value = true})
	RepoEkko.Activator.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
	RepoEkko.Activator:MenuElement({type = MENU, id = "I", name = "Items"})
	RepoEkko.Activator.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
	RepoEkko.Activator.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
	RepoEkko.Activator.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
	RepoEkko.Activator.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
	RepoEkko.Activator.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
	RepoEkko.Activator.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
	RepoEkko.Activator.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
	RepoEkko.Activator.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
	RepoEkko.Activator.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
	RepoEkko.Activator.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
	RepoEkko.Activator.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
	RepoEkko.Activator.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
	RepoEkko.Activator.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
	RepoEkko.Activator.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
	RepoEkko.Activator.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
	RepoEkko.Activator.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
	RepoEkko.Activator.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
	RepoEkko.Activator.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
	RepoEkko.Activator.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
	RepoEkko.Activator.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
	RepoEkko.Activator.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
	RepoEkko.Activator.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})
	
	RepoEkko.Activator:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			RepoEkko.Activator.S:MenuElement({id = "Smite", name = "Combo Smite", value = true})
			RepoEkko.Activator.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
			RepoEkko.Activator.S:MenuElement({id = "Heal", name = "Heal", value = true})
			RepoEkko.Activator.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
			RepoEkko.Activator.S:MenuElement({id = "Barrier", name = "Barrier", value = true})
			RepoEkko.Activator.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			RepoEkko.Activator.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			RepoEkko.Activator.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
			RepoEkko.Activator.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
		end

RepoEkko:MenuElement({id = "Draw", name = "Drawings", type = MENU})
    RepoEkko.Draw:MenuElement({id = "Q", name = "Q - Timewinder", value = true})
    RepoEkko.Draw:MenuElement({id = "W", name = "W - Parallel Convergence", value = true})
    RepoEkko.Draw:MenuElement({id = "E", name = "E - Phase Dive", value = true})
    RepoEkko.Draw:MenuElement({id = "C", name = "Enable Text", value = true})

Callback.Add("Tick", function() Tick() end)
Callback.Add("Draw", function() Drawings() end)

function Tick()
	local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
	elseif Mode == "Harass" then
		Harass()
	elseif Mode == "Clear" then
		Lane()
	elseif Mode == "Flee" then
		Flee()
	end
	Killsteal()
    Activator2()
	AutoLevel()
end

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

local _OnVision = {}
function OnVision(unit)
	if _OnVision[unit.networkID] == nil then _OnVision[unit.networkID] = {state = unit.visible , tick = GetTickCount(), pos = unit.pos} end
	if _OnVision[unit.networkID].state == true and not unit.visible then _OnVision[unit.networkID].state = false _OnVision[unit.networkID].tick = GetTickCount() end
	if _OnVision[unit.networkID].state == false and unit.visible then _OnVision[unit.networkID].state = true _OnVision[unit.networkID].tick = GetTickCount() end
	return _OnVision[unit.networkID]
end
Callback.Add("Tick", function() OnVisionF() end)
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
		-- print("OnWayPoint:"..unit.charName.." | "..math.floor(Game.Timer()))
		_OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo , speed = unit.ms, time = Game.Timer()}
			DelayAction(function()
				local time = (Game.Timer() - _OnWaypoint[unit.networkID].time)
				local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
				if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos,_OnWaypoint[unit.networkID].pos) > 200 then
					_OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
					-- print("OnDash: "..unit.charName)
				end
			end,0.05)
	end
	return _OnWaypoint[unit.networkID]
end

local function GetPred(unit,speed,delay,sourcePos)
	local speed = speed or math.huge
	local delay = delay or 0.25
	local sourcePos = sourcePos or myHero.pos
	local unitSpeed = unit.ms
	if OnWaypoint(unit).speed > unitSpeed then unitSpeed = OnWaypoint(unit).speed end
	if OnVision(unit).state == false then
		local unitPos = unit.pos + Vector(unit.pos,unit.posTo):Normalized() * ((GetTickCount() - OnVision(unit).tick)/1000 * unitSpeed)
		local predPos = unitPos + Vector(unit.pos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(sourcePos,unitPos)/speed)))
		if GetDistance(unit.pos,predPos) > GetDistance(unit.pos,unit.posTo) then predPos = unit.posTo end
		return predPos
	else
		if unitSpeed > unit.ms then
			local predPos = unit.pos + Vector(OnWaypoint(unit).startPos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(sourcePos,unit.pos)/speed)))
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
local function CastSpell(spell,pos,range,delay)
local range = range or math.huge
local delay = delay or 250
local ticker = GetTickCount()

	if castSpell.state == 0 and GetDistance(myHero.pos,pos) < range and ticker - castSpell.casting > delay + Game.Latency() and pos:ToScreen().onScreen then
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
			end,Game.Latency()/1000)
		end
		if ticker - castSpell.casting > Game.Latency() then
			Control.SetCursorPos(castSpell.mouse)
			castSpell.state = 0
		end
	end
end

function AutoLevel()
	if RepoEkko.Leveler.Enabled:Value() == false then return end
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
	local Check = Sequence[RepoEkko.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RepoEkko.Leveler.Block:Value() and level == 1 then return end
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

function CastQ(target)
	if target.ms ~= 0 and (Q.range - GetDistance(target.pos,myHero.pos))/target.ms <= GetDistance(myHero.pos,target.pos)/(Q.speed + Q.delay) and not IsFacing(target) then return end
	if Ready(_Q) and castSpell.state == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
			local qPred = GetPred(target,Q.speed,Q.delay + Game.Latency()/1000)
            CastSpell(HK_Q,qPred,Q.range + 200,250)
        end
	end
end

local _sphere = nil
function CastW(target)
	if target.ms ~= 0 and (W.range - GetDistance(target.pos,myHero.pos))/target.ms <= GetDistance(myHero.pos,target.pos)/(W.speed + W.delay) and not IsFacing(target) then return end
	if Ready(_W) and castSpell.state == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
            local wPred = GetPred(target,W.speed,W.delay + Game.Latency()/1000)
			_sphere = wPred
			CastSpell(HK_W,wPred,W.range,250)
        end
	end
end

local lastW = os.clock()
function Combo()
    local target = GetTarget(W.range)
    if target == nil then return end

    if IsValidTarget(target,W.range) and RepoEkko.Combo.W:Value() and Ready(_W) then
		CastW(target)
		lastW = os.clock()
    end
	if IsValidTarget(target,E.range + W.radius) and RepoEkko.Combo.E:Value() and Ready(_E) and _sphere ~= nil and os.clock() - lastW > 2.75 and os.clock() - lastW < 3 and GetDistance(_sphere,target.pos) < 400 then
		Control.CastSpell(HK_E, _sphere)
	end
	if IsValidTarget(target,E.range) and RepoEkko.Combo.E:Value() and Ready(_E) and (_sphere == nil or os.clock() - lastW > 3.25) then
		Control.CastSpell(HK_E, target)
	end
	if IsValidTarget(target,Q.range) and RepoEkko.Combo.Q:Value() and Ready(_Q) then
		CastQ(target)
	end
end

function Harass()
	local target = GetTarget(W.range)
	if target == nil then return end
    
	if IsValidTarget(target,W.range) and RepoEkko.Harass.W:Value() and Ready(_W) then
		CastW(target)
    end
	if IsValidTarget(target,Q.range) and RepoEkko.Harass.Q:Value() and Ready(_Q) then
		CastQ(target)
    end
    if IsValidTarget(target,E.range) and RepoEkko.Harass.E:Value() and Ready(_E) then
		Control.CastSpell(HK_E, target)
    end
end

function Lane()
	if RepoEkko.Clear.Key:Value() == false then return end
	if PercentMP(myHero) < RepoEkko.Clear.MP:Value() then return end
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion then
			if minion.team == 300 - myHero.team then
                if IsValidTarget(minion,Q.range) and minion:GetCollision(Q.width, Q.speed, Q.delay) - 1 >= RepoEkko.Clear.X:Value() and RepoEkko.Clear.Q:Value() and Ready(_Q) then
                    Control.CastSpell(HK_Q, minion.pos)
				end
			end
			if minion.team == 300 then
				if IsValidTarget(minion,E.range) and RepoEkko.Clear.E:Value() and Ready(_E) and myHero.attackData.state == STATE_WINDDOWN then
                    Control.CastSpell(HK_E, minion)
                end
                if IsValidTarget(minion,Q.range) and RepoEkko.Clear.Q:Value() and Ready(_Q) then
                    Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function Killsteal()
	local target = GetTarget(math.huge)

	if target and target.health < Rdmg(target) and RepoEkko.Killsteal.R:Value() and Ready(_R) then
		for i = 1, Game.ParticleCount() do
			local particle = Game.Particle(i)
			if particle then
				if particle.name == "Ekko_Base_R_TrailEnd.troy" then
					if GetDistance(particle.pos,target.pos) < 350 then
						Control.CastSpell(HK_R)
					end
				end	
			end
		end
	end
end

function Flee()
	local target = GetTarget(Q.range)
    
    if RepoEkko.Flee.E:Value() and Ready(_E) then
        Control.CastSpell(HK_E, Game.cursorPos())
    end
    if target and IsValidTarget(target,Q.range) and RepoEkko.Flee.Q:Value() and Ready(_Q) then
		CastQ(target)
    end
end

function Activator2()
	local target = GetTarget(1575)
	if target == nil then return end
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Banner = items[3060]
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and RepoEkko.Activator.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and RepoEkko.Activator.P.Pot:Value() and PercentHP(myHero) < RepoEkko.Activator.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and RepoEkko.Activator.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and RepoEkko.Activator.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and RepoEkko.Activator.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and RepoEkko.Activator.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and RepoEkko.Activator.D.Locket:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and RepoEkko.Activator.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and PercentHP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if RepoEkko.Activator.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoEkko.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoEkko.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if RepoEkko.Activator.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoEkko.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoEkko.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		if target then
			for i = 0, myHero.buffCount do
			local buff = myHero:GetBuff(i);
				if buff.count > 0 then
					if ((buff.type == 5 and RepoEkko.Activator.CS.Stun:Value())
					or (buff.type == 7 and  RepoEkko.Activator.CS.Silence:Value())
					or (buff.type == 8 and  RepoEkko.Activator.CS.Taunt:Value())
					or (buff.type == 9 and  RepoEkko.Activator.CS.Poly:Value())
					or (buff.type == 10 and  RepoEkko.Activator.CS.Slow:Value())
					or (buff.type == 11 and  RepoEkko.Activator.CS.Root:Value())
					or (buff.type == 21 and  RepoEkko.Activator.CS.Flee:Value())
					or (buff.type == 22 and  RepoEkko.Activator.CS.Charm:Value())
					or (buff.type == 25 and  RepoEkko.Activator.CS.Blind:Value())
					or (buff.type == 28 and  RepoEkko.Activator.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and RepoEkko.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and RepoEkko.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and RepoEkko.Activator.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and RepoEkko.Activator.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and RepoEkko.Activator.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and RepoEkko.Activator.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and RepoEkko.Activator.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and RepoEkko.Activator.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and RepoEkko.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and RepoEkko.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and RepoEkko.Activator.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and RepoEkko.Activator.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and RepoEkko.Activator.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and RepoEkko.Activator.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and RepoEkko.Activator.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if RepoEkko.Activator.S.Smite:Value() then
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoEkko.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoEkko.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoEkko.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoEkko.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RepoEkko.Activator.S.Ignite:Value() then
				local IgDamage = IGdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
	end
end

function Drawings()
    if myHero.dead then return end
    if RepoEkko.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.range, 3,  Draw.Color(255, 000, 222, 255)) end
    if RepoEkko.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.range, 3,  Draw.Color(255, 255, 200, 000)) end
    if RepoEkko.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.range, 3,  Draw.Color(255, 000, 043, 255)) end
	if RepoEkko.Draw.C:Value() then
		local textPos = myHero.pos:To2D()
		if RepoEkko.Clear.Key:Value() then
			Draw.Text("CLEAR ENABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("CLEAR DISABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 225, 000, 000)) 
		end
	end
end
