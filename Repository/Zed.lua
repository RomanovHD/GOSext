if myHero.charName ~= "Zed" then return end

local _shadowPos = myHero.pos

require "DamageLib"

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function PercentHP(target)
    return 100 * target.health / target.maxHealth
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

local Q = {range = 900, speed = 900, width = 70, delay = 0.25}
local W = {range = 650, speed = 1750, swaprange = 1300, delay = 0.25}
local E = {range = 290}
local R = {range = 625}
local BOTRK = {range = 550}
local EX = {range = 650}
local IG = {range = 600}

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
    if Ready(_Q) then
        if Ready(_W) and GetDistance(myHero.pos,target.pos) < 900 and target:GetCollision(70, 900, 0.25) == 0 then
            return CalcPhysicalDamage(myHero,target,(45 + 35 * myHero:GetSpellData(_Q).level + 0.9 * myHero.bonusDamage) * 1.75 )
        elseif Ready(_W) and GetDistance(myHero.pos,target.pos) < 900 and target:GetCollision(70, 900, 0.25) ~= 0 then
            return CalcPhysicalDamage(myHero,target,(45 + 35 * myHero:GetSpellData(_Q).level + 0.9 * myHero.bonusDamage) * 1.75 * 0.6 )
        elseif not Ready(_W) and target:GetCollision(70, 900, 0.25) == 0 then
            return CalcPhysicalDamage(myHero,target,(45 + 35 * myHero:GetSpellData(_Q).level + 0.9 * myHero.bonusDamage))
        elseif not Ready(_W) and target:GetCollision(70, 900, 0.25) ~= 0 then
            return CalcPhysicalDamage(myHero,target,(45 + 35 * myHero:GetSpellData(_Q).level + 0.9 * myHero.bonusDamage * 0.6))
        end
    end
    return 0
end

local function Edmg(target)
    if Ready(_E) then
        return CalcPhysicalDamage(myHero,target,(45 + 25 * myHero:GetSpellData(_E).level + 0.8 * myHero.bonusDamage))
    end
    return 0
end

local function Passivedmg(target)
	for i = 0, target.buffCount do
		local buff = target:GetBuff(i)
		if buff.name == "zedpassivecd" then
			return 0
		end
	end
	if myHero.levelData.lvl >= 17 then
		return CalcMagicalDamage(myHero,target,(target.maxHealth * 0.1))
	elseif myHero.levelData.lvl >= 7 then
		return CalcMagicalDamage(myHero,target,(target.maxHealth * 0.08))
	else
		return CalcMagicalDamage(myHero,target,(target.maxHealth * 0.06))
	end
end

local function ComboAA(target)
	local AAdmg = CalcPhysicalDamage(myHero,target,(myHero.totalDamage))
	if myHero.attackSpeed >= 2.5 then
		return AAdmg * 5
	elseif myHero.attackSpeed >= 2 then
		return AAdmg * 4
	elseif myHero.attackSpeed >= 1.5 then
		return AAdmg * 3
	elseif myHero.attackSpeed >= 1 then
		return AAdmg * 2
	else
		return AAdmg
	end
end

local function ELdmg(target)
    for i = 0, myHero.buffCount do
		local buff = myHero:GetBuff(i)
		if buff and buff.name == "ASSETS/Perks/Styles/Domination/TLords/TLords.lua" then
			return CalcPhysicalDamage(myHero,target,(40 + 10 * myHero.levelData.lvl + 0.5 * myHero.bonusDamage + 0.3 * myHero.ap))
		end
    end
    return 0
end

local function BOTRKdmg(target)
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end

    local BOTRK = items[3144] or items[3153]
    if BOTRK and myHero:GetSpellData(BOTRK).currentCd == 0 then
        return CalcMagicalDamage(myHero,target,(100))
    end
    return 0
end

local function IGdmg(target)
    if (myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1))
    or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2)) then
        return 70 + 20 * myHero.levelData.lvl
    end
    return 0
end

local function Rdmg(target)
    if Ready(_R) then
        return CalcPhysicalDamage(myHero,target,(myHero.totalDamage + (0.15 + 0.10 * myHero:GetSpellData(_R).level) * (Passivedmg(target) + Qdmg(target) + Edmg(target) + IGdmg(target) * 0.5 + BOTRKdmg(target) + ELdmg(target) + ComboAA(target)) ))
    end
    return 0
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

local RepoZed = MenuElement({type = MENU, id = "RepoZed", name = "Roman Repo 7.24", leftIcon = "https://raw.githubusercontent.com/RomanovHD/GOSext/master/Repository/Screenshot_1.png"})

RepoZed:MenuElement({id = "Me", name = "Zed", drop = {"v4.0"}})
RepoZed:MenuElement({id = "Core", name = " ", drop = {"Champion Core"}})
RepoZed:MenuElement({id = "Combo", name = "Combo", type = MENU})
	RepoZed.Combo:MenuElement({id = "Q", name = "Q - Razor Shuriken", value = true})
	RepoZed.Combo:MenuElement({id = "W", name = "W - Living Shadow", value = true})
	RepoZed.Combo:MenuElement({id = "E", name = "E - Shadow Slash", value = true})
	RepoZed.Combo:MenuElement({id = "R", name = "R - Death Mark", value = true})
	RepoZed.Combo:MenuElement({id = "BOTRK", name = "Item - Blade of the Ruined King", value = true})
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
		RepoZed.Combo:MenuElement({id = "IG", name = "Spell - Ignite", value = true})
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
		RepoZed.Combo:MenuElement({id = "EX", name = "Spell - Exhaust", value = true})
	end

RepoZed:MenuElement({id = "Harass", name = "Harass", type = MENU})
	RepoZed.Harass:MenuElement({id = "Q", name = "Q - Razor Shuriken", value = true})
	RepoZed.Harass:MenuElement({id = "W", name = "W - Living Shadow", value = true})
	RepoZed.Harass:MenuElement({id = "E", name = "E - Shadow Slash", value = true})
	RepoZed.Harass:MenuElement({id = "MP", name = "Min energy", value = 35, min = 0, max = 100})

RepoZed:MenuElement({id = "Clear", name = "Clear", type = MENU})
	RepoZed.Clear:MenuElement({id = "Q", name = "Q - Razor Shuriken", value = true})
	RepoZed.Clear:MenuElement({id = "W", name = "W - Living Shadow", value = true})
	RepoZed.Clear:MenuElement({id = "WX", name = "Minions [for lane]", value = 5, min = 1, max = 7})
	RepoZed.Clear:MenuElement({id = "E", name = "E - Shadow Slash", value = true})
	RepoZed.Clear:MenuElement({id = "EX", name = "Minions [for lane]", value = 5, min = 1, max = 7})
	RepoZed.Clear:MenuElement({id = "MP", name = "Min energy", value = 35, min = 0, max = 100})
	RepoZed.Clear:MenuElement({id = "Key", name = "Enable/Disable", key = string.byte("A"), toggle = true})

RepoZed:MenuElement({id = "Utility", name = " ", drop = {"Champion Utility"}})
RepoZed:MenuElement({id = "Leveler", name = "Auto Leveler", type = MENU})
    RepoZed.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
    RepoZed.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
    RepoZed.Leveler:MenuElement({id = "Order", name = "Skill Priority", value = 7, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]","Zed's best sequence"}})

RepoZed:MenuElement({type = MENU, id = "Activator", name = "Activator"})
	RepoZed.Activator:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
	RepoZed.Activator.CS:MenuElement({id = "Blind", name = "Blind", value = false})
	RepoZed.Activator.CS:MenuElement({id = "Charm", name = "Charm", value = true})
	RepoZed.Activator.CS:MenuElement({id = "Flee", name = "Flee", value = true})
	RepoZed.Activator.CS:MenuElement({id = "Slow", name = "Slow", value = false})
	RepoZed.Activator.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
	RepoZed.Activator.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
	RepoZed.Activator.CS:MenuElement({id = "Silence", name = "Silence", value = true})
	RepoZed.Activator.CS:MenuElement({id = "Stun", name = "Stun", value = true})
	RepoZed.Activator.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
	RepoZed.Activator:MenuElement({type = MENU, id = "P", name = "Potions"})
	RepoZed.Activator.P:MenuElement({id = "Pot", name = "All Potions", value = true})
	RepoZed.Activator.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
	RepoZed.Activator:MenuElement({type = MENU, id = "I", name = "Items"})
	RepoZed.Activator.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
	RepoZed.Activator.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
	RepoZed.Activator.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
	RepoZed.Activator.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
	RepoZed.Activator.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
	RepoZed.Activator.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
	RepoZed.Activator.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
	RepoZed.Activator.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
	RepoZed.Activator.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
	RepoZed.Activator.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
	RepoZed.Activator.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
	RepoZed.Activator.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
	RepoZed.Activator.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
	RepoZed.Activator.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
	RepoZed.Activator.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
	RepoZed.Activator.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
	RepoZed.Activator.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
	RepoZed.Activator.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
	RepoZed.Activator.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
	RepoZed.Activator.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
	RepoZed.Activator.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
	RepoZed.Activator.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})
	
	RepoZed.Activator:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			RepoZed.Activator.S:MenuElement({id = "Smite", name = "Combo Smite", value = true})
			RepoZed.Activator.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
			RepoZed.Activator.S:MenuElement({id = "Heal", name = "Heal", value = true})
			RepoZed.Activator.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
			RepoZed.Activator.S:MenuElement({id = "Barrier", name = "Barrier", value = true})
			RepoZed.Activator.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			RepoZed.Activator.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			RepoZed.Activator.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
			RepoZed.Activator.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
		end

RepoZed:MenuElement({id = "Draw", name = "Drawings", type = MENU})
    RepoZed.Draw:MenuElement({id = "Q", name = "Q - Razor Shuriken", value = true})
    RepoZed.Draw:MenuElement({id = "W", name = "W - Living Shadow", value = true})
    RepoZed.Draw:MenuElement({id = "E", name = "E - Shadow Slash", value = true})
    RepoZed.Draw:MenuElement({id = "R", name = "R - Death Mark", value = true})
    RepoZed.Draw:MenuElement({id = "C", name = "Enable Text", value = true})
    RepoZed.Draw:MenuElement({id = "D", name = "Damage by %", value = true})

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
	end
	Activator()
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
	if RepoZed.Leveler.Enabled:Value() == false then return end
	local Sequence = {
		[1] = { HK_Q, HK_W, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_W, HK_Q, HK_W, HK_R, HK_W, HK_W, HK_E, HK_E, HK_R, HK_E, HK_E },
		[2] = { HK_Q, HK_E, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_E, HK_Q, HK_E, HK_R, HK_E, HK_E, HK_W, HK_W, HK_R, HK_W, HK_W },
		[3] = { HK_W, HK_Q, HK_E, HK_W, HK_W, HK_R, HK_W, HK_Q, HK_W, HK_Q, HK_R, HK_Q, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_E },
		[4] = { HK_W, HK_E, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_E, HK_W, HK_E, HK_R, HK_E, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
		[5] = { HK_E, HK_Q, HK_W, HK_E, HK_E, HK_R, HK_E, HK_Q, HK_E, HK_Q, HK_R, HK_Q, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_W },
        [6] = { HK_E, HK_W, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_W, HK_E, HK_W, HK_R, HK_W, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
        [7] = { HK_Q, HK_W, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_E, HK_Q, HK_E, HK_R, HK_E, HK_E, HK_W, HK_W, HK_R, HK_W, HK_W },
	}
	local Slot = nil
	local Tick = 0
	local SkillPoints = myHero.levelData.lvl - (myHero:GetSpellData(_Q).level + myHero:GetSpellData(_W).level + myHero:GetSpellData(_E).level + myHero:GetSpellData(_R).level)
	local level = myHero.levelData.lvl
	local Check = Sequence[RepoZed.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RepoZed.Leveler.Block:Value() and level == 1 then return end
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

function CastQ(target,from)
	if Ready(_Q) and castSpell.state == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
            local qPred = GetPred(target,Q.speed,Q.delay + Game.Latency()/1000,from)
            CastSpell(HK_Q,qPred,Q.range + 200,250)
        end
	end
end

function CastW(target)
	if Ready(_W) and castSpell.state == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
            local wPred = GetPred(target,W.speed,W.delay + Game.Latency()/1000)
			CastSpell(HK_W,wPred,W.range + 200,250)
			_shadowPos = wPred
        end
	end
end

function Combo()
    local target = GetTarget(Q.range + W.range)
    if target == nil then return end
    
    if IsValidTarget(target,R.range) and Ready(_R) and RepoZed.Combo.R:Value() and Passivedmg(target) + ELdmg(target) + ComboAA(target) + Qdmg(target) + Edmg(target) + IGdmg(target) + BOTRKdmg(target) + Rdmg(target) > target.health and myHero:GetSpellData(_R).toggleState == 0 then
		Control.CastSpell(HK_R,target)
	end
	if IsValidTarget(target,W.range + E.range) and RepoZed.Combo.W:Value() and Ready(_W) and myHero:GetSpellData(_W).toggleState == 0 then
		if not Ready(_Q) and not Ready(_E) then return end
		CastW(target)
	end
	if RepoZed.Combo.E:Value() and Ready(_E) then
		if (HeroesAround(_shadowPos, 290, 300 - myHero.team) >= 1 and myHero:GetSpellData(_W).toggleState == 2)
		or HeroesAround(myHero.pos, 290, 300 - myHero.team) >= 1 then
			Control.CastSpell(HK_E)
		end
	end
	if myHero:GetSpellData(_W).toggleState == 2 and GetDistance(_shadowPos,target.pos) < GetDistance(myHero.pos,target.pos) then
		_shadowPos = myHero.pos
		Control.CastSpell(HK_W)
	end
	if IsValidTarget(target,Q.range + W.range) and RepoZed.Combo.Q:Value() and Ready(_Q) then
		if Ready(_W) and myHero:GetSpellData(_W).toggleState == 0 then return end
		if GetDistance(target.pos,_shadowPos) >= GetDistance(target.pos,myHero.pos) then
			if GetDistance(target.pos,myHero.pos) <= Q.range then
				CastQ(target,myHero.pos)
			end
		else
			if GetDistance(target.pos,_shadowPos) <= Q.range then
				CastQ(target,_shadowPos)
			end
		end
	end
end

function Harass()
	local target = GetTarget(Q.range + W.range)
	if target == nil then return end
	if myHero.mana < RepoZed.Harass.MP:Value() * 2 then return end

	if IsValidTarget(target,W.range + E.range) and RepoZed.Harass.W:Value() and Ready(_W) and myHero:GetSpellData(_W).toggleState == 0 then
		if not Ready(_Q) and not Ready(_E) then return end
		CastW(target)
	end
	if RepoZed.Harass.E:Value() and Ready(_E) then
		if (HeroesAround(_shadowPos, 290, 300 - myHero.team) >= 1 and myHero:GetSpellData(_W).toggleState == 2)
		or HeroesAround(myHero.pos, 290, 300 - myHero.team) >= 1 then
			Control.CastSpell(HK_E)
		end
	end
	if IsValidTarget(target,Q.range) and RepoZed.Harass.Q:Value() and Ready(_Q) then
		if Ready(_W) and myHero:GetSpellData(_W).toggleState == 0 then return end
		if GetDistance(target.pos,_shadowPos) >= GetDistance(target.pos,myHero.pos) then
			if GetDistance(target.pos,myHero.pos) <= Q.range then
				CastQ(target,myHero.pos)
			end
		else
			if GetDistance(target.pos,_shadowPos) <= Q.range then
				CastQ(target,_shadowPos)
			end
		end
	end
end

function Lane()
	if RepoZed.Clear.Key:Value() == false then return end
	if myHero.mana < RepoZed.Clear.MP:Value() * 2 then return end
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion then
			if minion.team == 300 - myHero.team then
				if IsValidTarget(minion,W.range) and RepoZed.Clear.W:Value() and Ready(_W) and MinionsAround(minion.pos, 290, 300 - myHero.team) >= RepoZed.Clear.WX:Value() and myHero:GetSpellData(_W).toggleState == 0 then
					CastW(minion)
				end
				if RepoZed.Clear.E:Value() and Ready(_E) then
					if (HeroesAround(_shadowPos, 290, 300 - myHero.team) >= RepoZed.Clear.EX:Value() and myHero:GetSpellData(_W).toggleState == 2)
					or MinionsAround(myHero.pos, 290, 300 - myHero.team) >= RepoZed.Clear.EX:Value() then
						Control.CastSpell(HK_E)
					end
				end
				if IsValidTarget(minion,W.range + Q.range) and RepoZed.Clear.Q:Value() and Ready(_Q) then
					if GetDistance(minion.pos,_shadowPos) >= GetDistance(minion.pos,myHero.pos) then
						if GetDistance(minion.pos,myHero.pos) <= Q.range then
							CastQ(minion,_shadowPos)
						end
					else
						if GetDistance(minion.pos,_shadowPos) <= Q.range then
							CastQ(minion,myHero.pos)
						end
					end
				end
			end
			if minion.team == 300 then
				if IsValidTarget(minion,W.range) and RepoZed.Clear.W:Value() and Ready(_W) and MinionsAround(minion.pos, 290, 300) >= 1 and myHero:GetSpellData(_W).toggleState == 0 then
					CastW(minion)
				end
				if RepoZed.Clear.E:Value() and Ready(_E) then
					if MinionsAround(_shadowPos, 290, 300) >= 1 
					or MinionsAround(myHero.pos, 290, 300) >= 1 then
						Control.CastSpell(HK_E)
					end
				end
				if IsValidTarget(minion,W.range + Q.range) and RepoZed.Clear.Q:Value() and Ready(_Q) then
					if GetDistance(minion.pos,_shadowPos) >= GetDistance(minion.pos,myHero.pos) then
						if GetDistance(minion.pos,myHero.pos) <= Q.range then
							CastQ(minion,_shadowPos)
						end
					else
						if GetDistance(minion.pos,_shadowPos) <= Q.range then
							CastQ(minion,myHero.pos)
						end
					end
				end
			end
		end
	end
end

function Activator()
	local target = GetTarget(W.range + Q.range)
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    if GetMode() == "Combo" then
    if target == nil then return end
        local BOTRK = items[3144] or items[3146]
        if BOTRK and myHero:GetSpellData(BOTRK).currentCd == 0 and RepoZed.Combo.BOTRK:Value() and GetDistance(myHero.pos,target.pos) < 550 then
            if myHero:GetSpellData(_R).toggleState ~= 0 then
                Control.CastSpell(HKITEM[BOTRK], target)
            end
        end
        if (myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1))
		or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2)) then
			if RepoZed.Combo.IG:Value() and myHero:GetSpellData(_R).toggleState ~= 0 then
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			if RepoZed.Combo.EX:Value() and myHero:GetSpellData(_R).toggleState ~= 0 then
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" and Ready(SUMMONER_1) then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" and Ready(SUMMONER_2) then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
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
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and RepoZed.Activator.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and RepoZed.Activator.P.Pot:Value() and PercentHP(myHero) < RepoZed.Activator.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and RepoZed.Activator.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and RepoZed.Activator.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and RepoZed.Activator.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and RepoZed.Activator.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and RepoZed.Activator.D.Locket:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and RepoZed.Activator.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and PercentHP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if RepoZed.Activator.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoZed.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoZed.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if RepoZed.Activator.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoZed.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoZed.Activator.S.BarrierHP:Value() then
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
					if ((buff.type == 5 and RepoZed.Activator.CS.Stun:Value())
					or (buff.type == 7 and  RepoZed.Activator.CS.Silence:Value())
					or (buff.type == 8 and  RepoZed.Activator.CS.Taunt:Value())
					or (buff.type == 9 and  RepoZed.Activator.CS.Poly:Value())
					or (buff.type == 10 and  RepoZed.Activator.CS.Slow:Value())
					or (buff.type == 11 and  RepoZed.Activator.CS.Root:Value())
					or (buff.type == 21 and  RepoZed.Activator.CS.Flee:Value())
					or (buff.type == 22 and  RepoZed.Activator.CS.Charm:Value())
					or (buff.type == 25 and  RepoZed.Activator.CS.Blind:Value())
					or (buff.type == 28 and  RepoZed.Activator.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and RepoZed.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and RepoZed.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and RepoZed.Activator.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and RepoZed.Activator.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and RepoZed.Activator.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and RepoZed.Activator.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and RepoZed.Activator.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and RepoZed.Activator.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and RepoZed.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and RepoZed.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and RepoZed.Activator.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and RepoZed.Activator.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and RepoZed.Activator.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and RepoZed.Activator.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and RepoZed.Activator.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if RepoZed.Activator.S.Smite:Value() then
				local RedDamage = Qdmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoZed.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoZed.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				local BlueDamage = Qdmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoZed.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoZed.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RepoZed.Activator.S.Ignite:Value() then
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
    if RepoZed.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.range, 3,  Draw.Color(255, 000, 222, 255)) end
    if RepoZed.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.range, 3,  Draw.Color(255, 255, 200, 000)) end
	if RepoZed.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.range, 3,  Draw.Color(255, 000, 043, 255)) end
	if RepoZed.Draw.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.range, 3,  Draw.Color(255, 246, 000, 255)) end
	if RepoZed.Draw.C:Value() then
		local textPos = myHero.pos:To2D()
		if RepoZed.Clear.Key:Value() then
			Draw.Text("CLEAR ENABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("CLEAR DISABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 225, 000, 000)) 
		end
	end
	
	if RepoZed.Draw.D:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead and enemy.visible then
				local barPos = enemy.hpBar
				local health = enemy.health
				local maxHealth = enemy.maxHealth
				local Qdmg = Qdmg(enemy)
                local IGdmg = IGdmg(enemy)
                local BOTRKdmg = BOTRKdmg(enemy)
                local Edmg = Edmg(enemy)
				local Rdmg = Rdmg(enemy)
				local ELdmg = ELdmg(enemy)
				local ComboAA = ComboAA(enemy)
				local Passivedmg = Passivedmg(enemy)
				local Damage = Passivedmg + Qdmg + BOTRKdmg + Edmg + Rdmg
				if Damage < health then
					Draw.Text(tostring(0.1*math.floor(1000*math.min(1,Damage/enemy.health))).." %", 30, enemy.pos:To2D().x, enemy.pos:To2D().y, Draw.Color(255, 255, 000, 000))
				else
    				Draw.Text("KILLABLE", 30, enemy.pos:To2D().x, enemy.pos:To2D().y, Draw.Color(255, 255, 000, 000))
				end
			end
		end
	end
end
