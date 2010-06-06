scbal = {}

function scbal.initialize()
    if ( not scbal.settings ) then
        scbal.settings = {}
        scbal.settings.wantShow = true
    end
    
    scbal.orderTotal = 0
    scbal.orderHealers = 0
    scbal.destroTotal = 0
    scbal.destroHealers = 0
    scbal.nowShowing = false
    scbal.timeToUpdate = 0
    scbal.timeBetweenUpdates = 2
    scbal.test = false
    
    scbal.orderHealerCareers = {
        GetStringFromTable("CareerLinesMale",GameDefs.CAREERID_RUNE_PRIEST),
        GetStringFromTable("CareerLinesMale",GameDefs.CAREERID_WARRIOR_PRIEST),
        GetStringFromTable("CareerLinesMale",GameDefs.CAREERID_ARCHMAGE),
        GetStringFromTable("CareerLinesFemale",GameDefs.CAREERID_RUNE_PRIEST),
        GetStringFromTable("CareerLinesFemale",GameDefs.CAREERID_WARRIOR_PRIEST),
        GetStringFromTable("CareerLinesFemale",GameDefs.CAREERID_ARCHMAGE)
    }

    scbal.destroHealerCareers = {
        GetStringFromTable("CareerLinesMale",GameDefs.CAREERID_SHAMAN),
        GetStringFromTable("CareerLinesMale",GameDefs.CAREERID_ZEALOT),
        GetStringFromTable("CareerLinesMale",GameDefs.CAREERID_BLOOD_PRIEST),
        GetStringFromTable("CareerLinesFemale",GameDefs.CAREERID_SHAMAN),
        GetStringFromTable("CareerLinesFemale",GameDefs.CAREERID_ZEALOT),
        GetStringFromTable("CareerLinesFemale",GameDefs.CAREERID_BLOOD_PRIEST)
    }
    
    CreateWindow("scbal", true)
    LayoutEditor.RegisterWindow( "scbal" , L"Scenario Balance" , L"Scenario Balance Window",
                               false , false , true , nil )
    LabelSetText("scbalUs", L"10/32")
    LabelSetText("scbalThem", L"1/8")
    WindowSetShowing("scbal", false)
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
        else
            scbal.p("Usage: /scbal [on|off|test]")
            hasOpts = true
        end
    end
    if ( wantOn or not hadOpts ) then
        scbal.settings.wantShow = true
    end
    scbal.p("ScenarioBalance:   on=", scbal.settings.wantShow)
    scbal.p("ScenarioBalance: test=", scbal.test)
    scbal.showOrHide()
end

function scbal.showOrHide()
    if ( scbal.test or (scbal.settings.wantShow and scbal.inScenario()) ) then
        if ( not scbal.nowShowing ) then
            WindowSetShowing("scbal", true)
            scbal.nowShowing = true
        end
    else
        if ( scbal.nowShowing ) then
            WindowSetShowing("scbal", false)
            scbal.nowShowing = false
        end
    end
end

function scbal.inScenario()
    if ( GameData.Player.isInSiege or GameData.Player.isInScenario) then
        return true
    else
        return false
    end
end

function scbal.tickTock(elapsed)
    scbal.timeToUpdate = scbal.timeToUpdate - elapsed
    if ( scbal.timeToUpdate <= 0 ) then
        if ( scbal.inScenario() ) then
            scbal.updateCounts()
        else
            scbal.orderTotal = 0
            scbal.orderHealers = 0
            scbal.destroTotal = 0
            scbal.destroHealers = 0
        end
        scbal.updateLabels()
        scbal.showOrHide()
        scbal.timeToUpdate = scbal.timeBetweenUpdates
    end
end

function scbal.updateCounts()
    local players = GameData.GetScenarioPlayers()
    scbal.orderTotal = 0
    scbal.orderHealers = 0
    scbal.destroTotal = 0
    scbal.destroHealers = 0
    if ( players ~= nil ) then
        for key, value in ipairs(players) do
            if ( value.realm == GameData.Realm.ORDER ) then
                scbal.orderTotal = scbal.orderTotal + 1
                local incr = 1
                for i, h in pairs(scbal.orderHealerCareers) do
                    if ( WStringsCompareIgnoreGrammer(value.career, h ) == 0 ) then
                        scbal.orderHealers = scbal.orderHealers + incr
                        incr = 0
                    end
                end
            else
                scbal.destroTotal = scbal.destroTotal + 1
                local incr = 1
                for i, h in pairs(scbal.destroHealerCareers) do
                    if ( WStringsCompareIgnoreGrammer(value.career, h ) == 0 ) then
                        scbal.destroHealers = scbal.destroHealers + incr
                        incr = 0
                    end
                end
            end
        end
    end
end

function scbal.updateLabels()
    local orderNumbers = L""..scbal.orderHealers..L"/"..scbal.orderTotal
    local destroNumbers = L""..scbal.destroHealers..L"/"..scbal.destroTotal
    if ( GameData.Player.realm == GameData.Realm.DESTRUCTION ) then
        LabelSetText("scbalUs", destroNumbers)
        LabelSetText("scbalThem", orderNumbers)
    else
        LabelSetText("scbalUs", orderNumbers)
        LabelSetText("scbalThem", destroNumbers)
    end
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

