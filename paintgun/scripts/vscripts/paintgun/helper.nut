// table containing useful dev functions
if(!("PG_Dev" in getroottable())) {
    ::PG_Dev <- {
        function msg(msg) {
            printl("[PAINT GUN] " + msg)
        }

        function msgDeveloper(msg) {
            if(GetDeveloperLevel() > 0) printl("[PAINT GUN - DEV] " + msg)
        }

        function msgError(msg) {
            printl("[PAINT GUN - ERROR] " + msg)
        }

        function EntFireByHandleCompressed(ent, input, param = "", delay = 0.0, activator = null, caller = null) {
            if(ent != null) EntFireByHandle(ent, input, param, delay, activator, caller)
            else PG_Dev.msgDeveloper("Tried to fire null entity!")
        }
    }
}