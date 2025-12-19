if(!("Entities" in this)) return

IncludeScript("unused_turret_vo/helper.nut")

function UTV_ScriptInit() {
    if(GetPlayer() != null) {
        UTV_Init()
    } else {
        printl("[TURRET VO - ERROR] Player entity not found!")
    }
}

UTV_player <- null
UTV_turretArr <- []

UTV_turretVoBlocked <- true
UTV_turretVoBlockedCooldownTimer <- null

const UTV_TURRET_SOUNDSCRIPT_BLOCKED = "NPC_FloorTurret.TalkBlockedByBridge"    // custom - added inside unused_turret_vo.txt
const UTV_TURRET_SOUNDSCRIPT_COOLDOWN_MIN = 7
const UTV_TURRET_SOUNDSCRIPT_COOLDOWN_MAX = 10
const UTV_TURRET_SOUNDSCRIPT_PLAYCHANCE = 40    // higher number = lower chance of playing (1 in X chance)

const UTV_TURRET_MAX_TEST_DISTANCE = 1024
const UTV_TURRET_MAX_COUNT = 32   // max number of turrets to store

UTV_TURRET_TRACE_BOUNDS_MIN <- Vector(-4,-4,-4)
UTV_TURRET_TRACE_BOUNDS_MAX <- UTV_TURRET_TRACE_BOUNDS_MIN * -1
UTV_TURRET_TRACE_MASK <- MASK_SOLID
UTV_TURRET_TRACE_COLLISION_GROUP <- COLLISION_GROUP_PLAYER

// runs when entities are ready
function UTV_Init() {
    // store turret handles to prevent constant searching, one slight downfall of this is if turrets are spawned after ScriptInit, but this rarely happens in maps
    for(local turret = null; turret = Entities.FindByClassname(turret, "npc_portal_turret_floor");) {
        UTV_turretArr.append(turret)
        if(UTV_turretArr.len() >= UTV_TURRET_MAX_COUNT) break   // only store a certain number of turrets to save on performance
    }

    if(UTV_turretArr.len() == 0 || Entities.FindByClassname(null, "prop_wall_projector") == null) return  // if there are no turrets or bridges, do nothing

    UTV_player = GetPlayer()

    local loop = CreateEntityByName("logic_timer", {   // loop timer for turrets checking for the player
        RefireTime = 0.2
    })

    loop.ConnectOutput("OnTimer", "UTV_Turret_CheckForPlayerBehindBridge")
    UTV_Dev.EntFireByHandleCompressed(loop, "Enable")

    UTV_turretVoBlockedCooldownTimer = CreateEntityByName("logic_timer", {  // timer to allow turret VO again after a delay
        RefireTime = RandomInt(UTV_TURRET_SOUNDSCRIPT_COOLDOWN_MIN, UTV_TURRET_SOUNDSCRIPT_COOLDOWN_MAX)
    })

    UTV_turretVoBlockedCooldownTimer.ConnectOutput("OnTimer", "UTV_Turret_AllowBlockedVoiceLines")
    UTV_turretVoBlockedCooldownTimer.PrecacheSoundScript(UTV_TURRET_SOUNDSCRIPT_BLOCKED)    // precache needs to be ran off an entity
}

function UTV_Turret_CheckForPlayerBehindBridge() {
    if(!UTV_turretVoBlocked) return   // if delay is in progress

    local playerPos = UTV_player.GetCenter()
    local turretMaxTestDistanceSqr = UTV_TURRET_MAX_TEST_DISTANCE * UTV_TURRET_MAX_TEST_DISTANCE

    foreach(turret in UTV_turretArr) {
        // make sure script doesnt complain
        if(!turret.IsValid()) {
            UTV_Dev.arrayRemoveValue(UTV_turretArr, turret)
            continue
        }

        // remove dead turrets from list
        local turretActivity = turret.GetSequenceActivityName(turret.GetSequence())
        if(turretActivity == "ACT_FLOOR_TURRET_DIE_IDLE" || turretActivity == "ACT_FLOOR_TURRET_DIE") {
            UTV_Dev.arrayRemoveValue(UTV_turretArr, turret)
            continue
        } else if(turretActivity != "ACT_FLOOR_TURRET_CLOSED_IDLE") continue   // don't check turrets that are not closed

        local turretPos = turret.EyePosition()

        if(UTV_Dev.distanceSqr(playerPos, turretPos) <= turretMaxTestDistanceSqr) { // if turret is within range
            // check if turret is looking through a bridge
            local traceBridge = TraceHull(
                turretPos,
                turretPos + (turret.GetForwardVector() * UTV_TURRET_MAX_TEST_DISTANCE),
                UTV_TURRET_TRACE_BOUNDS_MIN,
                UTV_TURRET_TRACE_BOUNDS_MAX,
                UTV_TURRET_TRACE_MASK,
                turret,
                UTV_TURRET_TRACE_COLLISION_GROUP
            )

            if(traceBridge.DidHitNonWorldEntity()) {
                if(traceBridge.GetEntity().GetClassname() == "projected_wall_entity") {
                    // check if there is LOS between turret's center and player center (ignoring bridge)
                    local traceForPlayer = TraceHull(
                        turretPos,
                        playerPos,
                        UTV_TURRET_TRACE_BOUNDS_MIN,
                        UTV_TURRET_TRACE_BOUNDS_MAX,
                        UTV_TURRET_TRACE_MASK,
                        traceBridge.GetEntity(),
                        UTV_TURRET_TRACE_COLLISION_GROUP
                    )

                    if(traceForPlayer.DidHitNonWorldEntity()) {
                        if(traceForPlayer.GetEntity() == UTV_player) { // can play blocked voice lines
                            // check if player is behind bridge from turret's POV
                            local traceForPlayerBridge = TraceHull(
                                turretPos,
                                playerPos,
                                UTV_TURRET_TRACE_BOUNDS_MIN,
                                UTV_TURRET_TRACE_BOUNDS_MAX,
                                UTV_TURRET_TRACE_MASK,
                                turret,
                                UTV_TURRET_TRACE_COLLISION_GROUP
                            )

                            if(traceForPlayerBridge.DidHitNonWorldEntity()) {
                                if(traceForPlayerBridge.GetEntity().GetClassname() == "projected_wall_entity" && RandomInt(1,UTV_TURRET_SOUNDSCRIPT_PLAYCHANCE) == 1) {   // 1 in TURRET_SOUNDSCRIPT_PLAYCHANCE chance of playing (when permitted)
                                    turret.EmitSound(UTV_TURRET_SOUNDSCRIPT_BLOCKED)

                                    UTV_turretVoBlocked = false

                                    UTV_turretVoBlockedCooldownTimer.__KeyValueFromInt("RefireTime", RandomInt(UTV_TURRET_SOUNDSCRIPT_COOLDOWN_MIN, UTV_TURRET_SOUNDSCRIPT_COOLDOWN_MAX))
                                    UTV_Dev.EntFireByHandleCompressed(UTV_turretVoBlockedCooldownTimer, "Enable")   // enable delay
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
function UTV_Turret_AllowBlockedVoiceLines() {
    UTV_turretVoBlocked = true
    UTV_Dev.EntFireByHandleCompressed(UTV_turretVoBlockedCooldownTimer, "Disable")
}

// run the script on spawn
UTV_auto <- CreateEntityByName("logic_auto", {spawnflags = 1})
UTV_auto.ConnectOutput("OnNewGame", "UTV_ScriptInit")