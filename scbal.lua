scbal = {}

function scbal.initialize()
    if ( not scbal.settings ) then
        scbal.settings = {}
        scbal.settings.wantShow = true
    end

    --settings added after initial release have to be handled individually
    --so that users who have old versions will have get them
    if ( scbal.settings.mode == nil ) then
        scbal.settings.mode = 0     --0 == show active, 1 == show all
    end

    if ( not scbal.debug ) then
        scbal.debug = false
    end
    
    scbal.orderCounts = {0,0,0,0,0}
    scbal.destroCounts = {0,0,0,0,0}
    scbal.activityScore = {}
    scbal.clock = 0
    scbal.needStop = false
    
    scbal.nowShowing = false
    scbal.timeToUpdate = 0
    scbal.timeBetweenUpdates = 4
    scbal.idleTimeout = 120
    scbal.test = false
    scbal.ignoreIdlePlayers = true
    
    scbal.careers = {
        --order careers, tanks first, then mdps, then rdps, then healers
        GameDefs.CAREERID_IRON_BREAKER, GameDefs.CAREERID_SWORDMASTER, GameDefs.CAREERID_KNIGHT,
        GameDefs.CAREERID_SLAYER, GameDefs.CAREERID_WITCH_HUNTER, GameDefs.CAREERID_SEER,
        GameDefs.CAREERID_ENGINEER, GameDefs.CAREERID_BRIGHT_WIZARD, GameDefs.CAREERID_SHADOW_WARRIOR,
        GameDefs.CAREERID_WARRIOR_PRIEST, GameDefs.CAREERID_ARCHMAGE, GameDefs.CAREERID_RUNE_PRIEST,
        --destruction careers, same order as order careers
        GameDefs.CAREERID_BLACKORC, GameDefs.CAREERID_CHOSEN, GameDefs.CAREERID_SHADE,
        GameDefs.CAREERID_ASSASSIN, GameDefs.CAREERID_CHOPPA, GameDefs.CAREERID_WARRIOR,
        GameDefs.CAREERID_SQUIG_HERDER, GameDefs.CAREERID_MAGUS, GameDefs.CAREERID_SORCERER,
        GameDefs.CAREERID_SHAMAN, GameDefs.CAREERID_ZEALOT, GameDefs.CAREERID_BLOOD_PRIEST
    }
    scbal.num_careers = #scbal.careers
    scbal.tank_end = 3   --index of last order tank in scbal.careers
    scbal.mdps_end = 6
    scbal.rdps_end = 9
    scbal.healer_end = 12
    for i=1,scbal.num_careers do
        scbal.careers[i+scbal.num_careers] = GetStringFromTable("CareerLinesFemale", scbal.careers[i])
        scbal.careers[i] = GetStringFromTable("CareerLinesMale", scbal.careers[i])
    end
    
    CreateWindow("scbalWin", true)
    LayoutEditor.RegisterWindow( "scbalWin" , L"Scenario Balance" , L"Scenario Balance Window",
                               false , false , true , nil )
    LabelSetText("scbalWinUs", L"")
    LabelSetText("scbalWinThem", L"")
    scbal.setMode(scbal.settings.mode)
    WindowSetShowing("scbalWin", false)
    scbal.showOrHide()
    LibSlash.RegisterWSlashCmd("scbal", function(args) scbal.onSlashCmd(args) end)
end

function scbal.onSlashCmd(args)
    local wantOn = false
    local hadOpts = false
    for i, opt in ipairs(scbal.words(WStringToString(args))) do
        if ( opt == "on" ) then
            wantOn = true
        elseif ( opt == "off" ) then
            scbal.settings.wantShow = false
            hadOpts = true
        elseif ( opt == "test" ) then
            scbal.test = not scbal.test
            hadOpts = true
        elseif ( opt == "mode" ) then
            scbal.setMode(1-scbal.settings.mode)
            hasOpts = true
        else
            scbal.p("Usage: /scbal [on|off|test]")
            hasOpts = true
        end
    end
    if ( wantOn or not hadOpts ) then
        scbal.settings.wantShow = true
    end
    scbal.p("ScenarioBalance:   on=", scbal.settings.wantShow)
    scbal.p("ScenarioBalance: mode=", scbal.settings.mode)
    scbal.p("ScenarioBalance: test=", scbal.test)
    scbal.showOrHide()
end

function scbal.showOrHide()
    if ( scbal.test or (scbal.settings.wantShow and scbal.inScenario()) ) then
        if ( not scbal.nowShowing ) then
            WindowSetShowing("scbalWin", true)
            scbal.nowShowing = true
        end
    else
        if ( scbal.nowShowing ) then
            WindowSetShowing("scbalWin", false)
            scbal.nowShowing = false
        end
    end
end

function scbal.inScenario()
    if ( GameData.Player.isInSiege or GameData.Player.isInScenario) then
        scbal.test = false
        return true
    else
        return false
    end
end

function scbal.tickTock(elapsed)
    scbal.timeToUpdate = scbal.timeToUpdate - elapsed
    scbal.clock = scbal.clock + elapsed
    if ( scbal.timeToUpdate <= 0 ) then
        if ( scbal.inScenario() ) then
            -- make sure stats are getting updated
            -- need to do this periodically because opening and closing the scenario
            -- summary window will stop updates
            BroadcastEvent( SystemData.Events.SCENARIO_START_UPDATING_PLAYERS_STATS)
            scbal.needStop = true
            scbal.updateCounts()
        else
            if ( scbal.needStop ) then
                BroadcastEvent( SystemData.Events.SCENARIO_STOP_UPDATING_PLAYERS_STATS )
                scbal.needStop = false
            end
            scbal.orderCounts = {0,0,0,0,0}
            scbal.destroCounts = {0,0,0,0,0}
        end
        scbal.updateLabels()
        scbal.showOrHide()
        scbal.timeToUpdate = scbal.timeBetweenUpdates
    end
end

function scbal.updateCounts()
    local players = GameData.GetScenarioPlayers()
    scbal.orderCounts = {0,0,0,0,0}
    scbal.destroCounts = {0,0,0,0,0}

    if ( players ~= nil ) then
        for key, value in ipairs(players) do
            if ( value.name ~= L"" ) then
                local score =  value.deaths + value.damagedealt + value.healingdealt + value.solokills + value.groupkills
                    + value.renown + value.deathblows + value.renownbonus + value.experience + value.experiencebonus
                if ( scbal.activityScore[value.name] == nil ) then
                    scbal.activityScore[value.name] = {}
                    scbal.activityScore[value.name].baseTime = scbal.clock
                    scbal.activityScore[value.name].score = score
                    scbal.activityScore[value.name].tracking = true
                    if ( scbal.debug ) then scbal.p("init tracking for ", value.name) end
                else
                    local idleTime = scbal.clock - scbal.activityScore[value.name].baseTime
                    if ( score ~= scbal.activityScore[value.name].score
                      or GameData.ScenarioData.mode ~= GameData.ScenarioMode.RUNNING ) then
                        scbal.activityScore[value.name].baseTime = scbal.clock
                        scbal.activityScore[value.name].score = score
                        if ( scbal.activityScore[value.name].tracking == false ) then
                            scbal.activityScore[value.name].tracking = true
                            if ( scbal.debug ) then scbal.p("active ",value.name," score ",score) end
                        end
                    else
                        if ( idleTime > scbal.idleTimeout ) then
                            if ( scbal.debug ) then scbal.p("not counting ",value.name," idle for ",idleTime) end
                            scbal.activityScore[value.name].tracking = false
                        end
                    end
                end
                if ( scbal.activityScore[value.name].tracking == true or scbal.settings.mode == 1 ) then
                    local archetype = scbal.careerNameToArchetype(value.career)            
                    if ( value.realm == GameData.Realm.ORDER ) then
                        scbal.orderCounts[archetype] = scbal.orderCounts[archetype] + 1
                        scbal.orderCounts[5] = scbal.orderCounts[5] + 1
                    else
                        scbal.destroCounts[archetype] = scbal.destroCounts[archetype] + 1
                        scbal.destroCounts[5] = scbal.destroCounts[5] + 1
                    end
                end
            end
        end
    end
end

function scbal.updateLabels()
    if (scbal.test == true ) then
        if ( scbal.settings.mode == 0 ) then
            scbal.orderCounts = {12,11,10,10,43}
            scbal.destroCounts = {1,1,1,1,4}
        else
            scbal.orderCounts = {12,12,12,12,48}
            scbal.destroCounts = {1,1,1,1,4}
        end
    end
    local orderNumbers = L"" .. scbal.orderCounts[5]
                    .. L"=" .. scbal.orderCounts[4]
                    .. L"+" .. scbal.orderCounts[3]
                    .. L"+" .. scbal.orderCounts[2]
                    .. L"+" .. scbal.orderCounts[1]
    local destroNumbers = L"" .. scbal.destroCounts[5]
                    .. L"=" .. scbal.destroCounts[4]
                    .. L"+" .. scbal.destroCounts[3]
                    .. L"+" .. scbal.destroCounts[2]
                    .. L"+" .. scbal.destroCounts[1]
                    
    if ( GameData.Player.realm == GameData.Realm.DESTRUCTION ) then
        LabelSetText("scbalWinUs", destroNumbers)
        LabelSetText("scbalWinThem", orderNumbers)
    else
        LabelSetText("scbalWinUs", orderNumbers)
        LabelSetText("scbalWinThem", destroNumbers)
    end
end

function scbal.setMode(newMode)
    scbal.settings.mode = newMode
    if ( newMode == 0 ) then
        LabelSetText("scbalWinMode", L"Show: active")
    elseif ( newMode == 1 ) then
        LabelSetText("scbalWinMode", L"Show: all")
    else
        LabelSetText("scbalWinMode", L" unknown mode")
    end
end

function scbal.changeMode()
    scbal.setMode(1-scbal.settings.mode)
    scbal.updateCounts()
    scbal.updateLabels()
end


function scbal.p(...)
    local out = L""
    for i, part in ipairs(arg) do
        if ( type(part) == "wstring" ) then
            out = out .. part
        elseif ( type(part) == "boolean" ) then
            if ( part == true ) then out = out .. L"true"
            else out = out .. L"false" end
        else
            out = out .. towstring(""..part)
        end
    end
    --output to the SYSTEM GENERAL channel, which is where /who goes
    --in 1.3.5. There doesn't seem to be a name for this in SystemData.ChatLogFilters
    --which is why I'm using the absolute number, 2000
    EA_ChatWindow.Print(out, ChatSettings.Channels[2000].id)
end

function scbal.words(str)
  local t = {}
  local function helper(word) table.insert(t, word) return "" end
  if not str:gsub("[^%s]+", helper):find"%S" then return t end
end

function scbal.careerNameToArchetype(career)
    local classindex = 0
    for i = 1, 2*scbal.num_careers do
        if ( WStringsCompareIgnoreGrammer(career, scbal.careers[i]) == 0 ) then
            classindex = i
            break
        end
    end
    if ( classindex > scbal.num_careers ) then classindex = classindex - scbal.num_careers end
    if ( classindex > scbal.num_careers/2 ) then classindex = classindex - scbal.num_careers/2 end
    if ( classindex <= scbal.tank_end ) then
        return 1
    elseif ( classindex <= scbal.mdps_end ) then
        return 2
    elseif ( classindex <= scbal.rdps_end ) then
        return 3
    else
        return 4
    end
end
