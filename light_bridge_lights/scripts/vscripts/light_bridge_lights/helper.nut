// table containing useful dev functions
if(!("LBL_Dev" in getroottable())) {
    ::LBL_Dev <- {
        function msg(msg) {
            printl("[LIGHT BRIDGE LIGHTS] " + msg)
        }

        function msgDeveloper(msg) {
            if(GetDeveloperLevel() > 0) printl("[LIGHT BRIDGE LIGHTS - DEV] " + msg)
        }

        function EntFireByHandleCompressed(ent, input, param = "", delay = 0.0, activator = null, caller = null) {
            if(ent != null) EntFireByHandle(ent, input, param, delay, activator, caller)
            else Dev.msgDeveloper("Tried to fire null entity!")
        }

        function distance(vec1, vec2) {
            return (vec1 - vec2).Length()
        }
    }
}