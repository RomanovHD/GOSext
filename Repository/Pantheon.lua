if myHero.charName ~= "Pantheon" then return end

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

local Q = {range = 600}
local W = {range = 600}
local E = {range = 600, speed = math.huge, delay = 0.25, width = 80}

local function Qdmg(target)
    if Ready(_Q) then
        return CalcPhysicalDamage(myHero,target,(25 + 30 * myHero:GetSpellData(_Q).level + 0.9 * myHero.bonusDamage))
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

local function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

local RepoPantheon = MenuElement({type = MENU, id = "RepoPantheon", name = "Roman Repo 8.3", leftIcon = "https://raw.githubusercontent.com/RomanovHD/GOSext/master/Repository/Screenshot_1.png"})

RepoPantheon:MenuElement({id = "Me", name = "Pantheon", drop = {"v1.00"}})
RepoPantheon:MenuElement({id = "Core", name = " ", drop = {"Champion Core"}})
RepoPantheon:MenuElement({id = "Combo", name = "Combo", type = MENU})
	RepoPantheon.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
    RepoPantheon.Combo:MenuElement({id = "W", name = "Use W", value = true})
    RepoPantheon.Combo:MenuElement({id = "WD", name = "Min W distance", value = 350, min = 0, max = 600})
    RepoPantheon.Combo:MenuElement({id = "E", name = "Use E", value = true})

RepoPantheon:MenuElement({id = "Harass", name = "Harass", type = MENU})
    RepoPantheon.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
    RepoPantheon.Harass:MenuElement({id = "CH", name = "Harass with clear", value = true})
	RepoPantheon.Harass:MenuElement({id = "MP", name = "Min mana", value = 50, min = 0, max = 100})

RepoPantheon:MenuElement({id = "Clear", name = "Clear", type = MENU})
    RepoPantheon.Clear:MenuElement({id = "Q", name = "Q Lane + Jungle", value = true})
    RepoPantheon.Clear:MenuElement({id = "W", name = "W Jungle", value = true})
    RepoPantheon.Clear:MenuElement({id = "E", name = "E Lane + Jungle", value = true})
	RepoPantheon.Clear:MenuElement({id = "MP", name = "Min mana", value = 50, min = 0, max = 100})
    RepoPantheon.Clear:MenuElement({id = "Key", name = "Enable/Disable", key = string.byte("A"), toggle = true})

RepoPantheon:MenuElement({id = "Utility", name = " ", drop = {"Champion Utility"}})
RepoPantheon:MenuElement({id = "Leveler", name = "Auto Leveler", type = MENU})
    RepoPantheon.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
    RepoPantheon.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
    RepoPantheon.Leveler:MenuElement({id = "Order", name = "Skill Priority", value = 1, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

RepoPantheon:MenuElement({id = "Draw", name = "Drawings", type = MENU})
    RepoPantheon.Draw:MenuElement({id = "QWE", name = "Q/W/E range", value = true})
    RepoPantheon.Draw:MenuElement({id = "C", name = "Enable Text", value = true})

Callback.Add("Tick", function() Tick() end)
Callback.Add("Draw", function() Drawings() end)

function Tick()
    local Eactive = HasBuff(myHero, "pantheonesound")
	local Mode = GetMode()
    if not Eactive then
        if Mode == "Combo" then
		    Combo()
	    elseif Mode == "Harass" then
		    Harass()
        elseif Mode == "Clear" then
		    Lane()
        end
    end
        OrbControl()
        AutoLevel()
end

function OrbControl()
    local Eactive = HasBuff(myHero, "pantheonesound")
    if Eactive then
        EnableOrb(false)
    else
        EnableOrb(true)
    end
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
	if RepoPantheon.Leveler.Enabled:Value() == false then return end
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
	local Check = Sequence[RepoPantheon.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RepoPantheon.Leveler.Block:Value() and level == 1 then return end
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

function CastE(target)
	if target.ms ~= 0 and (E.range - GetDistance(target.pos,myHero.pos))/target.ms <= GetDistance(myHero.pos,target.pos)/(E.speed + E.delay) and not IsFacing(target) then return end
	if Ready(_E) and castSpell.state == 0 and target:GetCollision(E.width, E.speed, E.delay) == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
            local ePred = GetPred(target,E.speed,E.delay + Game.Latency()/1000)
            CastSpell(HK_E,ePred,E.range + 200,250)
        end
	end
end

function Combo()
    local target = GetTarget(600)
    if target == nil then return end

    if IsValidTarget(target,600) and RepoPantheon.Combo.Q:Value() and Ready(_Q) then
        Control.CastSpell(HK_Q, target)
    end
    if IsValidTarget(target,600) and RepoPantheon.Combo.E:Value() and Ready(_E) then
		CastE(target)
	end
    if IsValidTarget(target,600) and RepoPantheon.Combo.W:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) >= RepoPantheon.Combo.WD:Value() then
		Control.CastSpell(HK_W, target)
    end
end

function Harass()
	local target = GetTarget(600)
	if target == nil then return end
    if PercentMP(myHero) < RepoPantheon.Harass.MP:Value() then return end
    
	if IsValidTarget(target,600) and RepoPantheon.Harass.Q:Value() and Ready(_Q) then
        Control.CastSpell(HK_Q, target)
    end
end

function Lane()
    if RepoPantheon.Harass.CH:Value() then
        Harass()
    end

	if RepoPantheon.Clear.Key:Value() == false then return end
	if PercentMP(myHero) < RepoPantheon.Clear.MP:Value() then return end
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion then
			if minion.team == 300 - myHero.team then
				if IsValidTarget(minion,600) and RepoPantheon.Clear.Q:Value() and Ready(_Q) then
                    Control.CastSpell(HK_Q, minion)
                end
                if IsValidTarget(minion,600) and RepoPantheon.Clear.E:Value() and Ready(_E) then
                    Control.CastSpell(HK_E, minion.pos)
                end
			end
			if minion.team == 300 then
				if IsValidTarget(minion,600) and RepoPantheon.Clear.Q:Value() and Ready(_Q) then
                    Control.CastSpell(HK_Q, minion)
                end
                if IsValidTarget(minion,600) and RepoPantheon.Clear.W:Value() and Ready(_W) then
                    Control.CastSpell(HK_W, minion)
                end
                if IsValidTarget(minion,600) and RepoPantheon.Clear.E:Value() and Ready(_E) then
                    Control.CastSpell(HK_E, minion.pos)
                end
			end
		end
	end
end

function Drawings()
    if myHero.dead then return end
    if RepoPantheon.Draw.QWE:Value() then Draw.Circle(myHero.pos, 600, 3,  Draw.Color(255, 000, 222, 255)) end
    if RepoPantheon.Draw.C:Value() then
		local textPos = myHero.pos:To2D()
		if RepoPantheon.Clear.Key:Value() then
			Draw.Text("CLEAR ENABLED", 15, textPos.x - 57, textPos.y + 40, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("CLEAR DISABLED", 15, textPos.x - 57, textPos.y + 40, Draw.Color(255, 225, 000, 000)) 
		end
    end
end
