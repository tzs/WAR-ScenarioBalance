<?xml version="1.0" encoding="UTF-8"?>
<ModuleFile xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <UiMod name="ScenarioBalance" version="1.4" date="2010-07-24">
        <Author name="tzs"/>
        <Description text="Shows count of scenario players and healers in a small window"/>
        <VersionSettings gameVersion="1.3.5"/>
        <Dependencies>
            <Dependency name="EA_ChatWindow"/>
            <Dependency name="LibSlash"/>
        </Dependencies>
        <Files>
            <File name="scbal.lua"/>
            <File name="scbal.xml"/>
        </Files>
        <OnInitialize>
            <CallFunction name="scbal.initialize"/>
        </OnInitialize>
        <OnUpdate>
            <CallFunction name="scbal.tickTock"/>
        </OnUpdate>
        <OnShutdown/>
        <SavedVariables>
            <SavedVariable name="scbal.settings"/>
        </SavedVariables>
        <WARInfo>
            <Categories>
                <Category name="RVR"/>
            </Categories>
        </WARInfo>
    </UiMod>
</ModuleFile>
