// table containing useful dev functions
if(!("Dev" in getroottable())) {
    ::Dev <- {
        function msg(msg) {
            printl("[UNUSED TURRET VO] " + msg)
        }

        function msgDeveloper(msg) {
            if(GetDeveloperLevel() > 0) printl("[UNUSED TURRET VO - DEV] " + msg)
        }

        function EntFireByHandleCompressed(ent, input, param = "", delay = 0.0, activator = null, caller = null) {
            if(ent != null) EntFireByHandle(ent, input, param, delay, activator, caller)
            else Dev.msgDeveloper("Tried to fire null entity!")
        }

        function distanceSqr(vec1, vec2) {
            return (vec1 - vec2).LengthSqr()
        }

        function arrayRemoveValue(arr, valToRemove) {
            foreach(idx, val in arr) {
                if(val == valToRemove) {
                    arr.remove(idx)
                    return
                }
            }
        }
    }
}