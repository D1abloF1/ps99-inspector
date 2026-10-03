-- PS99 Event · standalone Fluent hub. No Panda SDK, no embedded keys.
-- Run separately from the main hub. Automation is OFF by default.
local env:any=getgenv()
local old:any=env.PS99EventHub
if old and type(old.Shutdown)=="function"then old.Shutdown()end
local LP=game:GetService("Players").LocalPlayer
local RS=game:GetService("ReplicatedStorage")
local L:any=RS:WaitForChild("Library",15)
assert(L,"PS99 Library unavailable")
local loadModule:any=require
local Http=game:GetService("HttpService")
local M:any={Alive=true,Version="1.0-event",Started=os.clock(),Connections={},Owned={},Errors={},
    AutoBreak=false,AutoDrops=false,AntiAFK=false,DropBusy=false,DropDelay=.6,DropBatch=3,
    LuckyDelay=.8,OrbWait=6,OrbScope="Лучшая зона",OrbMovement="Телепорт",BreakScope="Все открытые",
    BreakStatus="Выключено",DropStatus="Выключен",AFKStatus="Выключен",Assigned=0,RemovedDrops=0,
    RemovedLucky=0,LuckGained=0,AFKAttempts=0,AFKObserved=0,NextBreak=0,NextDrop=0,NextAFK=0}
env.PS99EventHub=M
local Pets:any=loadModule(L.Client.PlayerPet)
local Network:any=loadModule(L.Client.Network)
local Map:any=loadModule(L.Client.MapCmds)
local Breakables:any=loadModule(L.Client.BreakableFrontend)
M.FarmAreaTP=true;M.FarmHits=0;M.FarmRequests=0;M.NextFarmMove=0
table.insert(M.Connections,Breakables.DamageDealt:Connect(function(b:any,_health:any,_damage:any,_pet:any,owner:any)
    if M.Alive and M.AutoBreak and owner==LP and b.parentID=="HatchWar"then
        M.FarmHits+=1;M.LastFarmHit=os.clock()
    end
end))
local function root():BasePart?
    local c=LP.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if h and h.Health>0 and r and r:IsA("BasePart")then return r end
    return nil
end
local createEvent=(function()
-- Verified against Hatch Wars client modules; no remote-name guesses.
return function(M:any, LP:Player, L:any, loadModule:any, Window:any)
    local E:any={AutoOrbs=false,AutoBoss=false,BossPending=false,BossStartNext=0,WasFighting=false,OrbStatus="Выключен",BossStatus="Выключен",
        AutoProgress=true,AutoUpgrades=false,UpgradePending=false,NextUpgrade=0,UpgradeStatus="Выключено",Priorities={},PriorityLoading=true,
        AutoPumpkin=false,PumpkinPending=false,NextPumpkin=0,PumpkinStatus="Выключена",PumpkinFed=0,PumpkinOpened=0,
        NextOrb=0,NextClick=0,NextStatus=0,Skipped=setmetatable({},{__mode="k"}),Teleports=0,Clicks=0,CircleHits=0}
    M.HatchEvent=E
    E.Http=game:GetService("HttpService")
    E.PriorityPath="PS99D1abloCloudAuth/event-priorities-"..tostring(LP.UserId)..".json"
    function E.Init()
        if E.Ready then return true end
        if os.clock()<(E.NextInit or 0)then return false end
        E.NextInit=os.clock()+10
        local ok,loaded=pcall(function()
            local module=L.Client:FindFirstChild("HatchWarCmds")
            if not module then error("Hatch Wars отсутствует в этой локации",0)end
            local data={HW=loadModule(module),Types=loadModule(L.Types.HatchWar),
                Input=loadModule(module.Boss.Input),GUI=loadModule(L.Client.GUI),
                Currency=loadModule(L.Client.CurrencyCmds),UpgradeCmds=loadModule(L.Client.EventUpgradeCmds)}
            if type(data.HW)~="table"or type(data.HW.Feature)~="function"or type(data.HW.Instance)~="function"
                or type(data.Types)~="table"or type(data.Types.UPGRADES)~="table"or type(data.Types.ZONES)~="table"
                or type(data.Input)~="table"or type(data.Input.PressCentre)~="function"
                or type(data.GUI)~="table"or type(data.GUI.HatchWarBoss)~="function"
                or type(data.Currency)~="table"or type(data.Currency.Get)~="function"
                or type(data.UpgradeCmds)~="table"or type(data.UpgradeCmds.GetTier)~="function"
                or type(data.UpgradeCmds.Purchase)~="function"then error("Неполные модули Hatch Wars",0)end
            return data
        end)
        if not ok then E.LastInitError=tostring(loaded);return false end
        -- Commit only a complete set: failed require must not leave a partial HW cache.
        for key,value in pairs(loaded)do E[key]=value end
        E.Ready=true;E.LastInitError=nil
        return true
    end
    function E.BestZone()
        local hud=E.HW.Feature("Hud");local zone=1
        for n=1,#E.Types.ZONES do if hud.Unlocked(n)then zone=n end end
        return zone
    end
    function E.CancelStart()
        if E.StartTask then pcall(task.cancel,E.StartTask);E.StartTask=nil end
        E.BossPending=false
    end
    function E.ProgressStep()
        if not E.AutoProgress or os.clock()<(E.NextProgress or 0)then return end
        E.NextProgress=os.clock()+.4
        if not E.Init()then return end
        local inst=E.HW.Instance()
        if not inst then E.ProgressInstance=nil;return end
        local best=E.BestZone()
        if E.ProgressInstance~=inst then
            E.ProgressInstance=inst;E.ProgressZone=best;return
        end
        if best<=(E.ProgressZone or best)then return end
        if E.PumpkinPending or E.HW.Feature("Boss").IsFighting()or E.HW.Feature("Boss").HudHidden or M.Farm or M.AutoRank then return end
        local c=LP.Character;local r=c and c:FindFirstChild("HumanoidRootPart")
        local h=c and c:FindFirstChildOfClass("Humanoid")
        local ground=inst.model:FindFirstChild("ZONE_GROUND")
        local target=ground and ground:FindFirstChild(tostring(best))
        if not r or not h or h.Health<=0 or not target or not target:IsA("BasePart")then return end
        r.CFrame=target.CFrame*CFrame.new(0,target.Size.Y/2+3,0)
        r.AssemblyLinearVelocity=Vector3.zero
        E.ProgressZone=best;E.OrbStatus="Новая зона: "..best
        E.NextOrb=os.clock()+1;E.BossStartNext=os.clock()+3
    end
    function E.LoadPriorities()
        if not E.Init()then return false end
        local defaults={OrbPower=1,OrbBank=2,OrbSpawn=3,OrbReach=4,RareHunter=5,ChainTime=6,PumpkinGrowth=7,PumpkinLoot=8}
        for name,id in pairs(E.Types.UPGRADES)do E.Priorities[id]=defaults[name]or 0 end
        local ok,data=pcall(function()
            if not isfile(E.PriorityPath)then return nil end
            local raw=readfile(E.PriorityPath);if #raw>8192 then return nil end
            return E.Http:JSONDecode(raw)
        end)
        if ok and type(data)=="table"and data.Version==1 and data.UserId==LP.UserId and type(data.Priorities)=="table"then
            for id in pairs(E.Priorities)do
                local p=data.Priorities[id]
                if type(p)=="number"and p==p and p>=0 and p<=99 and p%1==0 then E.Priorities[id]=p end
            end
        end
        local tracks=table.clone(E.HW.Feature("Upgrades").Tracks())
        table.sort(tracks,function(a,b)
            local pa,pb=E.Priorities[a._id]or 0,E.Priorities[b._id]or 0
            if pa==0 then pa=math.huge end;if pb==0 then pb=math.huge end
            if pa~=pb then return pa<pb end
            if (a.Order or 0)~=(b.Order or 0)then return (a.Order or 0)<(b.Order or 0)end
            return a._id<b._id
        end)
        E.PriorityOrder={};E.PriorityDirs={};local seen={}
        for _,dir in ipairs(tracks)do E.PriorityDirs[dir._id]=dir end
        if ok and type(data)=="table"and data.Version==1 and data.UserId==LP.UserId and type(data.Order)=="table"then
            for _,id in ipairs(data.Order)do
                if type(id)=="string"and E.PriorityDirs[id]and not seen[id]then
                    seen[id]=true;table.insert(E.PriorityOrder,id)
                end
            end
        end
        for _,dir in ipairs(tracks)do
            if not seen[dir._id]then table.insert(E.PriorityOrder,dir._id)end
        end
        E.ReindexPriorities()
        return true
    end
    function E.EnsurePriorities()
        if E.PrioritiesReady then return true end
        if os.clock()<(E.NextPriorities or 0)then return false end
        E.NextPriorities=os.clock()+10
        local ok,ready=pcall(E.LoadPriorities)
        E.PrioritiesReady=ok and ready==true
        if not ok then E.LastInitError=tostring(ready)end
        return E.PrioritiesReady
    end
    function E.ReindexPriorities()
        for index,id in ipairs(E.PriorityOrder)do
            if (E.Priorities[id]or 0)>0 then E.Priorities[id]=index end
        end
    end
    function E.RefreshPriorityUI()
        local lines={}
        for _,id in ipairs(E.PriorityOrder)do
            local dir=E.PriorityDirs[id]
            table.insert(lines,(id==E.SelectedUpgradeId and "➜ "or "    ")..dir.Name..((E.Priorities[id]or 0)==0 and " · отключён"or ""))
        end
        if E.PriorityCard then E.PriorityCard:SetDesc(table.concat(lines,"\n"))end
        if E.PriorityEnableButton then
            local enabled=(E.Priorities[E.SelectedUpgradeId]or 0)>0
            E.PriorityEnableButton:SetTitle(enabled and "Отключить выбранный буст"or "Включить выбранный буст")
        end
    end
    function E.MovePriority(delta:number)
        local index=table.find(E.PriorityOrder,E.SelectedUpgradeId)
        if not index then return end
        local target=index+delta
        if target<1 or target>#E.PriorityOrder then return end
        E.PriorityOrder[index],E.PriorityOrder[target]=E.PriorityOrder[target],E.PriorityOrder[index]
        E.ReindexPriorities();E.NextUpgrade=0;E.RefreshPriorityUI();E.SavePriorities()
    end
    function E.ToggleSelectedPriority()
        local id=E.SelectedUpgradeId
        local index=table.find(E.PriorityOrder,id)
        if not index then return end
        E.Priorities[id]=(E.Priorities[id]or 0)>0 and 0 or index
        E.ReindexPriorities();E.NextUpgrade=0;E.RefreshPriorityUI();E.SavePriorities()
    end
    function E.SavePriorities()
        if E.PriorityLoading then return end
        local ok=pcall(function()
            if type(makefolder)=="function"then makefolder("PS99D1abloCloudAuth")end
            writefile(E.PriorityPath,E.Http:JSONEncode({Version=1,UserId=LP.UserId,Priorities=E.Priorities,Order=E.PriorityOrder}))
        end)
        if not ok then E.UpgradeStatus="Не удалось сохранить приоритеты"end
    end
    function E.SelectUpgrade()
        local tracks=E.HW.Feature("Upgrades").Tracks()
        local selected=nil;local priority=math.huge
        for _,dir in ipairs(tracks)do
            local p=E.Priorities[dir._id]or 0
            if p>0 and not E.HW.Feature("Upgrades").IsMax(dir)then
                if p<priority or (p==priority and selected and (dir.Order or 0)<(selected.Order or 0))then
                    selected=dir;priority=p
                end
            end
        end
        return selected
    end
    function E.CancelUpgrade()
        if E.UpgradeTask then pcall(task.cancel,E.UpgradeTask);E.UpgradeTask=nil end
        E.UpgradePending=false
    end
    function E.UpgradeStep()
        if not E.AutoUpgrades then E.UpgradeStatus="Выключено";return end
        if E.PumpkinPending or E.UpgradePending or os.clock()<E.NextUpgrade then return end
        E.NextUpgrade=os.clock()+2
        if not E.Init()or not E.HW.Instance()then E.UpgradeStatus="Войди в Hatch Wars";return end
        if not E.EnsurePriorities()then E.UpgradeStatus="Ивентовые апгрейды недоступны в этой локации";return end
        if E.BossPending or E.HW.Feature("Boss").IsFighting()or E.HW.Feature("Boss").HudHidden then E.UpgradeStatus="Пауза: бой";return end
        local dir=E.SelectUpgrade()
        if not dir then E.UpgradeStatus="Все выбранные бусты максимальны / отключены";return end
        local tier=E.UpgradeCmds.GetTier(dir)
        local cost=E.HW.Feature("Upgrades").Cost(dir,tier+1)
        if cost:CountExact()<cost:GetAmount()then
            E.UpgradeStatus="Копим на "..dir.Name..": "..cost:CountExact().."/"..cost:GetAmount();return
        end
        local inst=E.HW.Instance()
        E.UpgradePending=true;E.UpgradeStatus="Покупаем "..dir.Name.." · уровень "..(tier+1)
        E.UpgradeTask=task.spawn(function()
            local ok,result=pcall(function()
                if not M.Alive or not E.AutoUpgrades or E.HW.Instance()~=inst then return false end
                if E.SelectUpgrade()~=dir or E.UpgradeCmds.GetTier(dir)~=tier
                    or not E.HW.Feature("Upgrades").CanAfford(dir)then return false end
                return E.UpgradeCmds.Purchase(dir)
            end)
            E.UpgradePending=false;E.UpgradeTask=nil
            E.NextUpgrade=os.clock()+(ok and result and 3 or 15)
            if M.Alive and E.AutoUpgrades then
                E.UpgradeStatus=ok and result and ("Куплено: "..dir.Name.." · уровень "..(tier+1))or "Покупка отклонена · повтор через 15 с"
            end
        end)
    end
    function E.PumpkinInit()
        if E.PumpkinUtil then return true end
        if not E.Init()then return false end
        E.PumpkinUtil=loadModule(L.Util.HatchWarPumpkin);E.Items=loadModule(L.Items)
        return true
    end
    function E.BuildPumpkinPlan(spare:any,state:any)
        local plan={};local total=0;local remaining=state.Cap-state.Points
        if remaining<=0 or type(spare)~="table"then return plan,total end
        local growth=E.PumpkinUtil.Growth(LP);local candidates={}
        local strongest=-math.huge;local keepUID=nil;local alreadyKept=false
        for uid,amount in pairs(spare)do
            if type(uid)=="string"and type(amount)=="number"and amount==amount and amount>=0 and amount<math.huge then
                local pet=E.Items.Pet:Get(uid)
                if pet and pet:GetExclusiveLevel()==0 then
                    local points=E.PumpkinUtil.UnitPoints(pet,growth)
                    local owned=math.floor(pet:GetAmount())
                    local count=math.floor(math.min(amount,owned))
                    if owned>0 and type(points)=="number"and points>0 and points<math.huge then
                        local protected=pet:IsLocked()or count<owned
                        if points>strongest then
                            strongest=points;keepUID=uid;alreadyKept=protected
                        elseif points==strongest then
                            alreadyKept=alreadyKept or protected
                            if uid<keepUID then keepUID=uid end
                        end
                        if not pet:IsLocked()and count>0 then
                            table.insert(candidates,{UID=uid,Count=count,Points=points})
                        end
                    end
                end
            end
        end
        -- Spare already excludes the game's protected copies. If it reserves none,
        -- retain one strongest copy ourselves; transferred pets need no hatch attribute.
        if not alreadyKept and keepUID then
            for _,pet in ipairs(candidates)do if pet.UID==keepUID then pet.Count=math.max(0,pet.Count-1)end end
        end
        table.sort(candidates,function(a,b)
            if a.Points~=b.Points then return a.Points<b.Points end
            return a.UID<b.UID
        end)
        for _,pet in ipairs(candidates)do
            local count=math.min(pet.Count,math.ceil(remaining/pet.Points),128-total)
            if count>0 then plan[pet.UID]=count;total+=count;remaining-=count*pet.Points end
            if remaining<=0 or total>=128 then break end
        end
        return plan,total
    end
    function E.CancelPumpkin()
        if E.PumpkinTask then pcall(task.cancel,E.PumpkinTask);E.PumpkinTask=nil end
        E.PumpkinPending=false
    end
    function E.PumpkinCanAct(inst:any)
        local boss=E.HW.Feature("Boss")
        return M.Alive and E.AutoPumpkin and E.HW.Instance()==inst and not E.BossPending
            and not boss.IsFighting()and not boss.HudHidden and not M.Farm and not M.AutoRank
    end
    function E.PumpkinDelay()
        local ok,cooldown=pcall(E.PumpkinUtil.Cooldown)
        if not ok or type(cooldown)~="number"or cooldown~=cooldown or cooldown<0 or cooldown==math.huge then cooldown=1 end
        return math.max(1.25,cooldown+.25)
    end
    function E.PumpkinStep()
        if not E.AutoPumpkin then E.PumpkinStatus="Выключена";return end
        if E.PumpkinPending or E.UpgradePending or os.clock()<E.NextPumpkin then return end
        E.NextPumpkin=os.clock()+3
        if not E.PumpkinInit()or not E.HW.Instance()then E.PumpkinStatus="Войди в Hatch Wars";return end
        if not E.PumpkinUtil.Enabled()then E.PumpkinStatus="Тыква отключена игрой";return end
        local inst=E.HW.Instance()
        if not E.PumpkinCanAct(inst)then E.PumpkinStatus="Пауза: бой / фарм";return end
        local pumpkin=E.HW.Feature("Pumpkin");local state=pumpkin.GetState()
        if not state or type(state.Points)~="number"or type(state.Cap)~="number"or state.Cap<=0 then E.PumpkinStatus="Ожидание состояния";return end
        if E.PumpkinAwait and E.PumpkinAwait.Points==state.Points and E.PumpkinAwait.Cap==state.Cap and E.PumpkinAwait.Opens==state.Opens then
            E.PumpkinStatus="Ожидание подтверждения состояния";return
        end
        E.PumpkinAwait=nil
        E.PumpkinPending=true;E.PumpkinStatus="Проверка запасных слабых питомцев…"
        E.PumpkinTask=task.spawn(function()
            local acted=false
            local ok,result=pcall(function()
                local prefix=E.Types.NET_PREFIX.Pumpkin
                local count=0;local plan={}
                if state.Points<state.Cap then
                    local spare=inst:InvokeCustom(prefix.."Spare")
                    if not E.PumpkinCanAct(inst)then return false end
                    state=pumpkin.GetState()
                    if not state then return false end
                    plan,count=E.BuildPumpkinPlan(spare,state)
                    if state.Points<state.Cap and count==0 then E.PumpkinStatus="Нет запасных слабых питомцев · ждём новые";return true end
                end
                local c=LP.Character;local r=c and c:FindFirstChild("HumanoidRootPart")
                local h=c and c:FindFirstChildOfClass("Humanoid")
                local debris=workspace:FindFirstChild("__DEBRIS")
                local anchor=debris and type(pumpkin.Anchor)=="string"and debris:FindFirstChild(pumpkin.Anchor)
                local interact=inst.model:FindFirstChild("INTERACT");local stalk=interact and interact:FindFirstChild("Stalk")
                if not anchor and stalk and type(pumpkin.Anchor)=="string"then anchor=stalk:FindFirstChild(pumpkin.Anchor,true)end
                if not r or not h or h.Health<=0 or not anchor or not anchor:IsA("BasePart")then
                    E.PumpkinStatus="Ожидание персонажа / площадки тыквы";return true
                end
                if not E.PumpkinCanAct(inst)then return false end
                local top=debris and debris:FindFirstChild("HatchWarPumpkinTop")
                local target=anchor
                if pumpkin.Mode=="stalk"and top and top:IsA("BasePart")then target=top end
                r.CFrame=target.CFrame*CFrame.new(0,target.Size.Y/2+3,0);r.AssemblyLinearVelocity=Vector3.zero
                task.wait(.6)
                if not E.PumpkinCanAct(inst)or not r.Parent or (r.Position-anchor.Position).Magnitude>E.PumpkinUtil.Reach()then return false end
                state=pumpkin.GetState();if not state then return false end
                local operation="Open"
                if state.Points<state.Cap then
                    local spare=inst:InvokeCustom(prefix.."Spare")
                    if not E.PumpkinCanAct(inst)then return false end
                    state=pumpkin.GetState();if not state then return false end
                    if state.Points<state.Cap then
                        plan,count=E.BuildPumpkinPlan(spare,state)
                        if count==0 then E.PumpkinStatus="Нет запасных слабых питомцев · ждём новые";return true end
                        operation="Feed"
                    end
                end
                if not E.PumpkinCanAct(inst)then return false end
                local previous={Points=state.Points,Cap=state.Cap,Opens=state.Opens}
                E.PumpkinStatus=operation=="Feed"and ("Заполнение: "..count.." слабых питомцев")or "Открываем полную тыкву…"
                local accepted,reason
                if operation=="Feed"then accepted,reason=inst:InvokeCustom(prefix..operation,plan)
                else accepted,reason=inst:InvokeCustom(prefix..operation)end
                if not accepted then E.PumpkinStatus="Игра отклонила действие: "..tostring(reason);return false end
                acted=true
                E.PumpkinAwait=previous
                if operation=="Feed"then E.PumpkinFed+=count;E.PumpkinStatus="Добавлено питомцев: "..count
                else E.PumpkinOpened+=1;E.PumpkinStatus="Тыква открыта · награды выдаёт игра"end
                return true
            end)
            E.PumpkinPending=false;E.PumpkinTask=nil
            E.NextPumpkin=os.clock()+(ok and result and (acted and E.PumpkinDelay()or 3)or 15)
            if not ok then E.PumpkinStatus="Ошибка тыквы: "..tostring(result)end
        end)
    end
    function E.Stop()
        E.AutoOrbs=false;E.AutoBoss=false;E.AutoUpgrades=false;E.AutoProgress=false
        E.AutoPumpkin=false;E.CancelStart();E.CancelUpgrade();E.CancelPumpkin()
    end
    function E.ZoneAt(inst:any,pos:Vector3)
        local ground=inst.model:FindFirstChild("ZONE_GROUND")
        if not ground then return nil end
        for _,part in ipairs(ground:GetChildren())do
            if part:IsA("BasePart")then
                local p=part.CFrame:PointToObjectSpace(pos)
                if math.abs(p.X)<=part.Size.X/2 and math.abs(p.Z)<=part.Size.Z/2 then return tonumber(part.Name)end
            end
        end
        return nil
    end
    function E.OrbStep()
        if not E.AutoOrbs then E.OrbStatus="Выключен";return end
        if os.clock()<E.NextOrb then return end
        E.NextOrb=os.clock()+.8
        if not E.Init()then E.OrbStatus="Ивент недоступен";return end
        local inst=E.HW.Instance()
        if not inst then E.OrbStatus="Войди в Hatch Wars";return end
        if E.PumpkinPending then E.OrbStatus="Пауза: гигантская тыква";return end
        if E.BossPending or E.HW.Feature("Boss").IsFighting()or E.HW.Feature("Boss").HudHidden then E.OrbStatus="Пауза: бой с боссом";return end
        if M.Farm or M.AutoRank then E.OrbStatus="Выключи Auto Farm / Auto Rank";return end
        local c=LP.Character;local r=c and c:FindFirstChild("HumanoidRootPart")
        local h=c and c:FindFirstChildOfClass("Humanoid")
        if not r or not h or h.Health<=0 then E.OrbStatus="Ожидание персонажа";return end
        local bank,cap=E.HW.Feature("Orbs").Bank()
        if bank>=cap then E.OrbStatus="Банк полный: "..bank.."/"..cap;return end
        local zone=E.BestZone()
        local debris=workspace:FindFirstChild("__DEBRIS")
        local folder=debris and debris:FindFirstChild("HatchWarOrbs")
        local target:Model?=nil;local nearest=math.huge
        if folder then for _,orb in ipairs(folder:GetChildren())do
            if orb:IsA("Model")and (E.Skipped[orb]or 0)<=os.clock()then
                local pos=orb:GetPivot().Position
                -- Skip elevated stalk/climbing orbs: the server checks their climb sequence.
                if E.ZoneAt(inst,pos)==zone then
                    local ground=inst.model.ZONE_GROUND:FindFirstChild(tostring(zone))
                    local floorY=ground and ground.Position.Y+ground.Size.Y/2
                    if floorY and pos.Y<floorY+10 and pos.Y>floorY-2 then
                        local d=(pos-r.Position).Magnitude
                        if d<nearest then target=orb;nearest=d end
                    end
                end
            end
        end end
        if not target then E.OrbStatus="Нет доступных орбов · зона "..zone;return end
        local pos=target:GetPivot().Position
        E.Skipped[target]=os.clock()+8
        r.CFrame=CFrame.new(pos+Vector3.new(0,1,0))*r.CFrame.Rotation
        r.AssemblyLinearVelocity=Vector3.zero
        E.Teleports+=1
        E.OrbStatus="Сбор · зона "..zone.." · банк "..bank.."/"..cap
        -- The game's proximity collector performs the claim after character replication.
    end
    function E.BossStep()
        if not E.AutoBoss then E.BossStatus="Выключен";return end
        if os.clock()<E.NextClick then return end
        E.NextClick=os.clock()+.17
        if not E.Init()or not E.HW.Instance()then E.BossStatus="Войди в Hatch Wars";return end
        local boss=E.HW.Feature("Boss")
        if not boss.IsFighting()then
            if E.PumpkinPending then E.BossStatus="Пауза: гигантская тыква";return end
            if E.WasFighting then E.WasFighting=false;E.BossStartNext=os.clock()+8 end
            if E.BossPending then E.BossStatus="Ожидание старта боя…";return end
            if os.clock()<E.BossStartNext then return end
            E.BossStartNext=os.clock()+2
            local inst=E.HW.Instance();local zone=E.BestZone()
            local required,luck=boss.Recommended(zone)
            local balance=E.Currency.Get(E.Types.COIN)
            if balance<required then
                E.BossStatus="Ожидание монет: "..tostring(balance).."/"..tostring(required);return
            end
            if boss.PlayerLuck(zone)<luck then
                E.BossStatus="Ожидание удачи: "..math.floor(boss.PlayerLuck(zone)).."/"..tostring(luck);return
            end
            if M.Farm or M.AutoRank then E.BossStatus="Выключи Auto Farm / Auto Rank";return end
            local character=LP.Character;local r=character and character:FindFirstChild("HumanoidRootPart")
            local h=character and character:FindFirstChildOfClass("Humanoid")
            if not r or not h or h.Health<=0 then E.BossStatus="Ожидание персонажа";return end
            local interact=inst.model:FindFirstChild("INTERACT")
            local bosses=interact and interact:FindFirstChild("Bosses")
            local target=bosses and bosses:FindFirstChild("Boss"..zone)
            if not target or not target:IsA("Model")then E.BossStatus="Ожидание модели босса";return end
            E.BossPending=true;E.BossStatus="Запуск босса · зона "..zone
            E.StartTask=task.spawn(function()
                -- The start request may yield; keep clicks and the UI worker responsive.
                local ok,result=pcall(function()
                    if not M.Alive or not E.AutoBoss or E.HW.Instance()~=inst then return false end
                    local currentCoins,currentLuck=boss.Recommended(zone)
                    if E.Currency.Get(E.Types.COIN)<currentCoins or boss.PlayerLuck(zone)<currentLuck then return false end
                    r.CFrame=target:GetPivot()*CFrame.new(0,3,6)
                    r.AssemblyLinearVelocity=Vector3.zero
                    task.wait(.6)
                    if not M.Alive or not E.AutoBoss or E.HW.Instance()~=inst then return false end
                    -- Recheck immediately before asking the game to start (no underfunded dialog).
                    if E.Currency.Get(E.Types.COIN)<currentCoins or boss.PlayerLuck(zone)<currentLuck then return false end
                    return boss.RequestFight(zone)
                end)
                E.BossPending=false;E.StartTask=nil
                E.BossStartNext=os.clock()+(ok and result and 8 or 20)
                if M.Alive and E.AutoBoss then
                    E.BossStatus=ok and result and "Бой запущен"or "Старт отклонён · повтор через 20 с"
                end
            end)
            return
        end
        E.WasFighting=true
        local gui=E.GUI.HatchWarBoss()
        if not gui or not gui.Enabled then return end
        local circle=gui:FindFirstChild("LiveCircle")
        if circle and circle:IsA("GuiButton")and circle.Visible and circle.Active then
            -- Invoke the game's real circle callback; firesignal is a no-op in Real.
            for _,connection in ipairs(getconnections(circle.Activated))do
                if connection.Enabled and type(connection.Function)=="function"then
                    local ok=pcall(connection.Function)
                    if ok then E.CircleHits+=1;E.BossStatus="Попаданий по целям: "..E.CircleHits;return end
                end
            end
        end
        if E.Input.PressCentre()then E.Clicks+=1 end
        E.BossStatus="Клики: "..E.Clicks.." · цели: "..E.CircleHits
    end
    function E.Status()
        if not E.Init()then return "Event недоступен в этой локации / версии игры. Остальные вкладки работают.\n"..tostring(E.LastInitError or "Ожидание модулей"):sub(1,220)end
        if not E.HW.Instance()then return "Войди в Hatch Wars"end
        local z=E.BestZone();local boss=E.HW.Feature("Boss")
        local coins,luck=boss.Recommended(z);local bank,cap=E.HW.Feature("Orbs").Bank()
        return string.format("Зона %d · %s\nОрбы: %s/%s · удача: %.0f / %.0f · шанс: %.1f%%\nМонет на бой: %s\nОрбы: %s\nБосс: %s",
            z,E.Types.ZONES[z].Name or E.Types.ZONES[z].DisplayName or E.Types.ZONES[z].Egg,
            tostring(bank),tostring(cap),boss.PlayerLuck(z),luck,boss.WinChance(z)*100,tostring(coins),E.OrbStatus,E.BossStatus).."\nАпгрейды: "..E.UpgradeStatus.."\nТыква: "..E.PumpkinStatus
    end
    function E.Step()
        local ok,err=pcall(function()E.ProgressStep();E.PumpkinStep();E.OrbStep();E.BossStep();E.UpgradeStep()end)
        if not ok then E.OrbStatus="Ошибка: "..tostring(err);E.NextOrb=os.clock()+5 end
        if E.Card and os.clock()>=E.NextStatus then
            E.NextStatus=os.clock()+1.5
            local good,status=pcall(E.Status)
            if good then E.Card:SetDesc(status)end
        end
    end
    return E
end


end)()
local E:any=createEvent(M,LP,L,loadModule,nil)
E.AutoProgress=false
-- Reuse existing priority format, but never read authentication files.
E.PriorityLoading=false
M.Event=E
local function blocked():boolean
    if not M.Alive or not root()then return true end
    local main:any=env.PS99Starter
    if main and main.Alive and (main.Farm or main.AutoRank or (main.HatchEvent and
        (main.HatchEvent.AutoOrbs or main.HatchEvent.AutoBoss or main.HatchEvent.AutoPumpkin)))then
        M.Conflict="Выключи автоматику основного хаба"
        return true
    end
    M.Conflict=nil
    if not E.Init()or not E.HW.Instance()then return true end
    local boss=E.HW.Feature("Boss")
    return E.BossPending or boss.IsFighting()or boss.HudHidden or E.PumpkinPending
end
local function allowedZone(inst:any,pos:Vector3,scope:string):boolean
    local zone=E.ZoneAt(inst,pos)
    if not zone or not E.HW.Feature("Hud").Unlocked(zone)then return false end
    if scope=="Все открытые"then return true end
    if scope=="Текущая зона"then
        local r=root();return r~=nil and zone==E.ZoneAt(inst,r.Position)
    end
    return zone==E.BestZone()
end
function M.ClearHover()
    M.HoverTarget=nil
    if M.HoverModule and M.HoverModule.ComputeMoveDirection==M.HoverHook then
        M.HoverModule.ComputeMoveDirection=M.HoverOriginal
    end
    M.HoverModule=nil;M.HoverOriginal=nil;M.HoverHook=nil
end
function M.EnsureHover():boolean
    if M.HoverModule then return true end
    local found=LP.PlayerScripts:FindFirstChild("HoverboardInstance",true)
    if not found then E.OrbStatus="Модуль ховерборда недоступен";return false end
    local ok,module=pcall(loadModule,found)
    if not ok or type(module)~="table"or type(module.ComputeMoveDirection)~="function"then return false end
    local original=module.ComputeMoveDirection
    local hook=function(self:any)
        if M.Alive and E.AutoOrbs and M.OrbMovement=="Ховерборд"and M.HoverTarget and self._isLocal then
            local r=self._humanoidRootPart
            if r and r.Parent then
                local delta=M.HoverTarget-r.Position;local flat=Vector3.new(delta.X,0,delta.Z)
                return flat.Magnitude>1 and flat.Unit or Vector3.zero
            end
        end
        return original(self)
    end
    M.HoverModule=module;M.HoverOriginal=original;M.HoverHook=hook
    module.ComputeMoveDirection=hook
    return true
end
function M.ClearLucky()
    E.OrbTarget=nil;M.HoverTarget=nil
end
function E.OrbStep()
    if not E.AutoOrbs then E.OrbStatus="Выключен";M.ClearLucky();return end
    if os.clock()<E.NextOrb then return end
    E.NextOrb=os.clock()+math.max(.15,M.LuckyDelay)
    if blocked()or M.DropBusy then E.OrbStatus=M.Conflict or "Пауза: бой / тыква / персонаж";M.ClearLucky();return end
    local inst=E.HW.Instance();local r=root();if not r then return end
    local bank,cap=E.HW.Feature("Orbs").Bank()
    if M.PreviousBank and M.PreviousInstance==inst and bank>M.PreviousBank then M.LuckGained+=bank-M.PreviousBank end
    M.PreviousBank=bank;M.PreviousInstance=inst
    if bank>=cap then E.OrbStatus="Банк полный: "..bank.."/"..cap;M.ClearLucky();return end
    if E.OrbTarget then
        if not E.OrbTarget.Parent then M.RemovedLucky+=1;M.ClearLucky()
        elseif os.clock()>E.OrbDeadline then
            E.Skipped[E.OrbTarget]=os.clock()+15;M.ClearLucky()
        else
            E.OrbStatus="Ожидание подбора · банк "..bank.."/"..cap
            if M.OrbMovement=="Ховерборд"then M.HoverTarget=E.OrbTarget:GetPivot().Position end
            return
        end
    end
    local debris=workspace:FindFirstChild("__DEBRIS")
    local folder=debris and debris:FindFirstChild("HatchWarOrbs")
    local target:Model?=nil;local nearest=math.huge
    if folder then for _,orb in ipairs(folder:GetChildren())do
        if orb:IsA("Model")and (E.Skipped[orb]or 0)<=os.clock()then
            local pos=orb:GetPivot().Position;local zone=E.ZoneAt(inst,pos)
            local ground=zone and inst.model.ZONE_GROUND:FindFirstChild(tostring(zone))
            local floorY=ground and ground.Position.Y+ground.Size.Y/2
            if floorY and pos.Y<floorY+10 and pos.Y>floorY-2 and allowedZone(inst,pos,M.OrbScope)then
                local distance=(pos-r.Position).Magnitude
                if distance<nearest then target=orb;nearest=distance end
            end
        end
    end end
    if not target then E.OrbStatus="Нет доступных наземных орбов";M.HoverTarget=nil;return end
    if M.OrbMovement=="Ховерборд"then
        if not LP:GetAttribute("UsingHoverboard")then E.OrbStatus="Сначала включи ховерборд";M.HoverTarget=nil;return end
        if not M.EnsureHover()then return end
        M.HoverTarget=target:GetPivot().Position
    else
        M.ClearHover()
        r.CFrame=CFrame.new(target:GetPivot().Position+Vector3.new(0,1,0))*r.CFrame.Rotation
        r.AssemblyLinearVelocity=Vector3.zero;E.Teleports+=1
    end
    E.OrbTarget=target;E.OrbDeadline=os.clock()+M.OrbWait
    E.OrbStatus="Сбор: "..M.OrbMovement.." · банк "..bank.."/"..cap
end
function M.ReleasePets()
    for pet,record in pairs(M.Owned)do
        pcall(function()
            if not pet.destroyed and pet:GetTarget()==record.Assigned then
                if record.Previous and record.Previous.Parent then pet:SetTarget(record.Previous)
                else pet:ClearTarget()end
            end
        end)
    end
    table.clear(M.Owned)
end
function M.BreakStep()
    if not M.AutoBreak then M.BreakStatus="Выключено";return end
    if os.clock()<M.NextBreak then return end
    M.NextBreak=os.clock()+.8
    if blocked()then M.ReleasePets();M.BreakStatus=M.Conflict or "Пауза: бой / тыква";return end
    if M.DropBusy or E.OrbTarget then M.BreakStatus="Пауза движения: подбор орбов";return end
    local inst=E.HW.Instance();local r=root();if not r then return end
    local things=workspace:FindFirstChild("__THINGS")
    local folder=things and things:FindFirstChild("Breakables");local targets={}
    if folder then for _,v in ipairs(folder:GetChildren())do
        if v:IsA("Model")and v:GetAttribute("ParentID")=="HatchWar"and
            allowedZone(inst,v:GetPivot().Position,M.BreakScope)then table.insert(targets,v)end
    end end
    table.sort(targets,function(a,b)return (a:GetPivot().Position-r.Position).Magnitude<(b:GetPivot().Position-r.Position).Magnitude end)
    if #targets==0 then M.ReleasePets();M.BreakStatus="Нет брейкаблов в выбранных зонах";return end
    -- Verified: requests from the pumpkin platform do no damage. Enter a real break area.
    local part=Map.GetCurrentBreakZonePart()
    local nearby={}
    if part and Map.IsInDottedBox()then
        for _,target in ipairs(targets)do
            if Map.IsPositionInBreakZone(part,target:GetPivot().Position)then table.insert(nearby,target)end
        end
    end
    if #nearby==0 then
        M.ReleasePets()
        if not M.FarmAreaTP then M.BreakStatus="Войди в пунктирную зону фарма или включи TP в зону";return end
        if os.clock()<M.NextFarmMove then M.BreakStatus="Ожидание входа в зону фарма";return end
        local pos=targets[1]:GetPivot().Position
        r.CFrame=CFrame.new(pos+Vector3.new(0,4,0))*r.CFrame.Rotation;r.AssemblyLinearVelocity=Vector3.zero
        M.NextFarmMove=os.clock()+3;M.NextBreak=os.clock()+1;E.Teleports+=1
        M.BreakStatus="Входим в зону фарма · ожидание подтверждения";return
    end
    if M.BreakScope~="Все открытые"then targets=nearby end
    local batch={};local n=0
    for _,pet in pairs(Pets.GetByPlayer(LP))do
        if not pet.destroyed and pet.owner==LP then
            n+=1
            local current=pet:GetTarget()
            local target=table.find(targets,current)and current or targets[(n-1)%#targets+1]
            if current~=target then
                if not M.Owned[pet]then M.Owned[pet]={Previous=current}end
                pet:SetTarget(target);M.Owned[pet].Assigned=target;M.Assigned+=1
            end
            local uid=target:GetAttribute("BreakableUID")
            if uid then batch[pet.euid]=uid end
        end
    end
    if next(batch)then Network.Fire("Breakables_JoinPetBulk",batch);M.FarmRequests+=1 end
    M.BreakStatus="Своих питомцев: "..n.." · целей: "..#targets.." · подтверждённых ударов: "..M.FarmHits
    if M.FarmRequests>5 and (not M.LastFarmHit or os.clock()-M.LastFarmHit>8)then
        M.BreakStatus..="\nИгра пока не подтверждает урон"
    end
end
function M.DropStep()
    if not M.AutoDrops or M.DropBusy or os.clock()<M.NextDrop then return end
    M.NextDrop=os.clock()+1
    if blocked()or E.OrbTarget then M.DropStatus=M.Conflict or "Пауза: другая задача";return end
    M.DropBusy=true
    M.DropTask=task.spawn(function()
        local ok,err=pcall(function()
            for _=1,M.DropBatch do
                if not M.Alive or not M.AutoDrops or blocked()then break end
                local r=root();if not r then break end
                local inst=E.HW.Instance();local things=workspace:FindFirstChild("__THINGS")
                local folder=things and things:FindFirstChild("Orbs")
                local target:Instance?=nil;local nearest=math.huge
                if folder then for _,orb in ipairs(folder:GetChildren())do
                    if (orb:IsA("BasePart")or orb:IsA("Model"))and (M.DropSkipped[orb]or 0)<=os.clock()then
                        local pos=orb:IsA("BasePart")and orb.Position or (orb::Model):GetPivot().Position
                        if allowedZone(inst,pos,M.OrbScope)then
                            local distance=(pos-r.Position).Magnitude
                            if distance<nearest then target=orb;nearest=distance end
                        end
                    end
                end end
                if not target then M.DropStatus="Нет выпавших орбов";break end
                local pos=target:IsA("BasePart")and target.Position or (target::Model):GetPivot().Position
                M.DropSkipped[target]=os.clock()+15
                r.CFrame=CFrame.new(pos+Vector3.new(0,1,0))*r.CFrame.Rotation
                r.AssemblyLinearVelocity=Vector3.zero;E.Teleports+=1
                M.DropStatus="Подбираем выпавшие орбы…"
                task.wait(math.max(.25,M.DropDelay))
                if not target.Parent then M.RemovedDrops+=1 end
            end
        end)
        if not ok then M.DropStatus="Ошибка: "..tostring(err);M.NextDrop=os.clock()+5 end
        M.DropBusy=false;M.DropTask=nil
    end)
end
M.DropSkipped=setmetatable({},{__mode="k"})
function M.CancelDrops()
    if M.DropTask then pcall(task.cancel,M.DropTask);M.DropTask=nil end
    M.DropBusy=false
end
function M.AFKPulse()
    if not M.Alive or not M.AntiAFK or M.AFKBusy then return end
    M.AFKBusy=true;M.NextAFK=os.clock()+120;M.AFKAttempts+=1
    M.AFKTask=task.spawn(function()
        if type(setthreadidentity)=="function"then setthreadidentity(8)end
        local before=M.LastInput or 0;local vu=game:GetService("VirtualUser")
        local camera=workspace.CurrentCamera
        local virtualOk,virtualErr=pcall(function()
            vu:CaptureController()
            vu:Button2Down(Vector2.zero,camera and camera.CFrame or CFrame.identity)
            task.wait(.1)
            vu:Button2Up(Vector2.zero,camera and camera.CFrame or CFrame.identity)
            vu:ClickButton2(Vector2.zero)
        end)
        local keyOk=false
        if not E.BossPending and not (E.Ready and E.HW.Feature("Boss").IsFighting())then
            keyOk=pcall(function()
                local input=game:GetService("VirtualInputManager")
                input:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
                task.wait(.08)
                input:SendKeyEvent(false,Enum.KeyCode.Space,false,game)
            end)
        end
        local focused=type(isrbxactive)=="function"and isrbxactive()
        if focused and type(mousemoverel)=="function"then
            mousemoverel(1,0);task.wait(.1);mousemoverel(-1,0)
        end
        task.wait(.2)
        if M.Alive and M.AntiAFK then
            if (M.LastInput or 0)>before then
                M.AFKObserved+=1;M.AFKStatus="Roblox увидел ввод · проверок: "..M.AFKObserved
            elseif virtualOk or keyOk then
                M.AFKStatus=focused and "Вызовы выполнены; событие ввода не подтверждено"or "Фоновый VirtualUser; сброс таймера не подтверждён"
            else M.AFKStatus="Ошибка VirtualUser: "..tostring(virtualErr)end
        end
        M.AFKBusy=false;M.AFKTask=nil
    end)
end
function M.SetAFK(value:boolean)
    M.AntiAFK=value
    if M.IdleConnection then M.IdleConnection:Disconnect();M.IdleConnection=nil end
    if M.AFKTask then pcall(task.cancel,M.AFKTask);M.AFKTask=nil end
    M.AFKBusy=false
    -- Always release a synthetic held button, including when stopped mid-pulse.
    pcall(function()game:GetService("VirtualUser"):Button2Up(Vector2.zero,workspace.CurrentCamera.CFrame)end)
    pcall(function()local input:any=game:GetService("VirtualInputManager");input:SendKeyEvent(false,Enum.KeyCode.Space,false,game)end)
    if value then
        M.IdleConnection=LP.Idled:Connect(function()M.AFKPulse()end)
        M.NextAFK=0;M.AFKStatus="Включён · импульс каждые 2 минуты и при Idled"
    else M.AFKStatus="Выключен"end
end
local UIS=game:GetService("UserInputService")
function M.SetDesc(card:any,text:string)
    if type(setthreadidentity)=="function"then setthreadidentity(8)end
    card:SetDesc(text)
end
table.insert(M.Connections,UIS.InputBegan:Connect(function()M.LastInput=os.clock()end))
table.insert(M.Connections,UIS.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement then M.LastInput=os.clock()end
end))
function M.Stop()
    E.Stop();M.AutoBreak=false;M.AutoDrops=false
    M.ClearLucky();M.ClearHover();M.CancelDrops();M.ReleasePets();M.SetAFK(false)
end
function M.Shutdown()
    if type(setthreadidentity)=="function"then setthreadidentity(8)end
    if not M.Alive then return end
    M.Alive=false;M.Stop()
    for _,connection in ipairs(M.Connections)do connection:Disconnect()end
    table.clear(M.Connections)
    if M.Fluent then pcall(function()M.Fluent:Destroy()end)end
    if env.PS99EventHub==M then env.PS99EventHub=nil end
    print("[PS99 Event] полностью остановлен")
end
local reloadState:any=rawget(getfenv(),"STATE")
if reloadState and type(reloadState.onCleanup)=="function"then reloadState.onCleanup(M.Shutdown)end

local uiOk,Fluent=pcall(function()
    local source=game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
    local chunk,err=loadstring(source)
    if not chunk then error(err)end
    return chunk()
end)
if not uiOk or type(Fluent)~="table"then M.Shutdown();error("Fluent: "..tostring(Fluent))end
M.Fluent=Fluent
local originalSafeCallback=Fluent.SafeCallback
Fluent.SafeCallback=function(self:any,callback:any,...:any)
    if type(setthreadidentity)=="function"then setthreadidentity(8)end
    return originalSafeCallback(self,callback,...)
end
local built,buildError=pcall(function()
    local Window=Fluent:CreateWindow({Title="D1ablo · Hatch Wars",SubTitle="Standalone Event · "..M.Version,
        TabWidth=155,Size=UDim2.fromOffset(700,540),Acrylic=false,Theme="Dark",MinimizeKey=Enum.KeyCode.RightControl})
    assert(Window,"Fluent window not created")
    M.Window=Window
    Fluent:ToggleTransparency(false)
    local originalMinimize=Window.Minimize
    Window.Minimize=function(self:any)
        if type(setthreadidentity)=="function"then setthreadidentity(8)end
        originalMinimize(self)
        if M.ReopenButton then M.ReopenButton.Visible=Window.Minimized end
    end
    local Tabs={
        Home=Window:AddTab({Title="Обзор",Icon="home"}),
        Collect=Window:AddTab({Title="Сбор орбов",Icon="sparkles"}),
        Fight=Window:AddTab({Title="Бой",Icon="swords"}),
        Pumpkin=Window:AddTab({Title="Тыква",Icon="gift"}),
        Upgrades=Window:AddTab({Title="Прокачка",Icon="arrow-up"}),
        Settings=Window:AddTab({Title="Настройки",Icon="settings"})}
    M.Tabs=Tabs;M.Toggles={}
    local function toggle(tab:any,id:string,title:string,description:string,callback:any,default:boolean?)
        local option=tab:AddToggle(id,{Title=title,Description=description,Default=default==true})
        M.Toggles[id]=option
        option:OnChanged(function(value)if M.Alive then callback(value)end end)
        return option
    end
    E.Card=Tabs.Home:AddParagraph({Title="Hatch Wars · живой статус",Content="Чтение игры…"})
    M.StatsCard=Tabs.Home:AddParagraph({Title="Сессия",Content=""})
    Tabs.Home:AddButton({Title="Остановить всю автоматику",Description="Окно останется открытым.",Callback=function()
        M.Stop()
        for id,option in pairs(M.Toggles)do if id~="EventFarmTP"then option:SetValue(false)end end
    end})
    M.MinimizeButton=Tabs.Home:AddButton({Title="Свернуть окно",Description="Клавишу можно поменять в настройках.",Callback=function()Window:Minimize()end})
    Tabs.Home:AddButton({Title="Полностью закрыть скрипт",Description="Убирает окно, циклы, анти-AFK и управление питомцами.",Callback=M.Shutdown})
    Tabs.Home:AddParagraph({Title="Отдельная версия",Content="Главный хаб не изменяется. Не включай его автоматику одновременно. Скрытие анимаций яиц здесь отсутствует."})
    toggle(Tabs.Collect,"EventLucky","Auto Lucky Orbs","Наземные орбы удачи. Полный банк, бой и тыква ставят сбор на паузу.",function(v)
        E.AutoOrbs=v;E.NextOrb=0;M.ClearLucky();if not v then M.ClearHover()end
    end)
    local scope=Tabs.Collect:AddDropdown("EventScope",{Title="Где собирать орбы",Values={"Лучшая зона","Текущая зона","Все открытые"},Default=1,Multi=false})
    scope:OnChanged(function(v)M.OrbScope=v;M.ClearLucky()end)
    local movement=Tabs.Collect:AddDropdown("EventMovement",{Title="Как собирать удачу",Values={"Телепорт","Ховерборд"},Default=1,Multi=false})
    movement:OnChanged(function(v)M.OrbMovement=v;M.ClearLucky();M.ClearHover()end)
    toggle(Tabs.Collect,"EventDrops","Auto выпавшие орбы · TP","Монеты и обычные орбы от брейкаблов. Без угадывания remotes; подбирает сама игра.",function(v)
        M.AutoDrops=v;M.NextDrop=0;if not v then M.CancelDrops()end
    end)
    Tabs.Collect:AddSlider("LuckyInterval",{Title="Интервал удачи, секунд",Default=.8,Min=.2,Max=3,Rounding=1,Callback=function(v)M.LuckyDelay=v end})
    Tabs.Collect:AddSlider("PickupTimeout",{Title="Таймаут подбора, секунд",Default=6,Min=2,Max=12,Rounding=0,Callback=function(v)M.OrbWait=v end})
    Tabs.Collect:AddSlider("DropBatch",{Title="Обычных орбов за проход",Default=3,Min=1,Max=10,Rounding=0,Callback=function(v)M.DropBatch=v end})
    Tabs.Collect:AddSlider("DropInterval",{Title="Пауза между обычными орбами",Default=.6,Min=.25,Max=2,Rounding=2,Callback=function(v)M.DropDelay=v end})
    Tabs.Collect:AddParagraph({Title="Ховерборд",Content="Включи ховерборд вручную. Этот режим направляет его к наземным орбам, не телепортирует. Отключение возвращает обычное управление. Орбы на лестнице тыквы намеренно пропускаются."})
    toggle(Tabs.Fight,"EventBoss","Auto Boss","Лучшая открытая зона. Входит только при рекомендованных монетах и удаче, затем кликает по целям.",function(v)
        E.AutoBoss=v;E.BossStartNext=0;if not v then E.CancelStart()end
    end)
    toggle(Tabs.Fight,"EventProgress","Auto переход в новую зону","После подтверждённого открытия арены. Ждёт окончания камеры босса.",function(v)E.AutoProgress=v end)
    toggle(Tabs.Fight,"EventBreak","Auto ломание всех","Распределяет твоих экипированных питомцев по объектам зоны фарма. Считает серверные подтверждения урона.",function(v)
        M.AutoBreak=v;M.NextBreak=0;if not v then M.ReleasePets()end
    end)
    toggle(Tabs.Fight,"EventFarmTP","TP в зону фарма","Сам входит в пунктирную область. Без этого с площадки тыквы / издалека игра не принимает удары.",function(v)M.FarmAreaTP=v end,true)
    local breakScope=Tabs.Fight:AddDropdown("BreakScope",{Title="Брейкаблы: какие зоны",Values={"Все открытые","Лучшая зона","Текущая зона"},Default=1,Multi=false})
    breakScope:OnChanged(function(v)M.BreakScope=v;M.ReleasePets();M.NextBreak=0 end)
    M.FightCard=Tabs.Fight:AddParagraph({Title="Фарм",Content="Выключено"})
    local pumpkinToggle:any
    local pumpkinApproved=false
    pumpkinToggle=toggle(Tabs.Pumpkin,"EventPumpkin","Auto Giant Pumpkin","Отдаёт запасных питомцев от слабых к сильным; открывает только полную тыкву.",function(v)
        if not v then E.AutoPumpkin=false;E.CancelPumpkin();pumpkinApproved=false;return end
        if pumpkinApproved then E.AutoPumpkin=true;E.NextPumpkin=0;return end
        pumpkinToggle:SetValue(false)
        Window:Dialog({Title="Безвозвратная отдача питомцев",Content="Тыква поглощает запасных ивентовых питомцев, включая радужных. Оставляем одного лучшего; заблокированных и эксклюзивных не трогаем. Включить?",Buttons={
            {Title="Включить",Callback=function()if M.Alive then pumpkinApproved=true;pumpkinToggle:SetValue(true)end end},
            {Title="Отмена",Callback=function()end}}})
    end)
    M.PumpkinCard=Tabs.Pumpkin:AddParagraph({Title="Гигантская тыква",Content="Выключена"})
    Tabs.Pumpkin:AddParagraph({Title="Как работает",Content="Проверяет актуальный Spare непосредственно перед отдачей, соблюдает игровой cooldown. После открытия награды выдаёт игра; фиктивного Claim здесь нет."})
    toggle(Tabs.Upgrades,"EventUpgrade","Auto Event Upgrades","Строгий порядок сверху вниз: первый выбранный до максимума, затем следующий.",function(v)
        E.AutoUpgrades=v;E.NextUpgrade=0;if not v then E.CancelUpgrade()end
    end)
    Tabs.Upgrades:AddParagraph({Title="Приоритет",Content="Выбери буст, затем нажми «Выше» или «Ниже». Недостаточно ресурсов для верхнего — копим, не пропускаем. Порядок сохраняется."})
    E.PriorityCard=Tabs.Upgrades:AddParagraph({Title="Порядок сверху вниз",Content="Ожидание ивентовых апгрейдов…"})
    function M.BuildPriorityUI()
        if M.PriorityUIReady or not E.EnsurePriorities()or #E.PriorityOrder==0 then return end
        M.PriorityUIReady=true;E.SelectedUpgradeId=E.PriorityOrder[1]
        local names={};local byName={}
        for _,id in ipairs(E.PriorityOrder)do
            local name=E.PriorityDirs[id].Name
            if byName[name]then name=name.." · "..id end
            table.insert(names,name);byName[name]=id
        end
        local selected=Tabs.Upgrades:AddDropdown("PriorityChoice",{Title="Какой буст переместить",Values=names,Default=1,Multi=false})
        selected:OnChanged(function(v)if byName[v]then E.SelectedUpgradeId=byName[v];E.RefreshPriorityUI()end end)
        Tabs.Upgrades:AddButton({Title="↑ Выше",Callback=function()E.MovePriority(-1)end})
        Tabs.Upgrades:AddButton({Title="↓ Ниже",Callback=function()E.MovePriority(1)end})
        E.PriorityEnableButton=Tabs.Upgrades:AddButton({Title="Отключить выбранный буст",Callback=E.ToggleSelectedPriority})
        E.RefreshPriorityUI()
    end
    M.BuildPriorityUI()
    toggle(Tabs.Settings,"EventAFK","Anti-AFK","Импульс каждые 2 минуты + Idled. Фоновый VirtualUser и нативный ввод, когда окно активно.",M.SetAFK,true)
    M.MinimizeBind=Tabs.Settings:AddKeybind("EventMinimize",{Title="Клавиша сворачивания",Description="Нажми на клавишу справа, затем на новую кнопку клавиатуры.",Mode="Toggle",Default="RightControl"})
    Fluent.MinimizeKeybind=M.MinimizeBind
    M.MinimizeBind:OnChanged(function()
        if type(setthreadidentity)=="function"then setthreadidentity(8)end
        M.MinimizeButton:SetDesc("Свернуть / развернуть: "..M.MinimizeBind.Value)
    end)
    -- One reopen widget; the menu itself is entirely Fluent.
    local square=Instance.new("TextButton")
    square.Name="EventReopen";square.Size=UDim2.fromOffset(48,48)
    square.Position=UDim2.fromOffset(18,170);square.BackgroundColor3=Color3.fromRGB(25,29,38)
    square.Text="D";square.Font=Enum.Font.GothamBold;square.TextSize=24
    square.TextColor3=Color3.fromRGB(76,194,255);square.BorderSizePixel=0
    square.Visible=false;square.ZIndex=100;square.Parent=Fluent.GUI
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=square
    local border=Instance.new("UIStroke");border.Color=Color3.fromRGB(76,194,255);border.Thickness=1;border.Parent=square
    M.ReopenButton=square
    local dragStart:Vector3?=nil;local dragPosition:UDim2?=nil;local dragged=false
    table.insert(M.Connections,square.InputBegan:Connect(function(input)
        if type(setthreadidentity)=="function"then setthreadidentity(8)end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragStart=input.Position;dragPosition=square.Position;dragged=false
        end
    end))
    table.insert(M.Connections,UIS.InputChanged:Connect(function(input)
        if not dragStart or not dragPosition then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
        local delta=input.Position-dragStart
        if delta.Magnitude>5 then dragged=true end
        if type(setthreadidentity)=="function"then setthreadidentity(8)end
        local view=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
        square.Position=UDim2.fromOffset(math.clamp(dragPosition.X.Offset+delta.X,0,math.max(0,view.X-48)),math.clamp(dragPosition.Y.Offset+delta.Y,0,math.max(0,view.Y-48)))
    end))
    table.insert(M.Connections,UIS.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragStart=nil;dragPosition=nil end
    end))
    table.insert(M.Connections,square.MouseButton1Click:Connect(function()
        if not dragged and M.Alive and Window.Minimized then
            if type(setthreadidentity)=="function"then setthreadidentity(8)end
            Window:Minimize();square.Visible=false
        end
    end))
    M.AFKCard=Tabs.Settings:AddParagraph({Title="Anti-AFK · диагностика",Content=M.AFKStatus})
    Tabs.Settings:AddButton({Title="Проверить импульс Anti-AFK сейчас",Callback=M.AFKPulse})
    Tabs.Settings:AddParagraph({Title="Важно",Content="Событие ввода и отсутствие ошибки — разные вещи. Статус показывает, увидел ли Roblox ввод. Защита от 20-минутного отключения в фоне требует длительной проверки; гарантии нет."})
    Tabs.Settings:AddButton({Title="Сбросить счётчики сессии",Callback=function()
        M.Started=os.clock();M.Assigned=0;M.FarmHits=0;M.FarmRequests=0;M.RemovedDrops=0;M.RemovedLucky=0;M.LuckGained=0;M.AFKAttempts=0;M.AFKObserved=0
        E.Teleports=0;E.Clicks=0;E.CircleHits=0;E.PumpkinFed=0;E.PumpkinOpened=0
    end})
    Window:SelectTab(1)
end)
if not built then M.Shutdown();error("Event UI: "..tostring(buildError))end
table.insert(M.Connections,LP.CharacterAdded:Connect(function()
    M.ClearLucky();M.ReleasePets();M.ClearHover();M.CancelDrops();E.CancelStart();E.CancelPumpkin()
    E.NextOrb=os.clock()+3;E.BossStartNext=os.clock()+3;M.NextBreak=os.clock()+3
end))
M.Worker=task.spawn(function()
    if type(setthreadidentity)=="function"then setthreadidentity(8)end
    while M.Alive and not Fluent.Unloaded do
        local ok,err=xpcall(function()
            if type(setthreadidentity)=="function"then setthreadidentity(8)end
            M.ReopenButton.Visible=M.Window.Minimized
            if M.Conflict then M.SetDesc(E.Card,M.Conflict)end
            if not blocked()then E.ProgressStep();E.PumpkinStep()end
            E.OrbStep()
            if not M.Conflict and E.Init()then E.BossStep();E.UpgradeStep()end
            M.BreakStep();M.DropStep()
            if M.AntiAFK and os.clock()>=M.NextAFK then M.AFKPulse()end
            if os.clock()>=(M.NextUI or 0)then
                M.NextUI=os.clock()+1.5;M.BuildPriorityUI()
                local good,status=pcall(E.Status)
                if good then M.SetDesc(E.Card,M.Conflict or status)end
                M.SetDesc(M.StatsCard,string.format("В игре: %s · сессия: %d мин\nTP: %d · прирост банка удачи: %s\nИсчезнувшие цели: удача %d / обычные %d\nОбычные орбы: %s",
                    LP.Name,math.floor((os.clock()-M.Started)/60),E.Teleports,tostring(M.LuckGained),M.RemovedLucky,M.RemovedDrops,M.DropStatus))
                M.SetDesc(M.FightCard,M.BreakStatus)
                M.SetDesc(M.PumpkinCard,E.PumpkinStatus.."\nОтдано питомцев: "..E.PumpkinFed.." · открыто тыкв: "..E.PumpkinOpened)
                M.SetDesc(M.AFKCard,M.AFKStatus.."\nИмпульсов: "..M.AFKAttempts.." · ввод подтверждён: "..M.AFKObserved)
            end
        end,function(message)return debug.traceback(tostring(message))end)
        if not ok then
            M.LastError=tostring(err)
            if M.LastLoggedError~=M.LastError then M.LastLoggedError=M.LastError;warn("[PS99 Event] "..M.LastError)end
        end
        task.wait(ok and .15 or 2)
    end
    if M.Alive then M.Shutdown()end
end)
print("[PS99 Event] Fluent готов · "..LP.Name.." · автоматика выключена, Anti-AFK включён")
return M


