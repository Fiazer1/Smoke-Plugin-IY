local Zigarette = {
    ["PluginName"] = "Smoke that",
    ["PluginDescription"] = "Smoke this.",
    ["Commands"] = {
        ["cig"] = {
            ["ListName"] = "cig / givecig / cigarette (CLIENT R6)",
            ["Description"] = "Gives a Cigarette pack. (CLIENT R6)",
            ["Aliases"] = {"givecig","cigarette"},
            ["Function"] = function(args, speaker)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Fiazer1/Smoke-Plugin-IY/refs/heads/main/Cigs.lua"))()
            end
        },
        ["cigar"] = {
            ["ListName"] = "cigar / givecigar (CLIENT R6)",
            ["Description"] = "Gives a Cigar. (CLIENT R6)",
            ["Aliases"] = {"givecigar"},
            ["Function"] = function(args, speaker)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Fiazer1/Smoke-Plugin-IY/refs/heads/main/cigar.lua"))()
            end
        },
        ["pipe"] = {
            ["ListName"] = "pipe / givepipe (CLIENT R6)",
            ["Description"] = "Gives a smoking pipe. (CLIENT R6)",
            ["Aliases"] = {"givepipe"},
            ["Function"] = function(args, speaker)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Fiazer1/Smoke-Plugin-IY/refs/heads/main/Pipe.lua"))()
            end
        }
    }
}

return Zigarette
