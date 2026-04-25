local REPO_BASES = {
    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/main/",
    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/",
}

local function fetch(path, expectReturn)
    local errors = {}
    for _, base in ipairs(REPO_BASES) do
        local url = base .. path .. "?t=" .. tick()
        local ok, result = pcall(function()
            local src = game:HttpGet(url)
            if type(src) ~= "string" or src == "" then
                error("empty response")
            end
            local lowered = string.lower(src)
            if lowered:find("404: not found", 1, true) or lowered:find("<html", 1, true) then
                error("http body is not lua (likely 404)")
            end
            local chunk, compileErr = loadstring(src)
            if not chunk then
                error("compile failed: " .. tostring(compileErr))
            end

            local value = chunk()
            if expectReturn and value == nil then
                error("module returned nil")
            end
            return value
        end)

        if ok then
            return result
        end
        table.insert(errors, string.format("%s -> %s", url, tostring(result)))
    end

    error("FarmV2 > [fatal] failed loading " .. path .. ":\n- " .. table.concat(errors, "\n- "))
end

local function fetchOptional(path, expectReturn)
    local ok, result = pcall(fetch, path, expectReturn)
    if ok then
        return result
    end
    warn("FarmV2 > [warn] optional module load failed for " .. path .. ": " .. tostring(result))
    return nil
end

local LoaderUI = fetchOptional("ui/loader.lua", true)
local ui = nil
if LoaderUI then ui = LoaderUI.show() end
local function step(perc, text) if ui then ui.update(perc, text) end end

step(0.5, "loading main script...")
fetch("main.lua", false)

step(1.0, "done")
if ui then ui.finish() end
