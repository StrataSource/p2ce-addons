if(!("Entities" in this)) return

IncludeScript("light_bridge_lights/helper.nut")

function LBL_scriptInit() {
    if(GetPlayer() != null) {
        LBL_Setup()
        if(GetDeveloperLevel() > 0) LBL_Dev.msgDeveloper("Script initialised.")
    } else {
        printl("[LIGHT BRIDGE LIGHTS - ERROR] Player entity not found!")
    }
}

LBL_LIGHT_COLOUR <- Vector(25, 175, 255)  // RGB colour values - light blue
const LBL_LIGHT_BRIGHTNESS = 50
const LBL_LIGHT_D50 = 50
const LBL_LIGHT_D0 = 300
const LBL_LIGHT_SHADOWSIZE = -1 // DONT CHANGE THIS FROM -1, it just instantly overwhelms the shadow atlas (-1 = no shadows)
const LBL_LIGHT_VOLUMETRIC_LIGHTSCALE = 110
const LBL_LIGHT_VOLUMETRIC_DENSITY = 0.025

const LBL_LIGHT_SPACING = 24  // distance between lights in units, less spacing means more lights but a higher performance cost
const LBL_LIGHT_MAXCOUNT = 128  // maximum number of lights per bridge to prevent performance issues

const LBL_LIGHT_SPECIFIC_HEALTH = 27852 // used to identify lights created by this script

LBL_bridgesCached <- [] // stores bridge handles and their entindexes
LBL_bridgeLightCountPrevious <- {}
LBL_bridgesCacheMarkedForReset <- false
const LBL_CACHE_REFRESH_TIME = 0.01

// traces used for calculating bridge length
const LBL_TRACE_DISTANCE = 8192
LBL_TRACE_MASK <- MASK_SOLID | MASK_WATER | MASK_BLOCKLOS
LBL_TRACE_COLLISION_GROUP <- COLLISION_GROUP_NONE
LBL_TRACE_BOUNDS_MIN <- Vector(-12, -12, -12)
LBL_TRACE_BOUNDS_MAX <- Vector(12, 12, 12)

function LBL_Setup() {
    if(Entities.FindByName(null, "lightbridgelights_setupdone") != null) {
        LBL_Dev.msgDeveloper("Setup has already been completed, skipping...")
        return
    }

    LBL_Dev.msgDeveloper("Creating cache refresh timer...")
    local loopTimer = CreateEntityByName("logic_timer", {  // cache refresh timer
        RefireTime = LBL_CACHE_REFRESH_TIME
    })
    loopTimer.ConnectOutput("OnTimer", "LBL_bridgeCacheRefresh")
    LBL_bridgeCacheRefresh()  // initial cache

    local loadAuto = CreateEntityByName("logic_auto", {}) // handle loading of saves
    loadAuto.ConnectOutput("OnLoadGame", "LBL_OnLoadGame")

    local hasBeenSetupEntity = CreateEntityByName("info_target", { // dummy entity to check against to prevent multiple setups
        targetname = "lightbridgelights_setupdone"
    })
}

function LBL_OnLoadGame() {
    LBL_Dev.msgDeveloper("Load game detected, resetting lights...")

    // entindexs get messed up on load, meaning all lights need to be reset
    LBL_bridgesCacheMarkedForReset = true
    LBL_lightRemoveAll()
}

function LBL_bridgeCacheRefresh() {
    if(LBL_bridgesCacheMarkedForReset) {
        LBL_bridgeCacheReset()
        LBL_bridgesCacheMarkedForReset = false
    }

    foreach(data in LBL_bridgesCached) {
        local bridge = data.bridge
        local bridgeIndex = data.index

        // reset the cache if any cached bridges are invalid
        // one small problem with this is it causes all lights to respawn (hence a small flicker), but it's better than crashing

        if(!bridge.IsValid()) { 
            LBL_lightRemoveAtBridge(bridgeIndex)
            LBL_bridgesCacheMarkedForReset = true   // wait until next tick to prevent crashes
            break
        }

        local lightCountNew = LBL_bridgeGetLightCount(bridge)

        // get old light count, or use new light count if not found
        local lightCountOld = (bridgeIndex in LBL_bridgeLightCountPrevious) ? LBL_bridgeLightCountPrevious[bridgeIndex] : lightCountNew 

        // check if light count has changed
        if(lightCountNew != lightCountOld) {
            if(lightCountNew < lightCountOld) LBL_lightRemoveAtBridge(bridgeIndex, lightCountNew)    // remove lights if bridge has shrunk
            if(lightCountNew > lightCountOld) LBL_lightSpawnAtBridge(bridge, lightCountOld) // spawn additional lights
            LBL_bridgeLightCountPrevious[bridgeIndex] <- lightCountNew
        }
    }

    for(local bridge = null; bridge = Entities.FindByClassname(bridge, "projected_wall_entity");) {
        if(LBL_bridgeIsCached(bridge) || !bridge.IsValid()) continue   // skip cached bridges or invalid bridges

        // update cache with new bridge

        local bridgeIndex = bridge.entindex()

        LBL_bridgesCached.append({
            bridge = bridge,
            index = bridgeIndex
        })

        local bridgeLightCount = LBL_bridgeGetLightCount(bridge)
        LBL_bridgeLightCountPrevious[bridgeIndex] <- bridgeLightCount   // store initial lightcount in a table based on entindex() for comparison later

        LBL_lightSpawnAtBridge(bridge)
    }
}

function LBL_bridgeIsCached(bridge) {
    foreach(data in LBL_bridgesCached) {
        if(data.bridge == bridge) return true
    }
    return false
}

function LBL_bridgeCacheReset() {
    LBL_Dev.msgDeveloper("Resetting bridge cache...")

    foreach(idx, data in LBL_bridgesCached) {
        local bridgeIndex = data.index
        LBL_lightRemoveAtBridge(bridgeIndex)    // prevent duplicate lights

        LBL_bridgesCached.remove(idx)   // dont attempt to remove lights at this bridge again
    }

    LBL_bridgesCached <- []
    LBL_bridgeLightCountPrevious <- {}
}

function LBL_bridgeCalculateLength(bridge) {
    local pos = bridge.GetOrigin()
    local forward = bridge.GetForwardVector()
    local ray = TraceHull(pos, pos + (forward * LBL_TRACE_DISTANCE), LBL_TRACE_BOUNDS_MIN, LBL_TRACE_BOUNDS_MAX, LBL_TRACE_MASK, bridge, LBL_TRACE_COLLISION_GROUP)

    return LBL_Dev.distance(pos, ray.GetEndPos())
}

function LBL_bridgeGetLightCount(bridge) {
    local bridgeLength = LBL_bridgeCalculateLength(bridge)

    return floor(bridgeLength / LBL_LIGHT_SPACING) + 1
}

function LBL_lightSpawnAtBridge(bridge, currentLightCount = 0) {
    local bridgeLength = LBL_bridgeCalculateLength(bridge)

    local lightCount = LBL_bridgeGetLightCount(bridge)
    if(lightCount > LBL_LIGHT_MAXCOUNT) lightCount = LBL_LIGHT_MAXCOUNT  // cap light count to prevent performance issues

    local bridgeIndex = bridge.entindex()

    LBL_Dev.msgDeveloper("Spawning " + (lightCount - currentLightCount) + " lights.")

    for(local i = currentLightCount; i < lightCount; i++) { // spawn lights from currentLightCount onwards
        local distance = (i * LBL_LIGHT_SPACING < bridgeLength) ? i * LBL_LIGHT_SPACING : bridgeLength  // prevent overshoot on last light
        local light = LBL_lightCreate(bridge.GetOrigin() + (bridge.GetForwardVector() * distance))

        light.SetParent(bridge)
        light.__KeyValueFromString("targetname", bridgeIndex + "_light" + i)
    }
}

function LBL_lightCreate(pos) {    // returns light handle
    local light = null

    light = CreateEntityByName("light_rt", {
        _specularmode = 0,
        _indirectmode = 0,
        _directmode = 2,
        spawnflags = 2
    })
    light.SetLightColor(LBL_LIGHT_COLOUR, LBL_LIGHT_BRIGHTNESS)
    light.SetLightFalloffD50D0(LBL_LIGHT_D50, LBL_LIGHT_D0)
    light.SetShadowSize(LBL_LIGHT_SHADOWSIZE)

    light.Spawn()
    light.SetOrigin(pos)

    light.__KeyValueFromInt("max_health", LBL_LIGHT_SPECIFIC_HEALTH) // needed to detect light entities later

    // needs adding like this for whatever reason
    LBL_Dev.EntFireByHandleCompressed(light, "AddOutput", "_volumetricmode 2")
    LBL_Dev.EntFireByHandleCompressed(light, "SetVolumetricLightScale", LBL_LIGHT_VOLUMETRIC_LIGHTSCALE.tostring())
    LBL_Dev.EntFireByHandleCompressed(light, "SetVolumetricDensity", LBL_LIGHT_VOLUMETRIC_DENSITY.tostring())

    return light
}

function LBL_lightRemoveAtBridge(bridgeIndex, numLightsToKeep = 0) { 
    LBL_Dev.msgDeveloper("Removing lights from bridgeIndex " + bridgeIndex + " starting at light index " + numLightsToKeep + ".")

    // how many lights could ever exist on this bridge given the current settings
    local numLightsPotential = (LBL_TRACE_DISTANCE / LBL_LIGHT_SPACING) 

    for(local i = numLightsToKeep; i < numLightsToKeep + numLightsPotential; i++) { // remove all lights from index numLightsToKeep onwards
        local light = Entities.FindByName(null, bridgeIndex + "_light" + i)
        if(light != null) LBL_Dev.EntFireByHandleCompressed(light, "Kill")
    }
}

function LBL_lightRemoveAll() {
    LBL_Dev.msgDeveloper("Removing all bridge lights...")

    for(local light = null; light = Entities.FindByClassname(light, "light_rt");) {
        if(light.GetMaxHealth() == LBL_LIGHT_SPECIFIC_HEALTH) { // only remove lights created by this script
            LBL_Dev.EntFireByHandleCompressed(light, "Kill")
        }
    }

    LBL_bridgeCacheReset()
}

LBL_auto <- CreateEntityByName("logic_auto", {spawnflags = 1})
LBL_auto.ConnectOutput("OnMapSpawn", "LBL_scriptInit")