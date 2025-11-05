IncludeScript("light_bridge_lights/helper.nut")

// sv_init.nut runs before entities have spawned + on every game load. wait until entities are ready before running
function scriptStart() {
    local initTimer = CreateEntityByName("logic_timer", {   // check every tick if entities have actually spawned in yet
        targetname = "lightbridgelights_canstarttimer"
        RefireTime = 0.01
    })

    initTimer.ConnectOutput("OnTimer", "scriptInit")
    EntFire("lightbridgelights_canstarttimer", "Enable")
}
function scriptInit() {   // if player exists, other entities exist
    local player = GetPlayer()
    if(player != null) {
        EntFire("lightbridgelights_canstarttimer", "Kill")    // prevent further inits

        Setup()
        if(GetDeveloperLevel() > 0) Dev.msgDeveloper("Script initialised.")
    }
}

::LIGHT_COLOUR <- Vector(63, 196, 252)  // RGB colour values - light blue
const LIGHT_BRIGHTNESS = 40
const LIGHT_D50 = 50
const LIGHT_D0 = 300
const LIGHT_SHADOWSIZE = -1 // DONT CHANGE THIS FROM -1, it just instantly overwhelms the shadow atlas (-1 = no shadows)

const LIGHT_SPACING = 20  // distance between lights in units, less spacing means more lights but a higher performance cost

bridgesCached <- [] // stores bridge handles and their entindexes
bridgeLightCountPrevious <- {}
bridgesCacheMarkedForReset <- false
const CACHE_REFRESH_TIME = 0.01

// traces used for calculating bridge length
const TRACE_DISTANCE = 8192
TRACE_MASK <- MASK_SOLID | MASK_WATER | MASK_BLOCKLOS
TRACE_COLLISION_GROUP <- COLLISION_GROUP_NONE
TRACE_BOUNDS_MIN <- Vector(-12, -12, -12)
TRACE_BOUNDS_MAX <- Vector(12, 12, 12)

function Setup() {
    Dev.msgDeveloper("Creating cache refresh timer...")
    local loopTimer = CreateEntityByName("logic_timer", {  // cache refresh timer
        RefireTime = CACHE_REFRESH_TIME
    })
    loopTimer.ConnectOutput("OnTimer", "bridgeCacheRefresh")
    bridgeCacheRefresh()  // initial cache
}

function bridgeCacheRefresh() {
    if(bridgesCacheMarkedForReset) {
        foreach(idx, data in bridgesCached) {
            local bridgeIndex = data.index
            lightRemoveAtBridge(bridgeIndex)    // prevent duplicate lights

            bridgesCached.remove(idx)   // dont attempt to remove lights at this bridge again
        }
        bridgeCacheReset()
        bridgesCacheMarkedForReset = false
    }

    foreach(data in bridgesCached) {
        local bridge = data.bridge
        local bridgeIndex = data.index

        // reset the cache if any cached bridges are invalid
        // one small problem with this is it causes all lights to respawn (hence a small flicker), but it's better than crashing

        if(!bridge.IsValid()) { 
            lightRemoveAtBridge(bridgeIndex)
            bridgesCacheMarkedForReset = true   // wait until next tick to prevent crashes
            break
        }

        local lightCountNew = bridgeGetLightCount(bridge)

        // get old light count, or use new light count if not found
        local lightCountOld = (bridgeIndex in bridgeLightCountPrevious) ? bridgeLightCountPrevious[bridgeIndex] : lightCountNew 

        // check if light count has changed
        if(lightCountNew != lightCountOld) {
            if(lightCountNew < lightCountOld) lightRemoveAtBridge(bridgeIndex, lightCountNew)    // remove lights if bridge has shrunk
            if(lightCountNew > lightCountOld) lightSpawnAtBridge(bridge, lightCountOld) // spawn additional lights
            bridgeLightCountPrevious[bridgeIndex] <- lightCountNew
        }
    }

    for(local bridge = null; bridge = Entities.FindByClassname(bridge, "projected_wall_entity");) {
        if(bridgeIsCached(bridge) || !bridge.IsValid()) continue   // skip cached bridges or invalid bridges

        // update cache with new bridge

        local bridgeIndex = bridge.entindex()

        bridgesCached.append({
            bridge = bridge,
            index = bridgeIndex
        })

        local bridgeLightCount = bridgeGetLightCount(bridge)
        bridgeLightCountPrevious[bridgeIndex] <- bridgeLightCount   // store initial lightcount in a table based on entindex() for comparison later

        lightSpawnAtBridge(bridge)
    }
}

function bridgeIsCached(bridge) {
    foreach(data in bridgesCached) {
        if(data.bridge == bridge) return true
    }
    return false
}

function bridgeCacheReset() {
    Dev.msgDeveloper("Resetting bridge cache...")
    bridgesCached <- []
    bridgeLightCountPrevious <- {}
}

function bridgeCalculateLength(bridge) {
    local pos = bridge.GetOrigin()
    local forward = bridge.GetForwardVector()
    local ray = TraceHull(pos, pos + (forward * TRACE_DISTANCE), TRACE_BOUNDS_MIN, TRACE_BOUNDS_MAX, TRACE_MASK, bridge, TRACE_COLLISION_GROUP)

    return Dev.distance(pos, ray.GetEndPos())
}

function bridgeGetLightCount(bridge) {
    local bridgeLength = bridgeCalculateLength(bridge)

    return floor(bridgeLength / LIGHT_SPACING) + 1
}

function lightSpawnAtBridge(bridge, currentLightCount = 0) {
    local bridgeLength = bridgeCalculateLength(bridge)
    local lightCount = bridgeGetLightCount(bridge)
    local bridgeIndex = bridge.entindex()

    Dev.msgDeveloper("Spawning " + (lightCount - currentLightCount) + " lights.")

    for(local i = currentLightCount; i < lightCount; i++) { // spawn lights from currentLightCount onwards
        local distance = (i * LIGHT_SPACING < bridgeLength) ? i * LIGHT_SPACING : bridgeLength  // prevent overshoot on last light
        local light = lightCreate(bridge.GetOrigin() + (bridge.GetForwardVector() * distance))

        light.SetParent(bridge)
        light.__KeyValueFromString("targetname", bridgeIndex + "_light" + i)
    }
}

function lightCreate(pos) {    // returns light handle
    local light = null

    light = CreateEntityByName("light_rt", {
        _lightmode = 3,
        spawnflags = 2
    })
    light.SetLightColor(LIGHT_COLOUR, LIGHT_BRIGHTNESS)
    light.SetLightFalloffD50D0(LIGHT_D50, LIGHT_D0)
    light.SetShadowSize(LIGHT_SHADOWSIZE)

    light.Spawn()
    light.SetOrigin(pos)

    return light
}

function lightRemoveAtBridge(bridgeIndex, numLightsToKeep = 0) { 
    Dev.msgDeveloper("Removing lights from bridgeIndex " + bridgeIndex + " starting at light index " + numLightsToKeep + ".")

    // how many lights could ever exist on this bridge given the current settings
    local numLightsPotential = (TRACE_DISTANCE / LIGHT_SPACING) 

    for(local i = numLightsToKeep; i < numLightsToKeep + numLightsPotential; i++) { // remove all lights from index numLightsToKeep onwards
        local light = Entities.FindByName(null, bridgeIndex + "_light" + i)
        if(light != null) Dev.EntFireByHandleCompressed(light, "Kill")
    }
}

scriptStart()