-- 

if myHero.charName ~= "LeeSin" then return end

require "DamageLib"

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

local Q = {range = 1100, speed = 1750, delay = 0.25, width = myHero:GetSpellData(_Q).width}
local W = {range = 700}
local E = {range = 350}
local R = {range = 375}

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
    if Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" then
        return CalcPhysicalDamage(myHero,target,(25 + 30 * myHero:GetSpellData(_Q).level + 0.9 * myHero.bonusDamage))
    end
    return 0
end

local function Q2dmg(target)
    if Ready(_Q) then
        return CalcPhysicalDamage(myHero,target,(25 + 30 * myHero:GetSpellData(_Q).level + 0.9 * myHero.bonusDamage + (0.08 * (target.maxHealth - (target.health - Qdmg(target))))))
    end
    return 0
end

local function Edmg(target)
    if Ready(_E) then
        return CalcMagicalDamage(myHero,target,(35 + 35 * myHero:GetSpellData(_E).level + myHero.bonusDamage))
    end
    return 0
end

local function Rdmg(target)
    if Ready(_R) then
        return CalcPhysicalDamage(myHero,target,(150 * myHero:GetSpellData(_R).level + 2 * myHero.bonusDamage))
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

local function Buffed()
	for i = 0, myHero.buffCount do 
    local buff = myHero:GetBuff(i)
		if buff and buff.type == 2 then 
			return true
		end
	end
	return false
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

local RepoLeesin = MenuElement({type = MENU, id = "RepoLeesin", name = "Roman Repo 7.24", leftIcon = "https://raw.githubusercontent.com/RomanovHD/GOSext/master/Repository/Screenshot_1.png"})

RepoLeesin:MenuElement({id = "Me", name = "Leesin", drop = {"v1.0"}})
RepoLeesin:MenuElement({id = "Core", name = " ", drop = {"Champion Core"}})
RepoLeesin:MenuElement({id = "Combo", name = "Combo", type = MENU})
	RepoLeesin.Combo:MenuElement({id = "Q", name = "Q - Sonic Wave/Resonating Strike", value = true})
	RepoLeesin.Combo:MenuElement({id = "W", name = "W - Safeguard/Iron Will", value = true})
    RepoLeesin.Combo:MenuElement({id = "E", name = "E - Tempest/Cripple", value = true})
    RepoLeesin.Combo:MenuElement({id = "R", name = "R - Dragon's Rage", value = true})

RepoLeesin:MenuElement({id = "Harass", name = "Harass", type = MENU})
    RepoLeesin.Harass:MenuElement({id = "Q", name = "Q - Sonic Wave", value = true})
    RepoLeesin.Harass:MenuElement({id = "Q2", name = "Q2 - Resonating Strike", value = false})
	RepoLeesin.Harass:MenuElement({id = "W", name = "W - Safeguard/Iron Will", value = true})
    RepoLeesin.Harass:MenuElement({id = "E", name = "E - Tempest/Cripple", value = true})
	RepoLeesin.Harass:MenuElement({id = "MP", name = "Min energy", value = 35, min = 0, max = 100})

RepoLeesin:MenuElement({id = "Clear", name = "Clear", type = MENU})
    RepoLeesin.Clear:MenuElement({id = "Q", name = "Q - Sonic Wave/Resonating Strike", value = true})
    RepoLeesin.Clear:MenuElement({id = "W", name = "W - Safeguard/Iron Will", value = true})
    RepoLeesin.Clear:MenuElement({id = "WX", name = "Min minions [lane]", value = 4, min = 1, max = 7})
    RepoLeesin.Clear:MenuElement({id = "E", name = "E - Tempest/Cripple", value = true})
    RepoLeesin.Clear:MenuElement({id = "EX", name = "Min minions [lane]", value = 5, min = 1, max = 7})
	RepoLeesin.Clear:MenuElement({id = "MP", name = "Min mana", value = 35, min = 0, max = 100})
    RepoLeesin.Clear:MenuElement({id = "Key", name = "Enable/Disable", key = string.byte("A"), toggle = true})
    
RepoLeesin:MenuElement({id = "Killsteal", name = "Killsteal", type = MENU})
    RepoLeesin.Killsteal:MenuElement({id = "Q", name = "Q - Sonic Wave", value = true})
    RepoLeesin.Killsteal:MenuElement({id = "E", name = "E - Tempest", value = true})
	RepoLeesin.Killsteal:MenuElement({id = "R", name = "R - Dragon's Rage", value = true})

RepoLeesin:MenuElement({id = "Flee", name = "Flee", type = MENU})
    RepoLeesin.Flee:MenuElement({id = "W", name = "W - Safeguard", value = true})

RepoLeesin:MenuElement({id = "Utility", name = " ", drop = {"Champion Utility"}})
RepoLeesin:MenuElement({id = "Leveler", name = "Auto Leveler", type = MENU})
    RepoLeesin.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
    RepoLeesin.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
    RepoLeesin.Leveler:MenuElement({id = "Order", name = "Skill Priority", value = 1, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

RepoLeesin:MenuElement({type = MENU, id = "Activator", name = "Activator"})
	RepoLeesin.Activator:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
	RepoLeesin.Activator.CS:MenuElement({id = "Blind", name = "Blind", value = false})
	RepoLeesin.Activator.CS:MenuElement({id = "Charm", name = "Charm", value = true})
	RepoLeesin.Activator.CS:MenuElement({id = "Flee", name = "Flee", value = true})
	RepoLeesin.Activator.CS:MenuElement({id = "Slow", name = "Slow", value = false})
	RepoLeesin.Activator.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
	RepoLeesin.Activator.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
	RepoLeesin.Activator.CS:MenuElement({id = "Silence", name = "Silence", value = true})
	RepoLeesin.Activator.CS:MenuElement({id = "Stun", name = "Stun", value = true})
	RepoLeesin.Activator.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
	RepoLeesin.Activator:MenuElement({type = MENU, id = "P", name = "Potions"})
	RepoLeesin.Activator.P:MenuElement({id = "Pot", name = "All Potions", value = true})
	RepoLeesin.Activator.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
	RepoLeesin.Activator:MenuElement({type = MENU, id = "I", name = "Items"})
	RepoLeesin.Activator.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
	RepoLeesin.Activator.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
	RepoLeesin.Activator.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
	RepoLeesin.Activator.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
	RepoLeesin.Activator.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
	RepoLeesin.Activator.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
	RepoLeesin.Activator.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
	RepoLeesin.Activator.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
	RepoLeesin.Activator.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
	RepoLeesin.Activator.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
	RepoLeesin.Activator.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
	RepoLeesin.Activator.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
	RepoLeesin.Activator.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
	RepoLeesin.Activator.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
	RepoLeesin.Activator.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
	RepoLeesin.Activator.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
	RepoLeesin.Activator.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
	RepoLeesin.Activator.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
	RepoLeesin.Activator.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
	RepoLeesin.Activator.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
	RepoLeesin.Activator.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
	RepoLeesin.Activator.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})
	
	RepoLeesin.Activator:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			RepoLeesin.Activator.S:MenuElement({id = "Smite", name = "Combo Smite", value = true})
			RepoLeesin.Activator.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
			RepoLeesin.Activator.S:MenuElement({id = "Heal", name = "Heal", value = true})
			RepoLeesin.Activator.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
			RepoLeesin.Activator.S:MenuElement({id = "Barrier", name = "Barrier", value = true})
			RepoLeesin.Activator.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			RepoLeesin.Activator.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			RepoLeesin.Activator.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
			RepoLeesin.Activator.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
		end

RepoLeesin:MenuElement({id = "Draw", name = "Drawings", type = MENU})
    RepoLeesin.Draw:MenuElement({id = "Q", name = "Q - Sonic Wave", value = true})
    RepoLeesin.Draw:MenuElement({id = "W", name = "W - Safeguard", value = true})
    RepoLeesin.Draw:MenuElement({id = "E", name = "E - Tempest", value = true})
    RepoLeesin.Draw:MenuElement({id = "R", name = "R - Dragon's Rage", value = true})
    RepoLeesin.Draw:MenuElement({id = "C", name = "Enable Text", value = true})

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
	if RepoLeesin.Leveler.Enabled:Value() == false then return end
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
	local Check = Sequence[RepoLeesin.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RepoLeesin.Leveler.Block:Value() and level == 1 then return end
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
	if Ready(_Q) and castSpell.state == 0 and target:GetCollision(Q.width, Q.speed, Q.delay) == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
            local qPred = GetPred(target,Q.speed,Q.delay + Game.Latency()/1000)
            CastSpell(HK_Q,qPred,Q.range + 200,250)
        end
	end
end

function Combo()
    local target = GetTarget(1300)
    if target == nil then return end

    if IsValidTarget(target,R.range) and RepoLeesin.Combo.R:Value() and Ready(_R) and Rdmg(target) + Qdmg(target) + Q2dmg(target) + Edmg(target) > target.health then
        Control.CastSpell(HK_R, target)
    end

    if GetDistance(myHero.pos,target.pos) < myHero.range and Buffed() then return end
    
	if IsValidTarget(target,Q.range) and RepoLeesin.Combo.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" then
		CastQ(target)
    end
    if IsValidTarget(target,1300) and RepoLeesin.Combo.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQTwo" then
        Control.CastSpell(HK_Q)
    end
    if IsValidTarget(target,E.range) and RepoLeesin.Combo.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkEOne" then
		Control.CastSpell(HK_E)
    end
    if IsValidTarget(target,500) and RepoLeesin.Combo.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkETwo" then
		Control.CastSpell(HK_E)
	end
    if IsValidTarget(target,E.range) and RepoLeesin.Combo.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWOne" then
		Control.CastSpell(HK_W, myHero)
    end
    if IsValidTarget(target,E.range) and RepoLeesin.Combo.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWTwo" then
		Control.CastSpell(HK_W)
	end
end

function Harass()
	local target = GetTarget(Q.range)
	if target == nil then return end
    if myHero.mana < RepoLeesin.Harass.MP:Value() * 2 then return end
    if GetDistance(myHero.pos,target.pos) < myHero.range and Buffed() then return end
    
	if IsValidTarget(target,Q.range) and RepoLeesin.Harass.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" then
		CastQ(target)
    end
    if IsValidTarget(target,1300) and RepoLeesin.Harass.Q2:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQTwo" then
        Control.CastSpell(HK_Q)
    end
    if IsValidTarget(target,E.range) and RepoLeesin.Harass.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkEOne" then
		Control.CastSpell(HK_E)
    end
    if IsValidTarget(target,500) and RepoLeesin.Harass.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkETwo" then
		Control.CastSpell(HK_E)
	end
    if IsValidTarget(target,E.range) and RepoLeesin.Harass.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWOne" then
		Control.CastSpell(HK_W, myHero)
    end
    if IsValidTarget(target,E.range) and RepoLeesin.Harass.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWTwo" then
		Control.CastSpell(HK_W)
	end
end

function Lane()
	if RepoLeesin.Clear.Key:Value() == false then return end
	if myHero.mana < RepoLeesin.Clear.MP:Value() * 2 then return end
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion then
        if GetDistance(myHero.pos,minion.pos) < myHero.range and Buffed() then return end
			if minion.team == 300 - myHero.team then
				if IsValidTarget(minion,Q.range) and minion:GetCollision(Q.width, Q.speed, Q.delay) == 0 and RepoLeesin.Clear.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" and Qdmg(minion) + Q2dmg(minion) > minion.health then
                    Control.CastSpell(HK_Q, minion)
                end
                if IsValidTarget(minion,Q.range) and RepoLeesin.Clear.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQTwo" then
                    Control.CastSpell(HK_Q)
                end
                if MinionsAround(myHero.pos, E.range, 300 - myHero.team) >= RepoLeesin.Clear.EX:Value() and RepoLeesin.Clear.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkEOne" then
                    Control.CastSpell(HK_E)
                end
                if IsValidTarget(minion,500) and RepoLeesin.Clear.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkETwo" then
                    Control.CastSpell(HK_E)
                end
                if MinionsAround(myHero.pos, E.range, 300 - myHero.team) >= RepoLeesin.Clear.WX:Value() and RepoLeesin.Clear.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWOne" then
                    Control.CastSpell(HK_W, myHero)
                end
                if IsValidTarget(minion,E.range) and RepoLeesin.Clear.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWTwo" then
                    Control.CastSpell(HK_W)
                end
			end
			if minion.team == 300 then
				if IsValidTarget(minion,Q.range) and minion:GetCollision(Q.width, Q.speed, Q.delay) == 0 and RepoLeesin.Clear.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" then
                    Control.CastSpell(HK_Q, minion)
                end
                if IsValidTarget(minion,Q.range) and RepoLeesin.Clear.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQTwo" then
                    Control.CastSpell(HK_Q)
                end
                if IsValidTarget(minion,E.range) and RepoLeesin.Clear.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkEOne" then
                    Control.CastSpell(HK_E)
                end
                if IsValidTarget(minion,500) and RepoLeesin.Clear.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkETwo" then
                    Control.CastSpell(HK_E)
                end
                if IsValidTarget(minion,E.range) and RepoLeesin.Clear.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWOne" then
                    Control.CastSpell(HK_W, myHero)
                end
                if IsValidTarget(minion,E.range) and RepoLeesin.Clear.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWTwo" then
                    Control.CastSpell(HK_W)
                end
			end
		end
	end
end

function Killsteal()
    local target = GetTarget(R.range)
    if target == nil then return end

    if IsValidTarget(target,Q.range) and RepoLeesin.Killsteal.Q:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" and Qdmg(target) > target.health then
        CastQ(target)
    end
    if IsValidTarget(target,E.range) and RepoLeesin.Killsteal.E:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkEOne" and Edmg(target) > target.health then
        Control.CastSpell(HK_E)
    end
    if IsValidTarget(target,R.range) and RepoLeesin.Killsteal.R:Value() and Ready(_R) and Rdmg(target) > target.health then
        Control.CastSpell(HK_R,target)
    end
end

function GetFleeMinion(range,team)
	local best = nil
	local closest = math.huge
	for i = 1, Game.MinionCount() do
		local m = Game.Minion(i)
		if m.team == team and GetDistance(myHero.pos,m.pos) < range then
			local DistanceM = GetDistance(myHero.pos, mousePos)
			local DistanceP = GetDistance(myHero.pos + (m.pos - myHero.pos):Normalized() * 400, mousePos)
			local DistanceC = GetDistance(myHero.pos + (m.pos - myHero.pos):Normalized() * 700, myHero.pos)
			if DistanceP < DistanceM and DistanceC < closest then
				best = m
				closest = DistanceC
			end
		end
	end
	return best
end

function GetFleeHero(range)
	local best = nil
	local closest = math.huge
	for i = 1, Game.HeroCount() do
		local m = Game.Hero(i)
		if m.team == myHero.team and GetDistance(myHero.pos,m.pos) < range then
			local DistanceM = GetDistance(myHero.pos, mousePos)
			local DistanceP = GetDistance(myHero.pos + (m.pos - myHero.pos):Normalized() * 400, mousePos)
			local DistanceC = GetDistance(myHero.pos + (m.pos - myHero.pos):Normalized() * 700, myHero.pos)
			if DistanceP < DistanceM and DistanceC < closest then
				best = m
				closest = DistanceC
			end
		end
	end
	return best
end

function Flee()
	local Wally = GetFleeHero(W.range)
	local Wminion = GetFleeMinion(W.range,myHero.team)
	if RepoLeesin.Flee.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWOne" and Wally then
		Control.CastSpell(HK_W, Wally.pos)
	end
	if RepoLeesin.Flee.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name == "BlindMonkWOne" and Wminion then
		Control.CastSpell(HK_W, Wminion.pos)
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
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and RepoLeesin.Activator.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and RepoLeesin.Activator.P.Pot:Value() and PercentHP(myHero) < RepoLeesin.Activator.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and RepoLeesin.Activator.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and RepoLeesin.Activator.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and RepoLeesin.Activator.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and RepoLeesin.Activator.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and RepoLeesin.Activator.D.Locket:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and RepoLeesin.Activator.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and PercentHP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if RepoLeesin.Activator.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoLeesin.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoLeesin.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if RepoLeesin.Activator.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoLeesin.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoLeesin.Activator.S.BarrierHP:Value() then
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
					if ((buff.type == 5 and RepoLeesin.Activator.CS.Stun:Value())
					or (buff.type == 7 and  RepoLeesin.Activator.CS.Silence:Value())
					or (buff.type == 8 and  RepoLeesin.Activator.CS.Taunt:Value())
					or (buff.type == 9 and  RepoLeesin.Activator.CS.Poly:Value())
					or (buff.type == 10 and  RepoLeesin.Activator.CS.Slow:Value())
					or (buff.type == 11 and  RepoLeesin.Activator.CS.Root:Value())
					or (buff.type == 21 and  RepoLeesin.Activator.CS.Flee:Value())
					or (buff.type == 22 and  RepoLeesin.Activator.CS.Charm:Value())
					or (buff.type == 25 and  RepoLeesin.Activator.CS.Blind:Value())
					or (buff.type == 28 and  RepoLeesin.Activator.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and RepoLeesin.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and RepoLeesin.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and RepoLeesin.Activator.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and RepoLeesin.Activator.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and RepoLeesin.Activator.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and RepoLeesin.Activator.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and RepoLeesin.Activator.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and RepoLeesin.Activator.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and RepoLeesin.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and RepoLeesin.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and RepoLeesin.Activator.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and RepoLeesin.Activator.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and RepoLeesin.Activator.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and RepoLeesin.Activator.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and RepoLeesin.Activator.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if RepoLeesin.Activator.S.Smite:Value() then
				local RedDamage = Qdmg(target) + Q2dmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoLeesin.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoLeesin.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				local BlueDamage = Qdmg(target) + Q2dmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoLeesin.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoLeesin.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RepoLeesin.Activator.S.Ignite:Value() then
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
    if RepoLeesin.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.range, 3,  Draw.Color(255, 000, 222, 255)) end
    if RepoLeesin.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.range, 3,  Draw.Color(255, 255, 200, 000)) end
    if RepoLeesin.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.range, 3,  Draw.Color(255, 000, 043, 255)) end
    if RepoLeesin.Draw.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.range, 3,  Draw.Color(255, 255, 000, 000)) end
	if RepoLeesin.Draw.C:Value() then
		local textPos = myHero.pos:To2D()
		if RepoLeesin.Clear.Key:Value() then
			Draw.Text("CLEAR ENABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("CLEAR DISABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 225, 000, 000)) 
		end
    end
	
	if RepoLeesin.Draw.D:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead and enemy.visible then
				local barPos = enemy.hpBar
				local health = enemy.health
				local maxHealth = enemy.maxHealth
                local Qdmg = Qdmg(enemy)
                local Q2dmg = Q2dmg(enemy)
                local Edmg = Edmg(enemy)
				local Rdmg = Rdmg(enemy)
				local Damage = Qdmg + Q2dmg + Edmg + Rdmg
				if Damage < health then
					Draw.Text(tostring(0.1*math.floor(1000*math.min(1,Damage/enemy.health))).." %", 30, enemy.pos:To2D().x, enemy.pos:To2D().y, Draw.Color(255, 255, 000, 000))
				else
    				Draw.Text("KILLABLE", 30, enemy.pos:To2D().x, enemy.pos:To2D().y, Draw.Color(255, 255, 000, 000))
				end
			end
		end
	end
end
