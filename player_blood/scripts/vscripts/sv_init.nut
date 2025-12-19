if(!("Entities" in this)) return

function PB_Init() {   // if player exists, other entities exist
    local player = GetPlayer()
    if(player != null) {
        player.__KeyValueFromString("bloodcolor", "0")  // enable blood
        if(GetDeveloperLevel() > 0) printl("[PLAYER BLOOD - DEV] Enabled player blood.")
    } else {
        printl("[PLAYER BLOOD - ERROR] Player entity not found!")
    }
}

// run the script on spawn
PB_auto <- CreateEntityByName("logic_auto", {spawnflags = 1})
PB_auto.ConnectOutput("OnNewGame", "PB_Init")