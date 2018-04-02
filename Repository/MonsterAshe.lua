require 'DamageLib'
require 'HPred'

local Version = "v1.00"
--- Engine ---
local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function PercentHP(target)
    return 100 * target.health / target.maxHealth
end

local function PercentMP(target)
    return 100 * target.mana / target.maxMana
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
end

local function MinionsAround(range, pos, team)
    local pos = pos or myHero.pos
    local team = team or 300 - myHero.team
    local Count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

local function HeroesAround(range, pos, team)
    local pos = pos or myHero.pos
    local team = team or 300 - myHero.team
    local Count = 0
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.team == team and not hero.dead and hero.pos:DistanceTo(pos, hero.pos) < range then
			Count = Count + 1
		end
	end
	return Count
end

local function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

local function GetDistance(Pos1, Pos2)
	return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

local function GetDistance2D(p1,p2)
    local p2 = p2 or myHero
    return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2))
end

local function GetTarget(range)
	local target = nil
	if _G.EOWLoaded then
		target = EOW:GetTarget(range)
	elseif _G.SDK and _G.SDK.Orbwalker then
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = GOS:GetTarget(range)
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
			return "Lasthit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_NONE] then
			return "None"
		end
	else
		return GOS.GetMode()
	end
end

local function EnableOrb(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif _G.SDK.Orbwalker then
		_G.SDK.Orbwalker:SetMovement(bool)
		_G.SDK.Orbwalker:SetAttack(bool)
	else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
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

local HKITEM = {
	[ITEM_1] = HK_ITEM_1,
	[ITEM_2] = HK_ITEM_2,
	[ITEM_3] = HK_ITEM_3,
	[ITEM_4] = HK_ITEM_4,
	[ITEM_5] = HK_ITEM_5,
	[ITEM_6] = HK_ITEM_6,
	[ITEM_7] = HK_ITEM_7,
}

local function NoPotion()
	for i = 0, myHero.buffCount do 
	local buff = myHero:GetBuff(i)
		if buff.type == 13 and Game.Timer() < buff.expireTime then 
			return false
		end
	end
	return true
end

local function isOnScreen(obj)
	return obj.pos:To2D().onScreen;
end

local function IsEvading()
    if ExtLibEvade and ExtLibEvade.Evading then return true end
	return false
end

local function IsAttacking()
	if myHero.attackData and myHero.attackData.target and myHero.attackData.state == STATE_WINDUP then return true end
	return false
end

local function IsRecalling()
	for K, Buff in pairs(GetBuffs(myHero)) do
		if Buff.name == "recall" and Buff.duration > 0 then
			return true
		end
	end
	return false
end
--- Engine ---

--- Ashe ---
class "Ashe"

local AsheVersion = "v1.00"

function Ashe:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Ashe:LoadSpells()
	Q = { Range = myHero.range, Delay = 0.25, cost = 50, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2a/Ranger%27s_Focus_2.png" }
	W = { Range = 1200, Delay = 0.25, cost = 50, Speed = 2000, Width = 20, Collision = true, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/5d/Volley.png" }
    E = { Range = 1200, Delay = 0.25, cost = 0, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e3/Hawkshot.png" }
	R = { Range = 25000, Delay = 0.25, cost = 100, Speed = 1600, Width = 125, Collision = false, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/28/Enchanted_Crystal_Arrow.png" }
end

function Ashe:LoadMenu()
	RomanovAshe = MenuElement({type = MENU, id = "RomanovAshe", name = "Monsters "..Version})
	--- Version ---
	RomanovAshe:MenuElement({name = "Ashe", drop = {AsheVersion}, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/15/Ashe_OriginalCircle.png"})
	--- Combo ---
	RomanovAshe:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	RomanovAshe.Combo:MenuElement({id = "Q", name = "Q", value = true, leftIcon = Q.icon})
	RomanovAshe.Combo:MenuElement({id = "W", name = "W", value = true, leftIcon = W.icon})
    RomanovAshe.Combo:MenuElement({id = "R", name = "R [?]", value = true, leftIcon = R.icon, tooltip = "Calculates possible damage after stun"})
    RomanovAshe.Combo:MenuElement({id = "Rrange", name = "Max distance to R", value = 2200, min = 100, max = 25000, step = 100})
    --- Clear ---
	RomanovAshe:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	RomanovAshe.Clear:MenuElement({id = "Key", name = "Enabled", key = string.byte("A"), toggle = true})
	RomanovAshe.Clear:MenuElement({id = "Q", name = "Q", value = true, leftIcon = Q.icon})
    RomanovAshe.Clear:MenuElement({id = "W", name = "W", value = true, leftIcon = W.icon})
    RomanovAshe.Clear:MenuElement({id = "Whit", name = "W min minions", value = 5, min = 1, max = 7})
    RomanovAshe.Clear:MenuElement({id = "Mana", name = "Mana percentage", value = 0, min = 0, max = 100})
    RomanovAshe.Clear:MenuElement({id = "Ignore", name = "Ignore mana check if have Blue", value = true})
	--- Harass ---
	RomanovAshe:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	RomanovAshe.Harass:MenuElement({id = "Key", name = "Enabled", key = string.byte("S"), toggle = true})
	RomanovAshe.Harass:MenuElement({id = "Q", name = "Q", value = true, leftIcon = Q.icon})
    RomanovAshe.Harass:MenuElement({id = "W", name = "W", value = true, leftIcon = W.icon})
    RomanovAshe.Harass:MenuElement({id = "AutoW", name = "W auto harass", value = true})
    RomanovAshe.Harass:MenuElement({id = "Mana", name = "Mana percentage", value = 0, min = 0, max = 100})
    RomanovAshe.Harass:MenuElement({id = "Ignore", name = "Ignore mana check if have Blue", value = true})
    --- Hawkshot ---
    RomanovAshe:MenuElement({type = MENU, id = "Hawkshot", name = "Hawkshot"})
    RomanovAshe.Hawkshot:MenuElement({id = "E", name = "E bush revealer", value = true, leftIcon = E.icon})
    RomanovAshe.Hawkshot:MenuElement({id = "Baron", name = "Send to Baron", key = string.byte("U")})
    RomanovAshe.Hawkshot:MenuElement({id = "Dragon", name = "Send to Dragon", key = string.byte("I")})
    --- Flee ---
    RomanovAshe:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    RomanovAshe.Flee:MenuElement({id = "W", name = "W", value = true, leftIcon = W.icon})
    RomanovAshe.Flee:MenuElement({id = "R", name = "R", value = true, leftIcon = R.icon})
    RomanovAshe.Flee:MenuElement({id = "HP", name = "Health percentage to R", value = 25, min = 0, max = 100})
    RomanovAshe.Flee:MenuElement({id = "Rrange", name = "Max distance to R", value = 700, min = 100, max = 25000, step = 100})
    --- Killsteal ---
    RomanovAshe:MenuElement({type = MENU, id = "Killsteal", name = "Killsteal"})
    RomanovAshe.Killsteal:MenuElement({id = "W", name = "W", value = true, leftIcon = W.icon})
    RomanovAshe.Killsteal:MenuElement({id = "R", name = "R", value = true, leftIcon = R.icon})
    RomanovAshe.Killsteal:MenuElement({id = "Rrange", name = "Max distance to R", value = 3000, min = 100, max = 25000, step = 100})
	--- Interrupter ---
    RomanovAshe:MenuElement({type = MENU, id = "Interrupter", name = "Interrupter"})
    RomanovAshe.Interrupter:MenuElement({id = "R", name = "R", value = true, leftIcon = R.icon})
    RomanovAshe.Interrupter:MenuElement({id = "Rrange", name = "Max distance to interrupt", value = 2000, min = 100, max = 25000, step = 100})
    RomanovAshe.Interrupter:MenuElement({type = MENU, id = "Whitelist", name = "Whitelist"})
    for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isEnemy then
			RomanovAshe.Interrupter.Whitelist:MenuElement({id = Hero.charName, name = Hero.charName, value = true, toggle = true})
		end
	end
	--- Antigapclose ---
    RomanovAshe:MenuElement({type = MENU, id = "Antigapclose", name = "Antigapclose"})
    RomanovAshe.Antigapclose:MenuElement({id = "R", name = "R", value = true, leftIcon = R.icon})
    RomanovAshe.Antigapclose:MenuElement({id = "Rrange", name = "Max antigapclose distance", value = 1500, min = 100, max = 25000, step = 100})
    RomanovAshe.Antigapclose:MenuElement({type = MENU, id = "Whitelist", name = "Whitelist"})
    for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isEnemy then
			RomanovAshe.Antigapclose.Whitelist:MenuElement({id = Hero.charName, name = Hero.charName, value = true, toggle = true})
		end
	end
	--- Draw ---
	RomanovAshe:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
	RomanovAshe.Draw:MenuElement({id = "W", name = "W range", value = true, leftIcon = W.icon})
	RomanovAshe.Draw:MenuElement({id = "CT", name = "Clear on/off", value = true})
	RomanovAshe.Draw:MenuElement({id = "HT", name = "Harass on/off", value = true})
end

function Ashe:Tick()
    if myHero.dead or Game.IsChatOpen() or IsRecalling() or IsEvading() or IsAttacking() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Clear" then
		self:Clear()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:Flee()
    end
    if RomanovAshe.Harass.AutoW:Value() then
        self:AutoW()
    end
    if RomanovAshe.Hawkshot.E:Value() and Ready(_E) then
        self:Hawkshot()
    end
    if RomanovAshe.Interrupter.R:Value() and Ready(_R) then
        self:UpdateInterrupterWhiteList()
        self:Interrupter()
    end
    if RomanovAshe.Antigapclose.R:Value() and Ready(_R) then
        self:UpdateAntigapcloseWhiteList()
        self:Antigapclose()
    end
        self:Killsteal()
        self:BaronDragon()
end

local _lastInterrupterWhiteListUpdate = Game.Timer()
local _whiteListUpdateFrequency = 1
local _interrupterWhiteList
function Ashe:UpdateInterrupterWhiteList()	
	if Game.Timer() - _lastInterrupterWhiteListUpdate < _whiteListUpdateFrequency then return end	
	_lastInterrupterWhiteListUpdate = Game.Timer()
	_interrupterWhiteList = {}
	for i  = 1,Game.HeroCount(i) do
		local enemy = Game.Hero(i)
		if RomanovAshe.Interrupter.Whitelist[enemy.charName] and RomanovAshe.Interrupter.Whitelist[enemy.charName]:Value() then
			_interrupterWhiteList[enemy.charName] = true
		end
	end
end

function Ashe:Interrupter()
	for i  = 1,Game.HeroCount(i) do
        local enemy = Game.Hero(i)
        if HPred:CanTarget(enemy) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, enemy, R.Range, R.Delay, R.Speed, R.Width, R.Collision, 2,_interrupterWhiteList)
            if hitChance and hitChance >= 4 and HPred:GetDistance(myHero.pos, aimPosition) <= RomanovAshe.Interrupter.Rrange:Value() then
                Control.CastSpell(HK_R, aimPosition)
            end
        end
    end
end

local _lastAntigapcloseWhiteListUpdate = Game.Timer()
local _antigapcloseWhiteList
function Ashe:UpdateAntigapcloseWhiteList()	
	if Game.Timer() - _lastAntigapcloseWhiteListUpdate < _whiteListUpdateFrequency then return end	
	_lastAntigapcloseWhiteListUpdate = Game.Timer()
	_antigapcloseWhiteList = {}
	for i  = 1,Game.HeroCount(i) do
		local enemy = Game.Hero(i)
		if RomanovAshe.Antigapclose.Whitelist[enemy.charName] and RomanovAshe.Antigapclose.Whitelist[enemy.charName]:Value() then
			_antigapcloseWhiteList[enemy.charName] = true
		end
	end
end

function Ashe:Antigapclose()
    for i  = 1,Game.HeroCount(i) do
        local enemy = Game.Hero(i)
        if HPred:CanTarget(enemy) and enemy.pathing.isDashing and GetDistance(enemy.pathing.endPos) < 300 then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, enemy, R.Range, R.Delay, R.Speed, R.Width, R.Collision, 2,_antigapcloseWhiteList)
            if hitChance and hitChance >= 2 and HPred:GetDistance(myHero.pos, aimPosition) <= RomanovAshe.Antigapclose.Rrange:Value() then
                Control.CastSpell(HK_R, aimPosition)
            end
        end
    end
end

local LastPositions = {}
function Ashe:Hawkshot()
    for i = 1, Game.HeroCount() do	
		local hero = Game.Hero(i)
		if not hero.dead and hero.visible and hero.isEnemy then
			LastPositions[hero.networkID] = {pos = hero.pos, posTo = hero.posTo, dir = hero.dir, time = Game.Timer() }
		end
	end	
	for i = 1, Game.HeroCount() do	
		local hero = Game.Hero(i)
		if not hero.dead and not hero.visible and hero.isEnemy and hero.distance < 1200 then
			local lastPosInfo = LastPositions[hero.networkID]
			if lastPosInfo and Game.Timer() - lastPosInfo.time < 3 then
				local inBush = false
				local Hawkshot
				for i = 1, 10 do
					local checkPos = lastPosInfo.pos + lastPosInfo.dir*20*i
					if GetDistance(checkPos) <= 1200 and MapPosition:inBush(checkPos) then
						Hawkshot = checkPos
						inBush = true
						break
					end
				end
				if inBush then
					Control.CastSpell(HK_E, Hawkshot)
					break
				end
			end
		end
	end
end

function Ashe:BaronDragon()
    if RomanovAshe.Hawkshot.Dragon:Value() then
        local mpos = Vector(9866.148438,0,4414.014160):ToMM()
		Control.SetCursorPos(mpos.x,mpos.y)
		Control.KeyDown(HK_E)
		Control.KeyUp(HK_E)
    end
    if RomanovAshe.Hawkshot.Baron:Value() then
        local mpos = Vector(5007.123535,0,10471.446289):ToMM()
		Control.SetCursorPos(mpos.x,mpos.y)
		Control.KeyDown(HK_E)
		Control.KeyUp(HK_E)
    end
end

function Ashe:Combo()
	local target = GetTarget(RomanovAshe.Combo.Rrange:Value())
    
    if target == nil then return end
	if RomanovAshe.Combo.R:Value() and Ready(_R) then
		if self:GetComboDamage(target) > target.health and myHero.mana > Q.cost + W.cost + R.cost then
			if HPred:CanTarget(target) then
                local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, R.Range, R.Delay, R.Speed, R.Width, R.Collision, nil)
                if hitChance and hitChance >= 3 and HPred:GetDistance(myHero.pos, aimPosition) <= RomanovAshe.Combo.Rrange:Value() then
                    if isOnScreen(target) then
                        Control.CastSpell(HK_R, aimPosition)
                    else
                        Control.CastSpell(HK_R, aimPosition:ToMM().x, aimPosition:ToMM().y)
                    end
                end
            end
		end
    end
	if RomanovAshe.Combo.Q:Value() and Ready(_Q) and GetDistance(target.pos) < myHero.range then
		Control.CastSpell(HK_Q)
    end
    if RomanovAshe.Combo.W:Value() and Ready(_W) and GetDistance(target.pos) < W.Range then
	    if HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, W.Range, W.Delay, W.Speed, W.Width, W.Collision, nil)
            if hitChance and hitChance >= 2 and HPred:GetDistance(myHero.pos, aimPosition) <= W.Range then
                Control.CastSpell(HK_W, aimPosition)
            end
        end
    end
end

function Ashe:AutoW()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
	local target = GetTarget(W.range)
    if RomanovAshe.Harass.Key:Value() == false then return end
	if PercentMP(myHero) < RomanovAshe.Harass.Mana:Value() and not (blue and RomanovAshe.Harass.Ignore:Value()) then return end

    if target == nil then return end
	if RomanovAshe.Harass.W:Value() and Ready(_W) and GetDistance(target.pos) < W.Range then
		if HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, W.Range, W.Delay, W.Speed, W.Width, W.Collision, nil)
            if hitChance and hitChance >= 2 and HPred:GetDistance(myHero.pos, aimPosition) <= W.Range then
                Control.CastSpell(HK_W, aimPosition)
            end
        end
    end
end

function Ashe:Harass()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
	local target = GetTarget(W.range)
    if RomanovAshe.Harass.Key:Value() == false then return end
	if PercentMP(myHero) < RomanovAshe.Harass.Mana:Value() and not (blue and RomanovAshe.Harass.Ignore:Value()) then return end

    if target == nil then return end
	if RomanovAshe.Harass.Q:Value() and Ready(_Q) and GetDistance(target.pos) < myHero.range then
		Control.CastSpell(HK_Q)
	end
	if RomanovAshe.Harass.W:Value() and Ready(_W) and GetDistance(target.pos) < W.Range then
		if HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, W.Range, W.Delay, W.Speed, W.Width, W.Collision, nil)
            if hitChance and hitChance >= 2 and HPred:GetDistance(myHero.pos, aimPosition) <= W.Range then
                Control.CastSpell(HK_W, aimPosition)
            end
        end
    end
end

function Ashe:Clear()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
    if RomanovAshe.Clear.Key:Value() == false then return end
    if PercentMP(myHero) < RomanovAshe.Clear.Mana:Value() and not (blue and RomanovAshe.Clear.Ignore:Value()) then return end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
		if minion and minion.team == 300 - myHero.team then
			if RomanovAshe.Clear.Q:Value() and Ready(_Q) then
                if GetDistance(minion.pos) < 600 then
                    Control.CastSpell(HK_Q)
                end
			end
			if RomanovAshe.Clear.W:Value() and Ready(_W) and MinionsAround(550,minion.pos) >= RomanovAshe.Clear.Whit:Value() then
                local pred = minion:GetPrediction(W.Speed, W.Delay)
                if GetDistance(pred) < W.Range then
                    Control.CastSpell(HK_W, pred)
                end
			end
		elseif minion and minion.team == 300 then
            if RomanovAshe.Clear.Q:Value() and Ready(_Q) then
                if GetDistance(minion.pos) < 600 then
                    Control.CastSpell(HK_Q)
                end
			end
			if RomanovAshe.Clear.W:Value() and Ready(_W) and GetDistance(minion.pos) < W.Range then
				local pred = minion:GetPrediction(W.Speed, W.Delay)
                if GetDistance(pred) < W.Range then
                    Control.CastSpell(HK_W, pred)
                end
			end
		end
	end
end

function Ashe:Flee()
	local target = GetTarget(W.Range)

    if target and RomanovAshe.Flee.W:Value() and Ready(_W) then
		if HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, W.Range, W.Delay, W.Speed, W.Width, W.Collision, nil)
            if hitChance and hitChance >= 2 and HPred:GetDistance(myHero.pos, aimPosition) <= W.Range then
                Control.CastSpell(HK_W, aimPosition)
            end
        end
    end
    if target and RomanovAshe.Flee.R:Value() and Ready(_R) and PercentHP(myHero) < RomanovAshe.Flee.HP:Value() then
		if HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, R.Range, R.Delay, R.Speed, R.Width, R.Collision, nil)
            if hitChance and hitChance >= 3 and HPred:GetDistance(myHero.pos, aimPosition) <= RomanovAshe.Flee.Rrange:Value() then
                if isOnScreen(target) then
                    Control.CastSpell(HK_R, aimPosition)
                else
                    Control.CastSpell(HK_R, aimPosition:ToMM().x, aimPosition:ToMM().y)
                end
            end
        end
    end
end

function Ashe:Killsteal()
	local target = GetTarget(RomanovAshe.Killsteal.Rrange:Value())
    if target == nil then return end
    
	if RomanovAshe.Killsteal.W:Value() and Ready(_W) then
		local Wdmg = CalcPhysicalDamage(myHero, target, (5 + 15 * myHero:GetSpellData(_W).level + myHero.totalDamage))
		if Wdmg > target.health then
			if HPred:CanTarget(target) then
                local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, W.Range, W.Delay, W.Speed, W.Width, W.Collision, nil)
                if hitChance and hitChance >= 2 and HPred:GetDistance(myHero.pos, aimPosition) <= W.Range then
                    Control.CastSpell(HK_W, aimPosition)
                end
            end
		end
    end
    if RomanovAshe.Killsteal.R:Value() and Ready(_R) then
		local Rdmg = CalcMagicalDamage(myHero, target, (200 * myHero:GetSpellData(_R).level + myHero.ap))
		if HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, R.Range, R.Delay, R.Speed, R.Width, R.Collision, nil)
            if hitChance and hitChance >= 3 and HPred:GetDistance(myHero.pos, aimPosition) <= RomanovAshe.Killsteal.Rrange:Value() then
                if isOnScreen(target) then
                    Control.CastSpell(HK_R, aimPosition)
                else
                    Control.CastSpell(HK_R, aimPosition:ToMM().x, aimPosition:ToMM().y)
                end
            end
        end
	end
end

function Ashe:GetComboDamage(unit)
    local Total = 0
    local Pdmg = CalcPhysicalDamage(myHero, unit, (1.1 * myHero.totalDamage + myHero.critChance)) * myHero.attackSpeed
    local Qdmg = CalcPhysicalDamage(myHero, unit, ((1 + 0.05 * myHero:GetSpellData(_Q).level) * myHero.totalDamage))
    local Wdmg = CalcPhysicalDamage(myHero, unit, (5 + 15 * myHero:GetSpellData(_W).level + myHero.totalDamage))
	local Rdmg = CalcMagicalDamage(myHero, unit, (200 * myHero:GetSpellData(_R).level + myHero.ap))
    if Ready(_Q) then
		Total = Total + Qdmg * 4
	end
    if Ready(_W) then
		Total = Total + Wdmg
	end
	if Ready(_R) then
		Total = Total + Rdmg
    end
    Total = Total + Pdmg * 3
	return Total
end

function Ashe:Draw()
	if RomanovAshe.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, 1200, 3,  Draw.Color(255,000, 075, 180)) end
	if RomanovAshe.Draw.CT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovAshe.Clear.Key:Value() then
			Draw.Text("Clear On", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear Off", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
	end
	if RomanovAshe.Draw.HT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovAshe.Harass.Key:Value() then
			Draw.Text("Harass On", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass Off", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
end
--- Ashe ---

Callback.Add("Load", function()
	if _G[myHero.charName] then
        _G[myHero.charName]()
	else return
	end
end)
