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

    scbal.debug = false
    scbal.timeBetweenUpdates = 5
    scbal.idleTimeout = 120
    scbal.updatePassthroughLockout = 3
    scbal.test = false
    scbal.nowShowing = false
    scbal.clock = 0
    scbal.reInitialize()

    if ( GameData.CareerLine.WITCH_ELF ~= nil ) then
        -- Game version 1.4 on the test server
        scbal.careers = {
            --order careers, tanks first, then mdps, then rdps, then healers
            GameData.CareerLine.IRON_BREAKER, GameData.CareerLine.KNIGHT, GameData.CareerLine.SWORDMASTER,
            GameData.CareerLine.SLAYER, GameData.CareerLine.WITCH_HUNTER, GameData.CareerLine.WHITE_LION,
            GameData.CareerLine.ENGINEER, GameData.CareerLine.BRIGHT_WIZARD, GameData.CareerLine.SHADOW_WARRIOR,
            GameData.CareerLine.RUNE_PRIEST, GameData.CareerLine.WARRIOR_PRIEST, GameData.CareerLine.ARCHMAGE,
            --destruction careers, same order as order careers
            GameData.CareerLine.BLACK_ORC, GameData.CareerLine.CHOSEN, GameData.CareerLine.BLACKGUARD,
            GameData.CareerLine.CHOPPA, GameData.CareerLine.MARAUDER, GameData.CareerLine.WITCH_ELF,
            GameData.CareerLine.SQUIG_HERDER, GameData.CareerLine.MAGUS, GameData.CareerLine.SORCERER,
            GameData.CareerLine.SHAMAN, GameData.CareerLine.DISCIPLE, GameData.CareerLine.ZEALOT
        }
    else
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
    end
    scbal.num_careers = #scbal.careers
    scbal.tank_end = 3   --index of last order tank in scbal.careers
    scbal.mdps_end = 6
    scbal.rdps_end = 9
    scbal.healer_end = 12
    for i=1,scbal.num_careers do
        scbal.careers[i+scbal.num_careers] = GetStringFromTable("CareerLinesFemale", scbal.careers[i])
        scbal.careers[i] = GetStringFromTable("CareerLinesMale", scbal.careers[i])
    end

    CreateWindow("scbalWin2", true)
    WindowSetShowing("scbalWin2", false)
    LabelSetText("scbalWin2Us", L"")
    LabelSetText("scbalWin2Them", L"")
    scbal.setMode(scbal.settings.mode)

    LibSlash.RegisterWSlashCmd("scbal", function(args) scbal.onSlashCmd(args) end)
    WindowRegisterEventHandler( "scbalWin2", SystemData.Events.SCENARIO_PLAYERS_LIST_STATS_UPDATED, "scbal.statsUpdated")
    LayoutEditor.RegisterWindow( "scbalWin2" , L"Scenario Balance" , L"Scenario Balance Window",
                               false , false , true , nil )
end

function scbal.reInitialize()
    scbal.orderCounts = {0,0,0,0,0}
    scbal.destroCounts = {0,0,0,0,0}
    scbal.activityScore = {}
    scbal.timeToUpdate = 0
    scbal.lastPassedOnUpdate = 0

    --unhook the scenario summary window from the update events, to combat the lag caused when
    --it processes events
    WindowUnregisterEventHandler("ScenarioSummaryWindow", SystemData.Events.SCENARIO_PLAYERS_LIST_UPDATED)
    WindowUnregisterEventHandler("ScenarioSummaryWindow", SystemData.Events.SCENARIO_PLAYERS_LIST_STATS_UPDATED)
end

function scbal.statsUpdated()
    BroadcastEvent(SystemData.Events.SCENARIO_STOP_UPDATING_PLAYERS_STATS)
    if ( WindowGetShowing("ScenarioSummaryWindow") == true ) then
        local elapsed = scbal.clock - scbal.lastPassedOnUpdate
        if ( elapsed >= scbal.updatePassthroughLockout ) then
            ScenarioSummaryWindow.OnPlayerListUpdated()
            scbal.lastPassedOnUpdate = scbal.clock
        end
    end
    if ( scbal.nowShowing == true ) then
        scbal.updateCounts()
        scbal.updateLabels()
    end
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
            scbal.p("Usage: /scbal [on|off|test|mode]")
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
            WindowSetShowing("scbalWin2", true)
            scbal.nowShowing = true
            scbal.reInitialize()
        end
    else
        if ( scbal.nowShowing ) then
            WindowSetShowing("scbalWin2", false)
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

function scbal.scenarioRunning()
    if ( GameData.Player.isInSiege ) then
        return true
    elseif ( GameData.Player.isInScenario and GameData.ScenarioData.mode ~= GameData.ScenarioMode.PRE_MODE ) then
        return true
    else
        return false
    end
end

function scbal.tickTock(elapsed)
    scbal.timeToUpdate = scbal.timeToUpdate - elapsed
    scbal.clock = scbal.clock + elapsed
    scbal.showOrHide()

    if ( scbal.timeToUpdate <= 0 ) then
        if ( scbal.inScenario() == true ) then
            if ( scbal.nowShowing == true ) then
                BroadcastEvent(SystemData.Events.SCENARIO_START_UPDATING_PLAYERS_STATS)
            end
        elseif ( scbal.test == true ) then
            scbal.statsUpdated()
        end
        scbal.timeToUpdate = scbal.timeBetweenUpdates
    end
end

function scbal.updateCounts()
    if ( scbal.test == true ) then
        if ( scbal.settings.mode == 0 ) then
            scbal.orderCounts = {12,11,10,10,43}
            scbal.destroCounts = {1,1,1,1,4}
        else
            scbal.orderCounts = {88,88,88,88,352}
            scbal.destroCounts = {1,1,1,1,4}
        end
    else
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
                        if ( score ~= scbal.activityScore[value.name].score or not scbal.scenarioRunning() ) then
                            scbal.activityScore[value.name].baseTime = scbal.clock
                            scbal.activityScore[value.name].score = score
                            if ( scbal.activityScore[value.name].tracking == false ) then
                                scbal.activityScore[value.name].tracking = true
                                if ( scbal.debug ) then scbal.p("active ",value.name," score ",score) end
                            end
                        else
                            if ( idleTime > scbal.idleTimeout ) then
                                if ( scbal.debug and scbal.activityScore[value.name].tracking == true ) then scbal.p("not counting ",value.name," idle for ",idleTime) end
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
end

function scbal.formatLine(h,r,m,t)
    local total = h + r + m + t
    local line = L"";
    line = line .. total .. L"="
    line = line .. h .. L"h "
    line = line .. r .. L"r "
    line = line .. m .. L"m "
    line = line .. t .. L"t"
    return line
end

function scbal.updateLabels()
    local orderNumbers = scbal.formatLine( scbal.orderCounts[4],
                                           scbal.orderCounts[3],
                                           scbal.orderCounts[2],
                                           scbal.orderCounts[1] )
    local destroNumbers = scbal.formatLine( scbal.destroCounts[4],
                                            scbal.destroCounts[3],
                                            scbal.destroCounts[2],
                                            scbal.destroCounts[1] )

    if ( GameData.Player.realm == GameData.Realm.DESTRUCTION ) then
        LabelSetText("scbalWin2Us", destroNumbers)
        LabelSetText("scbalWin2Them", orderNumbers)
    else
        LabelSetText("scbalWin2Us", orderNumbers)
        LabelSetText("scbalWin2Them", destroNumbers)
    end
end

function scbal.setMode(newMode)
    scbal.settings.mode = newMode
    if ( newMode == 0 ) then
        LabelSetText("scbalWin2Mode", L"Show: active")
    elseif ( newMode == 1 ) then
        LabelSetText("scbalWin2Mode", L"Show: all")
    else
        LabelSetText("scbalWin2Mode", L" unknown mode")
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
