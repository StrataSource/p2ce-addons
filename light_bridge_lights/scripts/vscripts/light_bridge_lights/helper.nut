// table containing useful dev functions
if(!("Dev" in getroottable())) {
    ::Dev <- {
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

// useful array functions
if(!("ArrExtended" in getroottable())) {
    ::ArrExtended <- {
        function Find(arr, val) {
            foreach(item in arr) {
                if(item == val) return true
            }
            return false
        }

        function printArray(arr, name = "array") {
            if(arr == null) {
                Dev.msgDeveloper(name + " is null")
                return
            }

            Dev.msgDeveloper("Contents of " + name + ":")
            foreach(idx, val in arr) {
                Dev.msgDeveloper("  [" + idx + "] = " + val + "\n")
            }
        }
    }
}