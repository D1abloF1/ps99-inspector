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
local M:any={Alive=true,Version="1.8-auto-flame-test",Started=os.clock(),Connections={},Owned={},Errors={},
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
    local E:any={AutoOrbs=false,AutoBoss=false,BossLuckPercent=100,BossPending=false,BossStartNext=0,WasFighting=false,OrbStatus="Выключен",BossStatus="Выключен",
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
                Currency=loadModule(L.Client.CurrencyCmds),UpgradeCmds=loadModule(L.Client.EventUpgradeCmds),
                Luck=loadModule(L.Util.HatchWarLuck),Flags=loadModule(L.Universal.FFlags),Actor=loadModule(module.Boss.Actor)}
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
        if E.UpgradePending or E.PumpkinPending or E.HW.Feature("Boss").IsFighting()or E.HW.Feature("Boss").HudHidden or M.Farm or M.AutoRank then return end
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
    function E.RestoreUpgrade()
        local trip=E.UpgradeReturn;E.UpgradeReturn=nil
        if not trip then return end
        pcall(function()
            if LP.Character==trip.Character and root()==trip.Root and E.HW.Instance()==trip.Instance
                and not E.HW.Feature("Boss").IsFighting()and not E.HW.Feature("Boss").HudHidden then
                trip.Root.CFrame=trip.Position;trip.Root.AssemblyLinearVelocity=Vector3.zero
            end
        end)
    end
    function E.CancelUpgrade()
        if E.UpgradeTask then pcall(task.cancel,E.UpgradeTask);E.UpgradeTask=nil end
        E.RestoreUpgrade()
        E.UpgradePending=false
    end
    function E.UpgradeStep()
        if not E.AutoUpgrades then E.UpgradeStatus="Выключено";return end
        if E.PumpkinPending or E.UpgradePending or os.clock()<E.NextUpgrade then return end
        if M.EntryPending or M.DropBusy or (M.Clan and M.Clan.Pending)or (M.AutoEgg and M.AutoEgg.Pending)then return end
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
        local interact=inst.model and inst.model:FindFirstChild("INTERACT")
        local machines=interact and interact:FindFirstChild("Machines")
        local machine=machines and machines:FindFirstChild("HatchWarUpgradeMachine")
        local pad=machine and (machine:FindFirstChild("Pad")or machine:FindFirstChild("Interact"))
        local r=root()
        if not r then E.UpgradeStatus="Ожидание персонажа";return end
        if not pad or not pad:IsA("BasePart")then E.UpgradeStatus="Ожидание зоны апгрейдов";return end
        E.UpgradePending=true;E.UpgradeStatus="Идём к апгрейдам: "..dir.Name.." · уровень "..(tier+1)
        E.UpgradeReturn={Character=LP.Character,Root=r,Instance=inst,Position=r.CFrame}
        if M.ClearLucky then M.ClearLucky()end
        if M.ClearHover then M.ClearHover()end
        E.UpgradeTask=task.spawn(function()
            local ok,result,reason=pcall(function()
                if not M.Alive or not E.AutoUpgrades or E.HW.Instance()~=inst then return false end
                r.CFrame=pad.CFrame*CFrame.new(0,pad.Size.Y/2+3,0)
                r.AssemblyLinearVelocity=Vector3.zero
                task.wait(.8)
                if not M.Alive or not E.AutoUpgrades or E.HW.Instance()~=inst or root()~=r then return false end
                if E.SelectUpgrade()~=dir or E.UpgradeCmds.GetTier(dir)~=tier
                    or not E.HW.Feature("Upgrades").CanAfford(dir)then return false end
                E.UpgradeStatus="Покупаем "..dir.Name.." · уровень "..(tier+1)
                local accepted,message=E.UpgradeCmds.Purchase(dir)
                if accepted then
                    local deadline=os.clock()+3
                    while M.Alive and E.AutoUpgrades and E.HW.Instance()==inst
                        and E.UpgradeCmds.GetTier(dir)<=tier and os.clock()<deadline do task.wait(.1)end
                    if E.UpgradeCmds.GetTier(dir)<=tier then return false,"Ждём подтверждения уровня"end
                end
                return accepted,message
            end)
            E.RestoreUpgrade()
            E.UpgradePending=false;E.UpgradeTask=nil
            E.NextUpgrade=os.clock()+(ok and result and 3 or 15)
            if M.Alive and E.AutoUpgrades then
                E.UpgradeStatus=ok and result and ("Куплено: "..dir.Name.." · уровень "..(tier+1).." · вернулись")or ("Покупка не подтверждена · повтор через 15 с · "..tostring(ok and reason or result))
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
        -- Reserve copies, not stacks. Server Spare and our reservation overlap;
        -- min(spare, owned-reserved) avoids subtracting equipped pets twice.
        local ranking={};local keep={};local hugeCount=0
        for _,pet in pairs(E.Items.Pet:All())do
            local level=pet:GetExclusiveLevel();local owned=math.floor(pet:GetAmount())
            if level>=4 then hugeCount+=owned
            elseif level==0 and owned>0 then
                table.insert(ranking,{UID=pet:GetUID(),Count=owned,Power=pet:CalculatePower()})
            end
        end
        table.sort(ranking,function(a,b)return a.Power>b.Power or a.Power==b.Power and a.UID<b.UID end)
        local reserve=math.max(1,15-math.min(15,hugeCount))
        for _,pet in ipairs(ranking)do
            local count=math.min(reserve,pet.Count);keep[pet.UID]=count;reserve-=count
            if reserve<=0 then break end
        end
        E.TeamKeep=keep;E.TeamHugeCount=hugeCount
        for uid,amount in pairs(spare)do
            if type(uid)=="string"and type(amount)=="number"and amount==amount and amount>=0 and amount<math.huge then
                local pet=E.Items.Pet:Get(uid)
                if pet and pet:GetExclusiveLevel()==0 then
                    local points=E.PumpkinUtil.UnitPoints(pet,growth)
                    local owned=math.floor(pet:GetAmount())
                    local count=math.floor(math.min(amount,math.max(0,owned-(keep[uid]or 0))))
                    if owned>0 and type(points)=="number"and points>0 and points<math.huge then
                        if not pet:IsLocked()and count>0 then
                            table.insert(candidates,{UID=uid,Count=count,Points=points})
                        end
                    end
                end
            end
        end
        table.sort(candidates,function(a,b)
            if a.Points~=b.Points then return a.Points<b.Points end
            return a.UID<b.UID
        end)
        for _,pet in ipairs(candidates)do
            local count=math.min(pet.Count,math.ceil(remaining/pet.Points))
            if count>0 then plan[pet.UID]=count;total+=count;remaining-=count*pet.Points end
            if remaining<=0 then break end
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
        if E.PumpkinFillOnly and state.Points>=state.Cap then E.PumpkinStatus="Полная тыква сохранена для верхнего яйца";return end
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
                    E.NoSpare=count==0
                    if state.Points<state.Cap and count==0 then E.PumpkinStatus="Нет запасных питомцев вне защищённой команды";return true end
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
                if not E.PumpkinCanAct(inst)or not r.Parent or (r.Position-target.Position).Magnitude>E.PumpkinUtil.Reach()then return false end
                state=pumpkin.GetState();if not state then return false end
                local operation="Open"
                if state.Points<state.Cap then
                    local spare=inst:InvokeCustom(prefix.."Spare")
                    if not E.PumpkinCanAct(inst)then return false end
                    state=pumpkin.GetState();if not state then return false end
                    if state.Points<state.Cap then
                        plan,count=E.BuildPumpkinPlan(spare,state)
                        E.NoSpare=count==0
                        if count==0 then E.PumpkinStatus="Нет запасных питомцев вне защищённой команды";return true end
                        operation="Feed"
                    end
                end
                if not E.PumpkinCanAct(inst)then return false end
                if operation=="Open"and E.PumpkinFillOnly then E.PumpkinStatus="Полная тыква сохранена";return true end
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
    function E.BossThreshold(zone:number)
        local boss=E.HW.Feature("Boss")
        local coins,recommended=boss.Recommended(zone)
        local current=boss.PlayerLuck(zone)
        local bank,cap=E.HW.Feature("Orbs").Bank()
        local computed=E.Luck.Compute(LP,{inFight=true,eggId=E.Types.ZONES[zone].Egg,zone=zone})
        local perOrb=E.Flags.GetNumber(E.Flags.Keys.HatchWar_OrbLuckPerOrb)
            *(1+E.UpgradeCmds.GetPower(E.Types.UPGRADES.OrbPower)/100)
        -- Same additive orb contribution and FightMult as the game's FightLuck.
        -- Only fill the existing bank; never wait for unavailable future boosts/upgrades.
        local maximum=current+math.max(0,cap-bank)*perOrb*math.max(1,computed.FightMult or 1)
        local requested=recommended*math.clamp(E.BossLuckPercent or 100,50,200)/100
        return coins,math.min(requested,maximum),current,maximum,recommended
    end
    function E.BossEnabled()
        return E.AutoBoss or (M.AutoFlame and M.AutoFlame.NeedsBoss)==true
    end
    function E.BossStep()
        if not E.BossEnabled()then E.BossStatus="Выключен";return end
        if os.clock()<E.NextClick then return end
        E.NextClick=os.clock()+.17
        if not E.Init()or not E.HW.Instance()then E.BossStatus="Войди в Hatch Wars";return end
        local boss=E.HW.Feature("Boss")
        if not boss.IsFighting()then
            if E.PumpkinPending or E.UpgradePending then E.BossStatus="Пауза: тыква / апгрейды";return end
            if E.WasFighting then E.WasFighting=false;E.BossStartNext=os.clock()+8 end
            if E.BossPending then E.BossStatus="Ожидание старта боя…";return end
            if os.clock()<E.BossStartNext then return end
            if M.EntryPending or M.DropBusy or (M.AutoEgg and M.AutoEgg.Pending)then E.BossStatus="Пауза: вход / подбор / открытие";return end
            E.BossStartNext=os.clock()+2
            local inst=E.HW.Instance();local zone=E.BestZone()
            local required,luck,currentLuck,maximum,recommended=E.BossThreshold(zone)
            local balance=E.Currency.Get(E.Types.COIN)
            if balance<required then
                E.BossStatus="Ожидание монет: "..tostring(balance).."/"..tostring(required);return
            end
            if currentLuck+1e-6<luck then
                E.BossStatus=string.format("Копим удачу: %.0f / %.0f · порог %.0f%% · доступно до %.1f%%",currentLuck,luck,E.BossLuckPercent,maximum/math.max(1,recommended)*100);return
            end
            if M.Farm or M.AutoRank then E.BossStatus="Выключи Auto Farm / Auto Rank";return end
            local character=LP.Character;local r=character and character:FindFirstChild("HumanoidRootPart")
            local h=character and character:FindFirstChildOfClass("Humanoid")
            if not r or not h or h.Health<=0 then E.BossStatus="Ожидание персонажа";return end
            local interact=inst.model:FindFirstChild("INTERACT")
            local bosses=interact and interact:FindFirstChild("Bosses")
            local target=bosses and bosses:FindFirstChild("Boss"..zone)
            if not target or not target:IsA("Model")then E.BossStatus="Ожидание модели босса";return end
            local spot=E.Actor.Root(zone)
            if not spot then spot=E.Actor.Spots(target)end
            if not spot then spot=target:FindFirstChild("Player")end
            if not spot or not spot:IsA("BasePart")then E.BossStatus="Ожидание точки входа босса";return end
            local startPosition=spot.Position
            local returnPosition=r.CFrame
            E.BossPending=true;E.BossStatus="Запуск босса · зона "..zone
            if M.ClearLucky then M.ClearLucky()end
            if M.ClearHover then M.ClearHover()end
            E.StartTask=task.spawn(function()
                -- The start request may yield; keep clicks and the UI worker responsive.
                local ok,result=pcall(function()
                    if not M.Alive or not E.BossEnabled()or E.HW.Instance()~=inst then return false end
                    local currentCoins,threshold,available=E.BossThreshold(zone)
                    if E.Currency.Get(E.Types.COIN)<currentCoins or available+1e-6<threshold then return false end
                    r.CFrame=CFrame.new(startPosition+Vector3.new(0,3,6))*r.CFrame.Rotation
                    r.AssemblyLinearVelocity=Vector3.zero
                    task.wait(.6)
                    if not M.Alive or not E.BossEnabled()or E.HW.Instance()~=inst or root()~=r then return false end
                    -- Recheck immediately before asking the game to start (no underfunded dialog).
                    currentCoins,threshold,available=E.BossThreshold(zone)
                    if E.Currency.Get(E.Types.COIN)<currentCoins or available+1e-6<threshold then return false end
                    local accepted=boss.RequestFight(zone)
                    if accepted then
                        local deadline=os.clock()+3
                        while M.Alive and E.HW.Instance()==inst and not boss.IsFighting()and not boss.HudHidden and os.clock()<deadline do task.wait(.1)end
                    end
                    return accepted and (boss.IsFighting()or boss.HudHidden)
                end)
                if not boss.IsFighting()and not boss.HudHidden and root()==r and E.HW.Instance()==inst then
                    r.CFrame=returnPosition;r.AssemblyLinearVelocity=Vector3.zero
                end
                E.BossPending=false;E.StartTask=nil
                E.BossStartNext=os.clock()+(ok and result and 8 or 4)
                if M.Alive and E.BossEnabled()then
                    E.BossStatus=ok and result and "Бой запущен"or ("Старт не подтверждён · повтор через 4 с"..(not ok and (" · "..tostring(result))or ""))
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
    return E.BossPending or boss.IsFighting()or boss.HudHidden or E.PumpkinPending or E.UpgradePending
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
    -- Use the game's explicit Stalk flag, not height alone: some tree orbs
    -- appear near ground level and must still be excluded.
    if os.clock()>=(M.NextGroundIndex or 0)then
        M.NextGroundIndex=os.clock()+.5;M.GroundOrbParts={}
        local feature=E.HW.Feature("Orbs")
        if type(debug.getupvalues)=="function"and type(feature.OnLeave)=="function"then
            for _,value in pairs(debug.getupvalues(feature.OnLeave))do
                if type(value)=="table"then for _,record in pairs(value)do
                    if type(record)=="table"and record.Stalk==false and typeof(record.Part)=="Instance"then M.GroundOrbParts[record.Part]=true end
                end end
            end
        end
    end
    local target:Model?=nil;local nearest=math.huge
    if folder then for _,orb in ipairs(folder:GetChildren())do
        if orb:IsA("Model")and M.GroundOrbParts[orb]and (E.Skipped[orb]or 0)<=os.clock()then
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
        if not M.FarmAreaTP and not (M.AutoFlame and M.AutoFlame.Active)then M.BreakStatus="Войди в пунктирную зону фарма или включи TP в зону";return end
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
-- Clan controller owns movement while enabled. Resource operations use the game's
-- existing APIs, never an invented stalk remote or a fabricated climb sequence.
local K:any={Enabled=false,Phase="Bank",Status="Выключен",FillPercent=80,MinMult=2,BatchLimit=3,
    Batch=0,Hatches=0,Candles=0,Lanterns=0,FarmMinutes=10,
    Replenish=false,Reroll=false,Epoch=0,Next=0,Pending=false,Log={},
    Multipliers={ ["2"]=true,["2.5"]=true,["3"]=true },
    Boosts={ ["Свеча I"]=true,["Свеча II"]=true,["Фонарь I"]=true,["Фонарь II"]=true }}
M.Clan=K
function K.Init()
    if K.Ready then return true end
    if not E.Init()then return false end
    K.Custom=loadModule(L.Client.CustomEggsCmds)
    K.Items=loadModule(L.Items);K.Bursts=loadModule(L.Util.HatchWarBursts)
    K.Consume=loadModule(L.Client.ConsumableCmds)
    K.Hatching=loadModule(L.Client.HatchingCmds)
    K.EggCmds=loadModule(L.Client.EggCmds)
    K.Price=loadModule(L.Balancing.CalcEggPricePlayer)
    K.Stalk=loadModule(L.Util.HatchWarStalk)
    K.Ready=true
    return true
end
function K.Stock(category:string)
    local best=nil;local count=0
    for _,item in pairs(K.Items.Consumable:All())do
        local label=(category=="Candle"and "Свеча "or "Фонарь ")..(item:GetTier()==2 and "II"or "I")
        if item:GetId()==K.Bursts.ID[category]and item:GetTier()<=2 and K.Boosts[label]and item:GetAmount()>0 and not item:IsLocked()then
            count+=item:GetAmount()
            if not best or item:GetTier()>best:GetTier()then best=item end
        end
    end
    return best,count
end
function K.Selection(values:any)
    local selected={}
    for key,value in pairs(values)do
        if type(key)=="string"and value==true then selected[key]=true end
    end
    return selected
end
function K.Wants(category:string):boolean
    local prefix=category=="Candle"and "Свеча "or "Фонарь "
    return K.Boosts[prefix.."I"]==true or K.Boosts[prefix.."II"]==true
end
function K.ScanEggs()
    local final=E.Types.ZONES[#E.Types.ZONES].Egg
    local scan:any={Ready=nil,ReadyMult=0,Selected=nil,SelectedMult=0,Any=nil,AnyMult=0,Known=0,Visible=0,Rows={}}
    for _,egg in pairs(K.Custom.All())do
        if egg._id==final and egg._owner==LP then
            local mult=tonumber(string.match(tostring(egg:GetTitle()),"x([%d%.]+)"))or 0
            local model=egg:GetModel()
            local visible=egg:IsRenderable()and model~=nil and model.Parent~=nil
            local ready=visible and egg:IsHatchable()
            if mult>0 then scan.Known+=1;if visible then scan.Visible+=1 end end
            table.insert(scan.Rows,{Mult=mult,Visible=visible,Ready=ready,Selected=K.Multipliers[tostring(mult)]==true})
            if mult>scan.AnyMult then scan.Any=egg;scan.AnyMult=mult end
            if mult>0 and K.Multipliers[tostring(mult)]then
                if mult>scan.SelectedMult then scan.Selected=egg;scan.SelectedMult=mult end
                if ready and (not scan.Ready or mult>scan.ReadyMult or mult==scan.ReadyMult and egg:GetPosition().Y>scan.Ready:GetPosition().Y)then
                    scan.Ready=egg;scan.ReadyMult=mult
                end
            end
        end
    end
    K.LastScan=scan
    return scan
end
function K.TopEgg()
    local scan=K.ScanEggs()
    return scan.Ready or scan.Selected or scan.Any,scan.Ready and scan.ReadyMult or scan.Selected and scan.SelectedMult or scan.AnyMult
end
-- Replenishment is not a boosted CB series: choose the best affordable tree
-- egg with the final pet set regardless of the CB multiplier selection.
function K.FarmEgg()
    local final=E.Types.ZONES[#E.Types.ZONES].Egg
    local best=nil;local bestCount=0;local bestMult=0;local fallback=nil;local fallbackCount=0
    for _,candidate in pairs(K.Custom.All())do
        local model=candidate:GetModel()
        if candidate._id==final and candidate:IsRenderable()and candidate:IsHatchable()and model and model.Parent
            and (candidate._owner==LP or candidate._owner==nil)then
            local dir=candidate:Directory()
            local price=K.Price(dir,nil,not candidate._allowChargedAndGolden)
            local maximum=candidate:GetMaxEggCount()or K.EggCmds.GetMaxHatch(dir)
            local count=price>0 and math.floor(math.min(maximum,E.Currency.Get(dir.currency)/price))or 0
            if count>0 then
                if candidate._owner==LP then
                    local mult=tonumber(string.match(tostring(candidate:GetTitle()),"x([%d%.]+)"))or 0
                    if mult>0 and (not best or mult>bestMult or mult==bestMult and candidate:GetPosition().Y>best:GetPosition().Y)then
                        best=candidate;bestCount=count;bestMult=mult
                    end
                else fallback=candidate;fallbackCount=count end
            end
        end
    end
    return best or fallback,best and bestCount or fallbackCount,best and bestMult or 0
end
function K.SetPhase(phase:string)
    if K.Phase==phase then return end
    K.Phase=phase;K.PhaseAt=os.clock();K.Batch=0
    if phase=="Farm"then K.FarmTreeAttempt=nil end
    M.ClearLucky();M.ClearHover();M.ReleasePets();M.CancelDrops()
end
function K.Cancel()
    K.Epoch+=1
    if K.Task then pcall(task.cancel,K.Task);K.Task=nil end
    K.Pending=false
end
function K.SetEnabled(value:boolean)
    K.Cancel();K.Enabled=value
    E.AutoOrbs=false;E.AutoBoss=false;E.AutoPumpkin=false;E.AutoUpgrades=false;E.AutoProgress=false
    M.AutoBreak=false;M.AutoDrops=false
    E.CancelStart();E.CancelPumpkin();E.CancelUpgrade()
    E.PumpkinFillOnly=false
    M.ClearLucky();M.ClearHover();M.ReleasePets();M.CancelDrops()
    K.Phase="Bank";K.PhaseAt=os.clock();K.Next=0;K.Batch=0
    E.NoSpare=false
    K.FullSince=nil;K.FullKey=nil;K.FarmReason=nil
    K.Status=value and "Проверяем ресурсы и яйца с последним набором питомцев…"or "Выключен"
    if value then
        M.OrbScope="Все открытые";M.OrbMovement="Телепорт";M.BreakScope="Лучшая зона"
        if K.Init()and K.Hatching.IsHatching()then K.Hatching.StopHatching()end
    end
end
function K.Async(fn:any,nextDelay:number?)
    if K.Pending then return end
    local epoch=K.Epoch;local inst=E.HW.Instance()
    K.Pending=true
    K.Task=task.spawn(function()
        local function valid()return M.Alive and K.Enabled and K.Epoch==epoch and E.HW.Instance()==inst end
        local ok,err=xpcall(function()fn(valid)end,function(msg)return debug.traceback(tostring(msg))end)
        if K.Epoch==epoch then
            K.Pending=false;K.Task=nil;K.Next=os.clock()+(nextDelay or 3)
            if not ok then K.Status="Ошибка КБ: "..tostring(err);K.Next=os.clock()+10 end
        end
    end)
end
function K.Use(category:string,valid:any)
    if not K.Wants(category)then return true end
    if K.Bursts.BestArmed(LP,category)>0 then return true end
    local item=K.Stock(category)
    if not item then return false,"Нет "..category end
    local accepted,reason=K.Consume.Consume(item,1)
    if not accepted then return false,tostring(reason)end
    if category=="Candle"then K.Candles+=1 else K.Lanterns+=1 end
    local untilTime=os.clock()+3
    repeat
        if not valid()then return false,"Остановлено"end
        if K.Bursts.BestArmed(LP,category)>0 then return true end
        task.wait(.15)
    until os.clock()>=untilTime
    K.Unconfirmed=category
    return false,"Эффект не подтверждён; повтор не отправляем"
end
function K.Hatch(egg:any,count:number,useBoosts:boolean)
    K.Async(function(valid:any)
        local r=root();if not r or not egg:IsHatchable()then K.Status="Яйцо пока недоступно";return end
        M.ClearLucky();M.ClearHover();M.ReleasePets();M.CancelDrops()
        if (r.Position-egg:GetPosition()).Magnitude>12 then
            r.CFrame=CFrame.new(egg:GetPosition()+Vector3.new(0,3,4))*r.CFrame.Rotation
            r.AssemblyLinearVelocity=Vector3.zero;E.Teleports+=1
            task.wait(.6)
        end
        if not valid()or not r.Parent or (r.Position-egg:GetPosition()).Magnitude>35 then return end
        if useBoosts then
            local active,why=K.Use("Brew",valid)
            if not active then K.Status="Фонарь: "..tostring(why);return end
            if not valid()then return end
            active,why=K.Use("Candle",valid)
            if not active then K.Status="Свеча: "..tostring(why);return end
        end
        if not valid()then return end
        -- This is the same manual-purchase request used by CustomEggs PromptPurchase.
        -- Never SetupCustomEgg/AUTO: that path deliberately ignores Candle.
        local bankBefore=E.HW.Feature("Orbs").Bank()
        local accepted,reason=Network.Invoke("CustomEggs_Hatch",egg._uid,count)
        if not valid()then return end
        if not accepted then K.Status="Открытие отклонено: "..tostring(reason);return end
        K.Hatches+=1
        K.LastHatchCount=count
        if useBoosts then K.Batch+=1 else K.StockHatches=(K.StockHatches or 0)+count end
        task.wait(math.max(.15,K.EggCmds.ComputeDebounce()+.15))
        if not valid()then return end
        local bankAfter=E.HW.Feature("Orbs").Bank()
        K.Status="Игра приняла открытие "..count.." яиц · банк "..bankBefore.." → "..bankAfter
        table.insert(K.Log,1,K.Status);if #K.Log>6 then table.remove(K.Log)end
        print("[PS99 Clan] "..K.Status)
        if useBoosts and (K.Batch>=K.BatchLimit or bankAfter<bankBefore*.5)then K.SetPhase("Bank")end
    end,0)
end
function K.ApproachSelected(egg:any,forFarm:boolean?)
    if os.clock()<(K.NextEggApproach or 0)then return end
    K.NextEggApproach=os.clock()+10
    K.Async(function(valid:any)
        local r=root();if not r then return end
        M.ClearLucky();M.ClearHover();M.CancelDrops();M.ReleasePets()
        r.CFrame=CFrame.new(egg:GetPosition()+Vector3.new(0,3,4))*r.CFrame.Rotation
        r.AssemblyLinearVelocity=Vector3.zero;E.Teleports+=1
        K.Status="Подходим к выбранному яйцу · ждём разрешения игры"
        local deadline=os.clock()+5
        repeat
            task.wait(.25)
            if not valid()then return end
            if forFarm then
                local best=K.FarmEgg()
                if best and best._owner==LP then K.Status="Яйцо дерева доступно для пополнения питомцев";return end
            elseif K.ScanEggs().Ready then K.Status="Выбранное яйцо доступно для открытия";return end
        until os.clock()>=deadline
        K.Status="Яйцо найдено, игра пока не разрешила открытие · тыкву сохраняем"
    end,1)
end
function K.Step()
    if not K.Enabled then return end
    if not K.Init()or not E.HW.Instance()or not root()then K.Status="Войди в Hatch Wars";return end
    if E.BestZone()<#E.Types.ZONES then K.Status="Нужна последняя зона; босса КБ сам не запускает";return end
    local boss=E.HW.Feature("Boss")
    if boss.IsFighting()or boss.HudHidden or E.BossPending then K.Status="Пауза: бой с боссом";return end
    if blocked()then K.Status=M.Conflict or "Пауза: персонаж / тыква";return end
    if K.Pending or E.PumpkinPending then return end
    if K.Unconfirmed then
        if K.Bursts.BestArmed(LP,K.Unconfirmed)>0 then K.Unconfirmed=nil
        else K.Status="Пауза: ждём подтверждения использованного бустера; повтор не отправляем";return end
    end
    if os.clock()<K.Next then return end
    K.Next=os.clock()+.4
    E.AutoOrbs=false;M.AutoBreak=false;M.AutoDrops=false;E.AutoPumpkin=false
    local candle,candleCount=K.Stock("Candle");local brew,brewCount=K.Stock("Brew")
    local armed=K.Bursts.BestArmed(LP,"Candle")>0
    local brewActive=K.Bursts.BestArmed(LP,"Brew")>0
    K.InventoryStatus="Свечи: "..candleCount.." · фонари: "..brewCount
    if next(K.Multipliers)==nil then K.Status="Выбери хотя бы один множитель яйца";return end
    local scan=K.ScanEggs()
    local egg=scan.Ready or scan.Selected or scan.Any
    local mult=scan.Ready and scan.ReadyMult or scan.Selected and scan.SelectedMult or scan.AnyMult
    local pumpkinState=E.HW.Feature("Pumpkin").GetState()
    if not pumpkinState then K.Status="Ждём состояние тыквы";return end
    local full=pumpkinState.Points>=pumpkinState.Cap
    if full then
        E.NoSpare=false
        local key=tostring(pumpkinState.Opens)..":"..tostring(pumpkinState.Cap)
        if K.FullKey~=key then K.FullKey=key;K.FullSince=os.clock()end
    else K.FullKey=nil;K.FullSince=nil end
    local remaining=K.Phase=="Upper"and math.max(1,K.BatchLimit-K.Batch)or K.BatchLimit
    local stocked=(not K.Wants("Candle")or candleCount+(armed and 1 or 0)>=remaining)
        and (not K.Wants("Brew")or brewCount>0 or brewActive)
    K.EggStatus=egg and ("Последний набор: "..egg._id.." · x"..mult)or "Нет яйца последнего набора на дереве"
    if K.Phase=="Farm"then
        if full and stocked and K.FarmReason~="Coins"then K.SetPhase("Bank");return end
        local elapsed=os.clock()-(K.FarmAt or os.clock())
        if K.FarmReason=="Coins"then
            M.AutoBreak=true;M.AutoDrops=true;M.BreakScope="Лучшая зона"
            if egg then
                local price=K.Price(egg:Directory(),nil,not egg._allowChargedAndGolden)
                if price>0 and E.Currency.Get(egg:Directory().currency)>=price then K.FarmReason=nil;K.SetPhase("Bank");return end
            end
            K.Status="Фарм монет для выбранного яйца · тыкву сохраняем";return
        end
        if elapsed>=K.FarmMinutes*60 and (K.StockHatches or 0)>(K.FarmStartedHatches or 0)then
            K.SetPhase("Prep");E.NoSpare=false;return
        end
        M.AutoBreak=true;M.AutoDrops=true;M.BreakScope="Лучшая зона"
        local farmEgg,count,farmMult=K.FarmEgg()
        if (not farmEgg or farmEgg._owner~=LP)and scan.Any then
            local dir=scan.Any:Directory()
            local price=K.Price(dir,nil,not scan.Any._allowChargedAndGolden)
            local key=tostring(pumpkinState.Opens)..":"..tostring(pumpkinState.Points)..":"..tostring(scan.Any._uid)
            if price>0 and E.Currency.Get(dir.currency)>=price and K.FarmTreeAttempt~=key and os.clock()>=(K.NextEggApproach or 0)then
                K.FarmTreeAttempt=key;K.ApproachSelected(scan.Any,true);return
            end
        end
        K.Status="Фарм питомцев: "..math.floor(elapsed/60).."/"..K.FarmMinutes.." мин · собрано "..((K.StockHatches or 0)-(K.FarmStartedHatches or 0))
        if farmEgg and not M.DropBusy then
            K.Status=K.Status..(farmMult>0 and " · дерево x"..farmMult or " · обычное яйцо (дерево недоступно / не хватает монет)")
            M.AutoBreak=false;M.AutoDrops=false;K.Hatch(farmEgg,count,false)
        end
        return
    end
    -- A missing/unrendered egg is NOT proof of an unsuitable roll. Fill first,
    -- obtain resources if needed, then bank luck before testing hatchability.
    if not full or not stocked then
        K.SetPhase("Prep")
        if not full and E.NoSpare then
            K.SetPhase("Farm");K.FarmAt=os.clock();K.FarmStartedHatches=K.StockHatches or 0
            K.FarmReason="Pets"
            K.Status="Запасные питомцы кончились → фарм последней зоны";return
        end
        E.AutoPumpkin=true;E.PumpkinFillOnly=not full
        E.PumpkinStep();K.Status="Пополнение / поиск выбранного x · "..E.PumpkinStatus
        return
    end
    E.PumpkinFillOnly=true
    if K.Phase~="Bank"and K.Phase~="Upper"then K.SetPhase("Bank")end
    local bank,cap=E.HW.Feature("Orbs").Bank()
    if K.Phase=="Bank"and bank<cap*K.FillPercent/100 then
        M.OrbScope="Все открытые"
        local r=root();local inst=E.HW.Instance()
        local current=E.ZoneAt(inst,r.Position)
        local ground=current and inst.model.ZONE_GROUND:FindFirstChild(tostring(current))
        local bestGround=inst.model.ZONE_GROUND:FindFirstChild(tostring(E.BestZone()))
        if r and bestGround and (not ground or not E.HW.Feature("Hud").Unlocked(current)or r.Position.Y>ground.Position.Y+ground.Size.Y/2+15)then
            M.ClearLucky();M.ClearHover()
            r.CFrame=bestGround.CFrame*CFrame.new(0,bestGround.Size.Y/2+3,0)
            r.AssemblyLinearVelocity=Vector3.zero;E.Teleports+=1
            K.Next=os.clock()+1.5;K.Status="Переход в последнюю зону для появления орбов";return
        end
        E.AutoOrbs=true;E.OrbStep()
        K.Status="Удача во всех открытых зонах: "..bank.."/"..cap.." · цель "..K.FillPercent.."%";return
    end
    scan=K.ScanEggs();egg=scan.Ready;mult=scan.ReadyMult
    if not egg then
        if scan.Selected then
            K.Status="Выбранное яйцо x"..scan.SelectedMult.." найдено · ждём доступности, тыкву сохраняем"
            K.ApproachSelected(scan.Selected)
        elseif scan.Known>0 and scan.Visible==scan.Known and os.clock()-(K.FullSince or os.clock())>=5 then
            E.AutoPumpkin=true;E.PumpkinFillOnly=false
            E.PumpkinStep();K.Status="Все яйца видны, выбранного x нет → реролл · "..E.PumpkinStatus
        else K.Status="Ждём появления / обновления яиц дерева · тыкву сохраняем"end
        return
    end
    if K.Wants("Candle")and not candle and not armed or K.Wants("Brew")and not brew and not brewActive then
        K.SetPhase("Prep");return
    end
    if K.Phase=="Bank"then
        K.SetPhase("Upper");K.Batch=0
    end
    if bank<=0 then K.SetPhase("Bank");return end
    local price=K.Price(egg:Directory(),nil,not egg._allowChargedAndGolden)
    local maximum=egg:GetMaxEggCount()or K.EggCmds.GetMaxHatch(egg:Directory())
    local count=math.floor(math.min(maximum,E.Currency.Get(egg:Directory().currency)/price))
    if count<1 then K.SetPhase("Farm");K.FarmReason="Coins";K.FarmAt=os.clock();K.FarmStartedHatches=K.StockHatches or 0;K.Status="Не хватает монет → фарм последней зоны";return end
    K.Status="Бустеры → "..count.." яиц · открытие "..(K.Batch+1).."/"..K.BatchLimit
    K.Hatch(egg,count,true)
end
-- Optional flame controller: no mandatory tier in the clan hatch state machine.
local F:any={Enabled=false,Target=3,Active=false,NeedsBoss=false,Status="Выключено"}
M.AutoFlame=F
function F.State(inst:any)
    local state=inst:GetSavedValue(E.Types.SAVE.Flames)
    if type(state)~="table"then return 0,0 end
    local remaining=math.max(0,(tonumber(state.EndsAt)or 0)-workspace:GetServerTimeNow())
    local tier=math.clamp(math.floor(tonumber(state.Tier)or 0),0,3)
    return remaining>0 and tier or 0,remaining
end
function F.Release()
    F.NeedsBoss=false
    local prior=F.Prior;F.Prior=nil;F.Active=false
    if not prior then return end
    M.ClearLucky();M.ClearHover();M.CancelDrops();M.ReleasePets()
    E.AutoOrbs=prior.Orbs;M.AutoBreak=prior.Break;M.AutoDrops=prior.Drops
    M.OrbScope=prior.OrbScope;M.BreakScope=prior.BreakScope
    if root()==prior.Root and E.HW.Instance()==prior.Instance
        and not E.HW.Feature("Boss").IsFighting()and not E.HW.Feature("Boss").HudHidden then
        prior.Root.CFrame=prior.Position;prior.Root.AssemblyLinearVelocity=Vector3.zero
    end
end
function F.SetEnabled(value:boolean)
    F.Enabled=value
    if not value then
        if F.NeedsBoss and not E.AutoBoss then E.CancelStart()end
        F.Release();F.Status="Выключено"
    else F.Status="Проверяем пламя"end
end
function F.Acquire(inst:any)
    if F.Active then return end
    local r=root()
    F.Prior={Orbs=E.AutoOrbs,Break=M.AutoBreak,Drops=M.AutoDrops,OrbScope=M.OrbScope,
        BreakScope=M.BreakScope,Root=r,Instance=inst,Position=r.CFrame}
    F.Active=true;M.ClearLucky();M.ClearHover();M.CancelDrops();M.ReleasePets()
end
function F.CoinsStep():boolean
    if not E.AutoBoss then F.Release();return false end
    if not E.Init()or not E.HW.Instance()or not root()then F.Release();return false end
    local inst=E.HW.Instance();local boss=E.HW.Feature("Boss")
    if boss.IsFighting()or boss.HudHidden or E.BossPending then F.Release();return false end
    local required=boss.Recommended(E.BestZone())
    local balance=E.Currency.Get(E.Types.COIN)
    if balance>=required then F.Release();return false end
    if M.EntryPending or E.UpgradePending or E.PumpkinPending or K.Pending or (M.AutoEgg and M.AutoEgg.Pending)then return F.Active end
    if blocked()then F.Status=M.Conflict or "Пауза: бой / персонаж";return F.Active end
    F.Acquire(inst);F.NeedsBoss=false
    E.AutoOrbs=false;M.AutoBreak=true;M.AutoDrops=true;M.BreakScope="Лучшая зона"
    E.BossStatus="Фарм монет для босса: "..tostring(balance).." / "..tostring(required)
    F.Status=E.BossStatus
    return true
end
function F.Step():boolean
    if not F.Enabled then return F.CoinsStep()end
    if not E.Init()or not E.HW.Instance()or not root()then
        F.Release();F.Status="Войди в Hatch Wars";return false
    end
    local inst=E.HW.Instance();local boss=E.HW.Feature("Boss")
    local tier,remaining=F.State(inst)
    if F.Active and (boss.IsFighting()or boss.HudHidden or E.BossPending)then
        F.NeedsBoss=true;E.BossStep();F.Status="Пламя "..tier.." / "..F.Target.." · "..E.BossStatus;return true
    end
    if tier>=F.Target then
        F.Release();F.Status="Пламя "..tier.." / "..F.Target.." · осталось "..math.ceil(remaining).." с";return F.CoinsStep()
    end
    if E.BestZone()<#E.Types.ZONES then
        F.Release();F.Status="Нужна последняя открытая зона; новые зоны не открывает";return false
    end
    if E.Flags.Get(E.Flags.Keys.HatchWar_Flames)==false then
        F.Release();F.Status="Пламя отключено игрой";return false
    end
    if M.EntryPending or E.UpgradePending or E.PumpkinPending or K.Pending or (M.AutoEgg and M.AutoEgg.Pending)then
        F.Status="Ждём завершения текущего действия";return F.Active
    end
    if not F.Active then
        if blocked()then F.Status=M.Conflict or "Пауза: бой / персонаж";return false end
        F.Acquire(inst)
    end
    F.NeedsBoss=true
    local coins,goal,available=E.BossThreshold(E.BestZone())
    E.AutoOrbs=false;M.AutoBreak=false;M.AutoDrops=false
    if E.Currency.Get(E.Types.COIN)<coins then
        M.AutoBreak=true;M.AutoDrops=true;M.BreakScope="Лучшая зона"
        F.Status="Пламя "..tier.." / "..F.Target.." · фарм монет для босса"
    elseif available+1e-6<goal then
        E.AutoOrbs=true;M.OrbScope="Все открытые";E.OrbStep()
        F.Status="Пламя "..tier.." / "..F.Target.." · собираем удачу: "..math.floor(available).." / "..math.ceil(goal)
    else
        E.BossStep();F.Status="Пламя "..tier.." / "..F.Target.." · "..E.BossStatus
    end
    return true
end
local N:any={Enabled=false,Pending=false,Next=0,Epoch=0,Batches=0,Pets=0,Status="Выключено"}
M.AutoEgg=N
function N.SetEnabled(value:boolean)
    N.Epoch+=1;N.Enabled=value;N.Pending=false;N.Next=0
    if N.Task then pcall(task.cancel,N.Task);N.Task=nil end
    N.Status=value and "Ищем ближайшее яйцо"or "Выключено"
end
function N.Nearest()
    local r=root();if not r then return nil end
    local ids={};for _,zone in ipairs(E.Types.ZONES)do ids[zone.Egg]=true end
    local best=nil;local distance=35
    for _,egg in pairs(K.Custom.All())do
        if ids[egg._id]and (egg._owner==nil or egg._owner==LP)and egg:IsRenderable()and egg:IsHatchable()and egg:GetModel().Parent then
            local d=(r.Position-egg:GetPosition()).Magnitude
            if d<distance then best=egg;distance=d end
        end
    end
    return best
end
function N.Step()
    if not N.Enabled or N.Pending or os.clock()<N.Next then return end
    if F.Active then N.Status="Пауза: набираем пламя удачи";return end
    if K.Enabled then N.Status="Открытиями управляет цикл КБ";return end
    if not K.Init()or blocked()or M.EntryPending then N.Status="Пауза: вход / бой / тыква";return end
    local egg=N.Nearest()
    if not egg then N.Status="Нет доступного ивентового яйца рядом (35 studs)";N.Next=os.clock()+.5;return end
    local price=K.Price(egg:Directory(),nil,not egg._allowChargedAndGolden)
    local maximum=egg:GetMaxEggCount()or K.EggCmds.GetMaxHatch(egg:Directory())
    local count=price>0 and math.floor(math.min(maximum,E.Currency.Get(egg:Directory().currency)/price))or 0
    if count<=0 then N.Status="Не хватает монет на "..egg._id;N.Next=os.clock()+1;return end
    local epoch=N.Epoch;local inst=E.HW.Instance();N.Pending=true
    M.ClearLucky();M.ClearHover();M.CancelDrops()
    N.Task=task.spawn(function()
        local ok=pcall(function()
            local r=root()
            if not r or not N.Enabled or K.Enabled or not egg:IsHatchable()or (r.Position-egg:GetPosition()).Magnitude>35 then return end
            local accepted,reason=Network.Invoke("CustomEggs_Hatch",egg._uid,count)
            if epoch~=N.Epoch or not M.Alive or E.HW.Instance()~=inst then return end
            if accepted then N.Batches+=1;N.Pets+=count;N.Status=egg._id.." · открыто "..count.." · всего "..N.Pets
            else N.Status="Игра отклонила открытие: "..tostring(reason)end
        end)
        if epoch==N.Epoch then
            N.Pending=false;N.Task=nil;N.Next=os.clock()+math.max(.15,K.EggCmds.ComputeDebounce()+.15)
            if not ok then N.Status="Ошибка открытия; повтор через 5 секунд";N.Next=os.clock()+5 end
        end
    end)
end
function M.SetHideEggs(value:boolean)
    if not value then
        M.HideEggs=false
        if M.EggAnimationEnv and M.EggAnimationEnv.PlayNormalEggAnimation==M.EggAnimationWrapper then
            M.EggAnimationEnv.PlayNormalEggAnimation=M.EggAnimationOriginal
        end
        M.EggAnimationEnv=nil;M.EggAnimationWrapper=nil;M.EggAnimationOriginal=nil
        return true
    end
    if M.EggAnimationWrapper then M.HideEggs=true;return true end
    local scripts=LP.PlayerScripts:FindFirstChild("Scripts")
    local gameFolder=scripts and scripts:FindFirstChild("Game")
    local frontend=gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend")
    if not frontend or not frontend:IsA("LocalScript")or type(getsenv)~="function"then return false end
    local ok,animationEnv=pcall(getsenv,frontend)
    if not ok or type(animationEnv.PlayNormalEggAnimation)~="function"then return false end
    local original=animationEnv.PlayNormalEggAnimation
    local signal=loadModule(L.Signal)
    M.EggAnimationOriginal=original;M.EggAnimationEnv=animationEnv
    M.EggAnimationWrapper=function(id:any,pets:any,...)
        if not M.Alive or not M.HideEggs then return original(id,pets,...)end
        M.HiddenHatchBatches=(M.HiddenHatchBatches or 0)+1
        local ids={};local count=0
        for _,pet in ipairs(pets)do table.insert(ids,pet:GetId());count+=pet:GetAmount()end
        M.HiddenHatchPets=(M.HiddenHatchPets or 0)+count
        signal.Fire("HatchingRevealedPets",id,ids)
        -- Only the visual entry point is skipped. The original network handler still
        -- unhides inventory, sends SM_Unmask and fires CompletedHatching afterwards.
        return nil
    end
    M.HideEggs=true;animationEnv.PlayNormalEggAnimation=M.EggAnimationWrapper
    return true
end
function M.SetDesc(card:any,text:string)
    if type(setthreadidentity)=="function"then setthreadidentity(8)end
    card:SetDesc(text)
end
-- Device-local configuration. Never include the standalone destructive toggle.
local C:any={Path="PS99_Event/settings-v1.json",AutoLoad=false,AutoSave=true,Ready=false,Next=0}
M.Config=C
C.IDs={"EventMinimize","ClanFill","ClanMultiplier","ClanBoosts","ClanBatch","ClanFarmMinutes",
    "EventAutoEgg",
    "ClanHideHatch","EventScope","EventMovement","LuckyInterval","PickupTimeout",
    "DropBatch","DropInterval","EventFarmTP","BreakScope","EventAFK","EventProgress",
    "EventUpgrade","EventBoss","BossLuckPercent","AutoFlame","FlameTier","EventBreak","EventDrops","EventLucky","ClanCycle",
    "WebhookEnabled","WebhookUrl","WebhookDiscordID","WebhookTypes","ConfigAutoLoad","ConfigAutoSave"}
C.Active={"EventBoss","EventBreak","EventDrops","EventLucky","EventAutoEgg","ClanCycle","AutoFlame"}
function C.Snapshot()
    local values={}
    for _,id in ipairs(C.IDs)do
        local option=M.Fluent.Options[id]
        if option then values[id]=option.Type=="Dropdown"and option.Multi and K.Selection(option.Value)or option.Value end
    end
    return {Schema=1,Values=values,Priority=E.PrioritiesReady and {Order=E.PriorityOrder,Values=E.Priorities}or C.PendingPriority}
end
function C.ApplyPriority()
    local data=C.PendingPriority
    if not data or not E.EnsurePriorities()then return end
    if type(data.Order)=="table"and type(data.Values)=="table"then
        local order={};local seen={}
        for _,id in ipairs(data.Order)do if type(id)=="string"and E.PriorityDirs[id]and not seen[id]then seen[id]=true;table.insert(order,id)end end
        for _,id in ipairs(E.PriorityOrder)do if not seen[id]then table.insert(order,id)end end
        E.PriorityOrder=order
        for id in pairs(E.PriorityDirs)do local p=data.Values[id];if type(p)=="number"and p>=0 and p<=99 and p%1==0 then E.Priorities[id]=p end end
        E.ReindexPriorities();E.RefreshPriorityUI()
    end
    C.PendingPriority=nil
end
function C.Save()
    if type(writefile)~="function"then C.Status="Сохранение файлов не поддерживается";return false end
    local ok=pcall(function()local encoded=Http:JSONEncode(C.Snapshot());writefile(C.Path,encoded);C.Last=encoded end)
    C.Status=ok and "Настройки сохранены на этом устройстве"or "Не удалось сохранить настройки"
    return ok
end
function C.Read()
    if type(isfile)~="function"or type(readfile)~="function"then return nil end
    local ok,data=pcall(function()
        if not isfile(C.Path)then return nil end
        local raw=readfile(C.Path);if #raw>32768 then return nil end
        return Http:JSONDecode(raw)
    end)
    if ok and type(data)=="table"and data.Schema==1 and type(data.Values)=="table"then return data end
    return nil
end
function C.Apply(data:any)
    if not data then C.Status="Сохранённых настроек нет";return false end
    M.Restoring=true
    C.PendingPriority=type(data.Priority)=="table"and data.Priority or nil
    C.ApplyPriority()
    local active={};for _,id in ipairs(C.Active)do active[id]=true;M.Toggles[id]:SetValue(false)end
    local function set(id:string)
        local option=M.Fluent.Options[id];local value=data.Values[id]
        if not option or value==nil then return end
        if option.Type=="Toggle"then if type(value)~="boolean"then return end
        elseif option.Type=="Slider"then
            if type(value)~="number"or value~=value or math.abs(value)==math.huge then return end
            value=math.clamp(value,option.Min or 0,option.Max or 100)
        elseif option.Type=="Dropdown"then
            if option.Multi then
                if type(value)~="table"then return end
                local clean={};for _,allowed in ipairs(option.Values)do if value[allowed]==true then clean[allowed]=true end end;value=clean
            elseif type(value)~="string"or not table.find(option.Values,value)then return end
        elseif option.Type=="Keybind"then
            if type(value)~="string"or not pcall(function()return Enum.KeyCode[value]end)then return end
        elseif option.Type=="Input"then if type(value)~="string"or #value>512 then return end
        else return end
        local ok=pcall(function()option:SetValue(value)end)
        if not ok then C.Status="Не удалось применить один из параметров"end
    end
    for _,id in ipairs(C.IDs)do if not active[id]then set(id)end end
    -- Clan owns movement; don't restore competing autonomous routines alongside it.
    if data.Values.ClanCycle==true then set("ClanCycle")
    else for _,id in ipairs(C.Active)do set(id)end end
    M.Restoring=false;C.Ready=true;C.Last=Http:JSONEncode(C.Snapshot());C.Status="Настройки загружены"
    return true
end
function C.Step()
    if not C.Ready or os.clock()<C.Next then return end
    C.Next=os.clock()+2
    C.ApplyPriority()
    if C.AutoSave then
        local encoded=Http:JSONEncode(C.Snapshot())
        if encoded~=C.Last then C.Save()end
    end
end
-- Only our confirmed hatch packet; no inventory polling and no other players.
local W:any={Enabled=false,Url="",DiscordID="",Types={Huge=true,Titanic=true,Gargantuan=true},
    Queue={},Seen={},SeenOrder={},Next=0,Sent=0,Status="Выключен"}
M.Webhook=W
function W.ValidUrl(url:string):boolean
    return #url<=512 and (string.match(url,"^https://discord%.com/api/webhooks/%d+/[%w_%-]+$")~=nil
        or string.match(url,"^https://discordapp%.com/api/webhooks/%d+/[%w_%-]+$")~=nil)
end
function W.Payload(egg:string,pets:any)
    local lines={};for _,pet in ipairs(pets)do table.insert(lines,pet.Kind.." · "..pet.Name.." ×"..pet.Count)end
    local id=W.DiscordID;local mention=string.match(id,"^%d+$")and #id>=17 and #id<=20
    return {content=mention and ("<@"..id..">")or "",allowed_mentions={parse={},users=mention and {id}or {}},
        embeds={{title="Hatch Wars · редкий хэтч",description=table.concat(lines,"\n"),color=5096191,
            fields={{name="Игрок",value=LP.Name,inline=true},{name="Яйцо",value=egg,inline=true}}}}}
end
function W.OnHatch(egg:string,packet:any)
    if not M.Alive or not W.Enabled or not W.ValidUrl(W.Url)then return end
    local ok,result=pcall(function()
        local groups={};local payload=loadModule(L.Util.EggAnimPayload).Decompress(packet)
        for uid,data in pairs(payload)do
            if not W.Seen[uid]then
                W.Seen[uid]=true;table.insert(W.SeenOrder,uid)
                if #W.SeenOrder>4096 then W.Seen[table.remove(W.SeenOrder,1)]=nil end
                local pet=loadModule(L.Items).Pet:From(data):SetUID(uid):Freeze()
                local level=pet:GetExclusiveLevel()
                local kind=level==4 and "Huge"or level==5 and "Titanic"or level==6 and "Gargantuan"or nil
                if kind and W.Types[kind]then
                    local name=pet:GetName();local key=kind..name
                    if not groups[key]then groups[key]={Kind=kind,Name=name,Count=0}end
                    groups[key].Count+=1
                end
            end
        end
        local list={};for _,pet in pairs(groups)do table.insert(list,pet)end
        if #list>0 then return W.Payload(egg,list)end
        return nil
    end)
    if ok and result then
        if #W.Queue>=50 then table.remove(W.Queue,1)end
        table.insert(W.Queue,{Body=result,Retries=0});W.Status="Уведомление в очереди"
    elseif not ok then W.Status="Не удалось разобрать хэтч"end
end
function W.Step()
    if not W.Enabled then table.clear(W.Queue);return end
    if W.Pending or os.clock()<W.Next or #W.Queue==0 then return end
    if not W.ValidUrl(W.Url)then W.Status="Нужна действительная ссылка Discord webhook";table.clear(W.Queue);return end
    local send:any=request
    if type(send)~="function"then W.Status="HTTP-отправка не поддерживается";table.clear(W.Queue);return end
    local entry=table.remove(W.Queue,1);local url=W.Url;W.Pending=true
    W.Task=task.spawn(function()
        local ok,response=pcall(send,{Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=Http:JSONEncode(entry.Body)})
        if not M.Alive then return end
        W.Pending=false;W.Task=nil;W.Next=os.clock()+2
        local code=ok and type(response)=="table"and response.StatusCode or 0
        if code>=200 and code<300 then W.Sent+=1;W.Status="Отправлено: "..W.Sent
        elseif code==429 and entry.Retries<2 then
            entry.Retries+=1
            local delay=5
            local decoded,data=pcall(function()return Http:JSONDecode(response.Body)end)
            if decoded and type(data)=="table"and type(data.retry_after)=="number"then delay=math.clamp(data.retry_after,2,300)end
            W.Next=os.clock()+delay
            if W.Enabled and W.Url==url then table.insert(W.Queue,1,entry)end
            W.Status="Discord ограничил частоту; ждём"
        else W.Status="Отправка не выполнена · HTTP "..code end
    end)
end
table.insert(M.Connections,Network.Fired("Eggs_PlayOpenAnimation"):Connect(W.OnHatch))
-- Walk through the real Enter trigger; the game's normal touch handler enters.
M.AutoEnter=true;M.EntryNext=0
function M.EnterEvent()
    if M.EntryPending or not M.Alive then return end
    local instancing=loadModule(L.Client.InstancingCmds)
    M.EntryNext=os.clock()+5
    if instancing.IsBusy()or instancing.GetInstanceID()then return end
    if not instancing.DoesMeetRequirement("HatchWar")then M.EntryStatus="Ивент пока недоступен этому аккаунту";M.EntryNext=os.clock()+30;return end
    local r=root();local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    local things=workspace:FindFirstChild("__THINGS");local instances=things and things:FindFirstChild("Instances")
    local model=instances and instances:FindFirstChild("HatchWar");local portals=model and model:FindFirstChild("Teleports")
    local door=nil;local distance=math.huge
    if r and portals then for _,part in ipairs(portals:GetChildren())do
        if part.Name=="Enter"and part:IsA("BasePart")then local d=(r.Position-part.Position).Magnitude;if d<distance then door=part;distance=d end end
    end end
    if not r or not h or not door then M.EntryNext=os.clock()+10;return end
    M.EntryPending=true;M.EntryStatus="Входим через обычную дверь"
    M.EntryTask=task.spawn(function()
        local ok=pcall(function()
            r.CFrame=door.CFrame*CFrame.new(0,-door.Size.Y/2+3,6);r.AssemblyLinearVelocity=Vector3.zero
            h:MoveTo((door.CFrame*CFrame.new(0,-door.Size.Y/2+3,-6)).Position)
            local deadline=os.clock()+10
            repeat task.wait(.25)until not M.Alive or instancing.GetInstanceID()or os.clock()>deadline
            h:Move(Vector3.zero)
        end)
        M.EntryPending=false;M.EntryTask=nil;M.EntryNext=os.clock()+15
        M.EntryStatus=ok and instancing.GetInstanceID()=="HatchWar"and "Вход подтверждён"or "Дверь не подтвердила вход; повтор позже"
    end)
end
table.insert(M.Connections,UIS.InputBegan:Connect(function()M.LastInput=os.clock()end))
table.insert(M.Connections,UIS.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement then M.LastInput=os.clock()end
end))
function M.Stop()
    F.SetEnabled(false)
    N.SetEnabled(false)
    M.SetHideEggs(false)
    K.SetEnabled(false)
    E.Stop();M.AutoBreak=false;M.AutoDrops=false
    M.ClearLucky();M.ClearHover();M.CancelDrops();M.ReleasePets();M.SetAFK(false)
end
function M.Shutdown()
    if type(setthreadidentity)=="function"then setthreadidentity(8)end
    if not M.Alive then return end
    M.Alive=false;M.Stop()
    if M.EntryTask then pcall(task.cancel,M.EntryTask)end
    if W.Task then pcall(task.cancel,W.Task)end
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
        TabWidth=155,Size=UDim2.fromOffset(700,540),Acrylic=false,Theme="Dark",MinimizeKey=Enum.KeyCode.LeftControl})
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
        Clan=Window:AddTab({Title="Клановая битва",Icon="flag"}),
        Upgrades=Window:AddTab({Title="Прокачка",Icon="arrow-up"}),
        Webhook=Window:AddTab({Title="Вебхук",Icon="bell"}),
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
    M.ClanCard=Tabs.Clan:AddParagraph({Title="Цикл КБ · тестовая версия",Content="Выключен"})
    local clanToggle:any
    clanToggle=toggle(Tabs.Clan,"ClanCycle","Цикл клановой битвы","Последний набор питомцев на дереве, лучший выбранный x, банк удачи и бустеры. Сам не запускает босса; «Авто пламя» включается отдельно.",function(v)
        if not v then K.SetEnabled(false);return end
        if M.Restoring then K.SetEnabled(true);return end
        Window:Dialog({Title="Запустить полный цикл КБ?",Content="Расходует выбранные бустеры и запасных ивентовых питомцев. Сохраняет команду 15: Huge не отдаёт, при 15 Huge оставляет одного лучшего обычного питомца. Заблокированных и эксклюзивных не трогает. Если запаса нет — фармит питомцев. Остальная автоматика остановится.",Buttons={
            {Title="Запустить",Callback=function()K.SetEnabled(true)end},
            {Title="Отмена",Callback=function()clanToggle:SetValue(false)end}}})
    end)
    Tabs.Clan:AddSlider("ClanFill",{Title="Банк перед серией, %",Default=80,Min=10,Max=100,Rounding=0,Callback=function(v)K.FillPercent=v end})
    toggle(Tabs.Clan,"AutoFlame","Авто пламя удачи","Отдельная функция: добирает выбранный тир через босса, затем возвращает управление фарму. После окончания пламени повторяет. Использует порог удачи из вкладки «Бой».",F.SetEnabled)
    local flameTier=Tabs.Clan:AddDropdown("FlameTier",{Title="Какой тир пламени поддерживать",Values={"I","II","III"},Default=3,Multi=false})
    flameTier:OnChanged(function(v)F.Target=({I=1,II=2,III=3})[v]or 3 end)
    M.FlameCard=Tabs.Clan:AddParagraph({Title="Пламя удачи",Content="Выключено"})
    local multiplier=Tabs.Clan:AddDropdown("ClanMultiplier",{Title="Какие x яйца дерева открывать",Values={"1.25","1.5","2","2.5","3"},Default={"2","2.5","3"},Multi=true})
    multiplier:OnChanged(function(v)K.Multipliers=K.Selection(v)end)
    local boosts=Tabs.Clan:AddDropdown("ClanBoosts",{Title="Какие бустеры тратить · несколько галочек",Values={"Свеча I","Свеча II","Фонарь I","Фонарь II"},Default={"Свеча I","Свеча II","Фонарь I","Фонарь II"},Multi=true})
    boosts:OnChanged(function(v)K.Boosts=K.Selection(v)end)
    toggle(Tabs.Clan,"ClanHideHatch","Скрыть анимацию открытия","Пропускает только показ открытия. Без удаления яиц и постоянного сканирования объектов.",function(v)
        if not M.SetHideEggs(v)then K.Status="Скрытие недоступно: обычная анимация сохранена"end
    end,true)
    toggle(Tabs.Clan,"EventAutoEgg","Автооткрытие ближайшего яйца","Открывает максимум доступных яиц рядом по игровому cooldown. Не включает бустеры самостоятельно. При включённом КБ уступает управление циклу.",N.SetEnabled)
    M.EggCard=Tabs.Clan:AddParagraph({Title="Ближайшее яйцо",Content="Выключено"})
    Tabs.Clan:AddSlider("ClanBatch",{Title="Открытий до возврата за удачей",Default=3,Min=1,Max=10,Rounding=0,Callback=function(v)K.BatchLimit=v end})
    Tabs.Clan:AddSlider("ClanFarmMinutes",{Title="Фарм питомцев для тыквы, минут",Default=10,Min=1,Max=60,Rounding=0,Callback=function(v)K.FarmMinutes=v end})
    Tabs.Clan:AddParagraph({Title="Полный цикл",Content="Фарм монет → питомцы из лучшего доступного яйца дерева с последним набором (обычное яйцо — запасной вариант) → тыква и бустеры → выбранный x → банк удачи → серия КБ. При пополнении не включает бустеры; выбор x для КБ его не ограничивает. Хорошую полную тыкву сохраняет."})
    Tabs.Home:AddButton({Title="Остановить всю автоматику",Description="Окно останется открытым.",Callback=function()
        M.Stop()
        for id,option in pairs(M.Toggles)do if id~="EventFarmTP"and not string.match(id,"^Config")then option:SetValue(false)end end
    end})
    M.MinimizeButton=Tabs.Home:AddButton({Title="Свернуть окно",Description="Клавишу можно поменять в настройках.",Callback=function()Window:Minimize()end})
    Tabs.Home:AddButton({Title="Полностью закрыть скрипт",Description="Убирает окно, циклы, анти-AFK и управление питомцами.",Callback=M.Shutdown})
    Tabs.Home:AddParagraph({Title="Отдельная версия",Content="Главный хаб не изменяется. Не включай его автоматику одновременно. Скрытие пропускает только анимацию открытия, не удаляет яйца."})
    Tabs.Collect:AddButton({Title="TP к ивенту",Description="Подходит к обычной двери и входит через игровой триггер. При запуске делает это автоматически.",Callback=M.EnterEvent})
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
    toggle(Tabs.Fight,"EventBoss","Auto Boss","Лучшая зона: сам фармит рекомендованные монеты, затем ждёт выбранный процент удачи. Недостижимый порог ограничивается полным банком.",function(v)
        E.AutoBoss=v;E.BossStartNext=0;if not v and not F.NeedsBoss then E.CancelStart();if not F.Enabled then F.Release()end end
    end)
    Tabs.Fight:AddSlider("BossLuckPercent",{Title="Удача для босса, % от рекомендации",Default=100,Min=50,Max=200,Rounding=0,Callback=function(v)E.BossLuckPercent=v;E.BossStartNext=0 end})
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
        Window:Dialog({Title="Безвозвратная отдача питомцев",Content="Тыква поглощает запасных ивентовых питомцев, включая радужных. Сохраняет команду 15 (при 15 Huge — одного лучшего обычного). Заблокированных и эксклюзивных не трогает. Включить?",Buttons={
            {Title="Включить",Callback=function()if M.Alive then pumpkinApproved=true;pumpkinToggle:SetValue(true)end end},
            {Title="Отмена",Callback=function()end}}})
    end)
    M.PumpkinCard=Tabs.Pumpkin:AddParagraph({Title="Гигантская тыква",Content="Выключена"})
    Tabs.Pumpkin:AddParagraph({Title="Как работает",Content="Проверяет актуальный Spare непосредственно перед отдачей, соблюдает игровой cooldown. После открытия награды выдаёт игра; фиктивного Claim здесь нет."})
    toggle(Tabs.Upgrades,"EventUpgrade","Auto Event Upgrades","Первый выбранный до максимума. Хватает палочек → TP к машине, покупка и возврат к прежнему действию.",function(v)
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
    toggle(Tabs.Settings,"ConfigAutoSave","Автосохранение изменений","Общие настройки устройства для всех аккаунтов; отдельный Auto Pumpkin не сохраняется.",function(v)C.AutoSave=v end,true)
    toggle(Tabs.Settings,"ConfigAutoLoad","Загружать автоматически при запуске","Без вопроса восстанавливает сохранённые режимы, включая КБ. Включай только после проверки своих настроек.",function(v)C.AutoLoad=v end)
    Tabs.Settings:AddButton({Title="Сохранить текущие настройки",Callback=function()C.Save();C.Ready=true end})
    Tabs.Settings:AddButton({Title="Загрузить сохранённые настройки",Callback=function()C.Apply(C.Read())end})
    M.ConfigCard=Tabs.Settings:AddParagraph({Title="Сохранение на устройстве",Content="Файл общий для всех аккаунтов в этом executor."})
    toggle(Tabs.Webhook,"WebhookEnabled","Уведомления Discord","Только подтверждённые редкие хэтчи этого аккаунта.",function(v)W.Enabled=v;W.Status=v and "Ожидаем редкий хэтч"or "Выключен";if not v then table.clear(W.Queue)end end)
    local hook=Tabs.Webhook:AddInput("WebhookUrl",{Title="Ссылка на Discord webhook",Default="",Placeholder="https://discord.com/api/webhooks/…",Finished=true})
    hook:OnChanged(function(v)W.Url=string.gsub(tostring(v),"%s","");if W.Url~=""and not W.ValidUrl(W.Url)then W.Status="Проверь ссылку Discord webhook"end end)
    local discord=Tabs.Webhook:AddInput("WebhookDiscordID",{Title="Твой Discord ID · необязательно",Default="",Placeholder="Числовой ID для упоминания",Finished=true})
    discord:OnChanged(function(v)W.DiscordID=string.gsub(tostring(v),"%s","")end)
    local rare=Tabs.Webhook:AddDropdown("WebhookTypes",{Title="Какие выпадения отправлять",Values={"Huge","Titanic","Gargantuan"},Default={"Huge","Titanic","Gargantuan"},Multi=true})
    rare:OnChanged(function(v)W.Types=K.Selection(v)end)
    Tabs.Webhook:AddButton({Title="Выбрать все",Callback=function()rare:SetValue({Huge=true,Titanic=true,Gargantuan=true})end})
    M.WebhookCard=Tabs.Webhook:AddParagraph({Title="Статус уведомлений",Content="Выключен"})
    Tabs.Webhook:AddParagraph({Title="Важно",Content="Адрес вебхука — секрет. Сохраняется в локальном файле вместе с настройками; не передавай этот файл. В логи адрес не выводится. Discord ID не нужен для обычной отправки."})
    M.MinimizeBind=Tabs.Settings:AddKeybind("EventMinimize",{Title="Клавиша сворачивания",Description="Нажми на клавишу справа, затем на новую кнопку клавиатуры.",Mode="Toggle",Default="LeftControl"})
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
local saved=C.Read()
if saved and saved.Values.ConfigAutoLoad==true then C.Apply(saved)
elseif saved then
    M.Window:Dialog({Title="Загрузить сохранённые настройки?",Content="Настройки общие для всех аккаунтов устройства. Загрузка восстановит сохранённую автоматику. Отдельная автотыква останется выключенной.",Buttons={
        {Title="Загрузить",Callback=function()C.Apply(saved)end},
        {Title="Сохранить текущие",Callback=function()C.Save();C.Ready=true end},
        {Title="Не загружать",Callback=function()C.Ready=false;C.Status="Автосохранение приостановлено; сохранённый файл не изменён"end}}})
else C.Ready=true;C.Status="Автосохранение готово"end
table.insert(M.Connections,LP.CharacterAdded:Connect(function()
    F.Release()
    K.Cancel();if K.Enabled then K.SetPhase("Bank")end
    M.ClearLucky();M.ReleasePets();M.ClearHover();M.CancelDrops();E.CancelStart();E.CancelPumpkin();E.CancelUpgrade()
    E.NextOrb=os.clock()+3;E.BossStartNext=os.clock()+3;M.NextBreak=os.clock()+3
end))
M.Worker=task.spawn(function()
    if type(setthreadidentity)=="function"then setthreadidentity(8)end
    while M.Alive and not Fluent.Unloaded do
        local ok,err=xpcall(function()
            if type(setthreadidentity)=="function"then setthreadidentity(8)end
            M.ReopenButton.Visible=M.Window.Minimized
            C.Step();W.Step()
            if M.AutoEnter and not M.EntryPending and os.clock()>=M.EntryNext then M.EnterEvent()end
            if M.Conflict then M.SetDesc(E.Card,M.Conflict)end
            local flameBusy=F.Step()
            if not flameBusy and not M.Conflict and E.Init()then E.UpgradeStep()end
            if flameBusy then
                -- Optional controller owns movement only until the requested flame is active.
            elseif K.Enabled then K.Step()
            elseif not N.Pending then
                if not blocked()then E.ProgressStep();E.PumpkinStep()end
                E.OrbStep()
                if not M.Conflict and E.Init()then E.BossStep()end
            end
            N.Step()
            if not N.Pending then M.BreakStep();M.DropStep()end
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
                M.SetDesc(M.ConfigCard,C.Status or "Настройки не сохранены")
                M.SetDesc(M.WebhookCard,W.Status)
                M.SetDesc(M.EggCard,N.Status)
                M.SetDesc(M.FlameCard,F.Status)
                M.SetDesc(M.ClanCard,K.Status.."\n"..(K.EggStatus or "").."\n"..(K.InventoryStatus or "").."\nПринято открытий: "..K.Hatches.." · свечей: "..K.Candles.." · фонарей: "..K.Lanterns.."\nУдача: все открытые зоны, без дерева")
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


