IncludeScript("unused_turret_vo/helper.nut")

// sv_init.nut runs before entities have spawned, wait until entities are ready
function ScriptInit() {
    local canStartTimer = CreateEntityByName("logic_timer", {   // check every tick if entities have actually spawned in yet
        targetname = "unusedturretvo_canstarttimer"
        RefireTime = 0.01
    })
    
    canStartTimer.ConnectOutput("OnTimer", "ScriptInit_CheckForStart")
    Dev.EntFireByHandleCompressed(canStartTimer, "Enable")
}
function ScriptInit_CheckForStart() {   // if player exists, other entities exist
    if(GetPlayer() != null) {
        EntFire("unusedturretvo_canstarttimer", "Kill")
        Init()
    }
}

player <- null
turretArr <- []

turretVoBlocked <- true
turretVoBlockedCooldownTimer <- null

const TURRET_SOUNDSCRIPT_BLOCKED = "NPC_FloorTurret.TalkBlockedByBridge"    // custom - added inside unused_turret_vo.txt
const TURRET_SOUNDSCRIPT_COOLDOWN_MIN = 7
const TURRET_SOUNDSCRIPT_COOLDOWN_MAX = 10
const TURRET_SOUNDSCRIPT_PLAYCHANCE = 40    // higher number = lower chance of playing (1 in X chance)

const TURRET_MAX_TEST_DISTANCE = 1024
const TURRET_MAX_COUNT = 32   // max number of turrets to store

TURRET_TRACE_BOUNDS_MIN <- Vector(-4,-4,-4)
TURRET_TRACE_BOUNDS_MAX <- TURRET_TRACE_BOUNDS_MIN * -1
TURRET_TRACE_MASK <- MASK_SOLID
TURRET_TRACE_COLLISION_GROUP <- COLLISION_GROUP_PLAYER

// runs when entities are ready
function Init() {
    // store turret handles to prevent constant searching, one slight downfall of this is if turrets are spawned after ScriptInit, but this rarely happens in maps
    for(local turret = null; turret = Entities.FindByClassname(turret, "npc_portal_turret_floor");) {
        turretArr.append(turret)
        if(turretArr.len() >= TURRET_MAX_COUNT) break   // only store a certain number of turrets to save on performance
    }

    if(turretArr.len() == 0 || Entities.FindByClassname(null, "prop_wall_projector") == null) return  // if there are no turrets or bridges, do nothing

    player = GetPlayer()

    local loop = CreateEntityByName("logic_timer", {   // loop timer for turrets checking for the player
        RefireTime = 0.2
    })

    loop.ConnectOutput("OnTimer", "Turret_CheckForPlayerBehindBridge")
    Dev.EntFireByHandleCompressed(loop, "Enable")

    turretVoBlockedCooldownTimer = CreateEntityByName("logic_timer", {  // timer to allow turret VO again after a delay
        RefireTime = RandomInt(TURRET_SOUNDSCRIPT_COOLDOWN_MIN, TURRET_SOUNDSCRIPT_COOLDOWN_MAX)
    })

    turretVoBlockedCooldownTimer.ConnectOutput("OnTimer", "Turret_AllowBlockedVoiceLines")
    turretVoBlockedCooldownTimer.PrecacheSoundScript(TURRET_SOUNDSCRIPT_BLOCKED)    // precache needs to be ran off an entity
}

function Turret_CheckForPlayerBehindBridge() {
    if(!turretVoBlocked) return   // if delay is in progress

    local playerPos = player.GetCenter()
    local turretMaxTestDistanceSqr = TURRET_MAX_TEST_DISTANCE * TURRET_MAX_TEST_DISTANCE

    foreach(turret in turretArr) {
        // make sure script doesnt complain
        if(!turret.IsValid()) {
            Dev.arrayRemoveValue(turretArr, turret)
            continue
        }

        // remove dead turrets from list
        local turretActivity = turret.GetSequenceActivityName(turret.GetSequence())
        if(turretActivity == "ACT_FLOOR_TURRET_DIE_IDLE" || turretActivity == "ACT_FLOOR_TURRET_DIE") {
            Dev.arrayRemoveValue(turretArr, turret)
            continue
        } else if(turretActivity != "ACT_FLOOR_TURRET_CLOSED_IDLE") continue   // don't check turrets that are not closed

        local turretPos = turret.EyePosition()

        if(Dev.distanceSqr(playerPos, turretPos) <= turretMaxTestDistanceSqr) { // if turret is within range
            // check if turret is looking through a bridge
            local traceBridge = TraceHull(
                turretPos,
                turretPos + (turret.GetForwardVector() * TURRET_MAX_TEST_DISTANCE),
                TURRET_TRACE_BOUNDS_MIN,
                TURRET_TRACE_BOUNDS_MAX,
                TURRET_TRACE_MASK,
                turret,
                TURRET_TRACE_COLLISION_GROUP
            )

            if(traceBridge.DidHitNonWorldEntity()) {
                if(traceBridge.GetEntity().GetClassname() == "projected_wall_entity") {
                    // check if there is LOS between turret's center and player center (ignoring bridge)
                    local traceForPlayer = TraceHull(
                        turretPos,
                        playerPos,
                        TURRET_TRACE_BOUNDS_MIN,
                        TURRET_TRACE_BOUNDS_MAX,
                        TURRET_TRACE_MASK,
                        traceBridge.GetEntity(),
                        TURRET_TRACE_COLLISION_GROUP
                    )

                    if(traceForPlayer.DidHitNonWorldEntity()) {
                        if(traceForPlayer.GetEntity() == player) { // can play blocked voice lines
                            // check if player is behind bridge from turret's POV
                            local traceForPlayerBridge = TraceHull(
                                turretPos,
                                playerPos,
                                TURRET_TRACE_BOUNDS_MIN,
                                TURRET_TRACE_BOUNDS_MAX,
                                TURRET_TRACE_MASK,
                                turret,
                                TURRET_TRACE_COLLISION_GROUP
                            )

                            if(traceForPlayerBridge.DidHitNonWorldEntity()) {
                                if(traceForPlayerBridge.GetEntity().GetClassname() == "projected_wall_entity" && RandomInt(1,TURRET_SOUNDSCRIPT_PLAYCHANCE) == 1) {   // 1 in TURRET_SOUNDSCRIPT_PLAYCHANCE chance of playing (when permitted)
                                    turret.EmitSound(TURRET_SOUNDSCRIPT_BLOCKED)

                                    turretVoBlocked = false

                                    turretVoBlockedCooldownTimer.__KeyValueFromInt("RefireTime", RandomInt(TURRET_SOUNDSCRIPT_COOLDOWN_MIN, TURRET_SOUNDSCRIPT_COOLDOWN_MAX))
                                    Dev.EntFireByHandleCompressed(turretVoBlockedCooldownTimer, "Enable")   // enable delay
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// re-enable ability to play voice lines once delay is up
function Turret_AllowBlockedVoiceLines() {
    turretVoBlocked = true
    Dev.EntFireByHandleCompressed(turretVoBlockedCooldownTimer, "Disable")
}

// run the script
ScriptInit()