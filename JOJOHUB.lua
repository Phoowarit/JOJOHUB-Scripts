local scripts = {
    [78490532994307] = {
        name = "Build An Ant Empire",
        url = "https://raw.githubusercontent.com/Phoowarit/JOJOHUB-Scripts/main/games/Build%20An%20Ant%20Empire/Build%20An%20Ant%20Empire.lua",
    },
    [113290951185459] = {
        name = "Anime Dice",
        url = "https://raw.githubusercontent.com/Phoowarit/JOJOHUB-Scripts/main/games/Anime%20Dice/Anime_Dice.lua",
    },
}

local selectedScript = scripts[game.PlaceId]
if not selectedScript then
    error("[JOJOHUB] Unsupported PlaceId: " .. tostring(game.PlaceId), 0)
end

local downloaded, source = pcall(function()
    return game:HttpGet(selectedScript.url)
end)
if not downloaded then
    error("[JOJOHUB] Failed to download " .. selectedScript.name .. " script: " .. tostring(source), 0)
end
if type(source) ~= "string" or source == "" then
    error("[JOJOHUB] Downloaded script for " .. selectedScript.name .. " is empty or invalid.", 0)
end

if type(loadstring) ~= "function" then
    error("[JOJOHUB] loadstring is unavailable in this environment.", 0)
end

local runScript, compileError = loadstring(source)
if not runScript then
    error("[JOJOHUB] Failed to compile " .. selectedScript.name .. " script: " .. tostring(compileError), 0)
end

local ran, runtimeError = pcall(runScript)
if not ran then
    error("[JOJOHUB] " .. selectedScript.name .. " script failed: " .. tostring(runtimeError), 0)
end
