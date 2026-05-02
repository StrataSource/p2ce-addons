if(!("Entities" in this)) return

IncludeScript("paintgun/helper.nut")

function PG_scriptInit() {
    if(GetPlayer() != null) {
        // check if the script has already been initialised
        if(Entities.FindByName(null, "paintgun_setupdone") != null) {
            PG_Dev.msgDeveloper("Setup has already been completed, skipping...")
            return
        } else {
            // check if paint is enabled, if not, enable it and restart the map
            if(!IsPaintEnabled()) {
                PG_Dev.msgError("Paint is not enabled! Enabling paint and restarting map...")

                local serverCommand = CreateEntityByName("point_servercommand", {})
                PG_Dev.EntFireByHandleCompressed(serverCommand, "Command", "sv_cheats 1; sv_force_enable_paint_in_map 1; restart", FrameTime())

                return
            }

            PG_GivePaintgun()

            // spawn initialisation marker entity
            local hasBeenSetupEntity = CreateEntityByName("info_target", {
                targetname = "paintgun_setupdone"
            })

            PG_Dev.msgDeveloper("Script initialised.")
        }
    } else {
        PG_Dev.msgError("Player entity not found!")
    }
}

function PG_GivePaintgun() {
    PG_Dev.msg("Giving player the paintgun...")

    // give paintgun with all paints
    UpgradePlayerPaintgun()

    // allow cubes to become visibly painted
    SendToConsole("sv_force_upgrade_weighted_cube 1")

    // kill any weapon_portalgun entities in the map
    for(local pgun = null; pgun = Entities.FindByClassname(pgun, "weapon_portalgun");) {
        PG_Dev.EntFireByHandleCompressed(pgun, "Kill")
    }
}

// override these functions to not do anything to prevent the player being given a portal gun too soon (and prevent console errors!)
function GivePlayerPortalgun() {
    PG_Dev.msg("Preventing player from receiving a portal gun...")
}
function UpgradePlayerPortalgun() {
    PG_Dev.msg("Preventing player from receiving a portal gun upgrade...")
}

PG_auto <- CreateEntityByName("logic_auto", {spawnflags = 1})
PG_auto.ConnectOutput("OnMapSpawn", "PG_scriptInit")