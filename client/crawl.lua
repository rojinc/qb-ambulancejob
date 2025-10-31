-- Crawl System for KNOCKDOWN State ONLY
-- Based on: https://github.com/MadsLeander/crouch_crawl

-- Note: IsBeingRevived is a global variable defined in knockdown.lua

IsCrawling = false

-- Animation dictionaries
local idleDict = 'dead' -- Static idle on ground
local idleAnim = 'dead_d'
local crawlDict = 'move_injured_ground'
local crawlAnim = 'front_loop' -- Only use front_loop for all movement

-- Key mappings
local INPUT_MOVE_UP_ONLY = 32
local INPUT_MOVE_LEFT_ONLY = 34
local INPUT_MOVE_RIGHT_ONLY = 35

-- Load animation dictionaries
local function LoadCrawlDict()
    if not HasAnimDictLoaded(crawlDict) then
        RequestAnimDict(crawlDict)
        while not HasAnimDictLoaded(crawlDict) do
            Wait(10)
        end
    end
    if not HasAnimDictLoaded(idleDict) then
        RequestAnimDict(idleDict)
        while not HasAnimDictLoaded(idleDict) do
            Wait(10)
        end
    end
end

-- Start crawling mode
function StartCrawl()
    if not IsCrawling then
        IsCrawling = true
        LoadCrawlDict()

        local ped = PlayerPedId()
        -- Play STATIC idle animation (lying still, NO movement)
        TaskPlayAnim(ped, idleDict, idleAnim, 1.0, 1.0, -1, 1, 0, false, false, false)
    end
end

-- Stop crawling mode
function StopCrawl()
    if IsCrawling then
        IsCrawling = false
        local ped = PlayerPedId()
        ClearPedTasks(ped)
    end
end

-- Main crawl thread - ONLY active during KNOCKDOWN state (IsKnockedDown)
CreateThread(function()
    while true do
        Wait(0)

        -- Only allow crawling in KNOCKDOWN state, NOT in bleeding/dead or being revived
        if IsKnockedDown and not isDead and not isEscorted and not IsBeingRevived then
            local ped = PlayerPedId()

            -- Don't crawl in vehicles
            if not IsPedInAnyVehicle(ped, false) then
                -- Initialize crawl if not already crawling
                if not IsCrawling then
                    StartCrawl()
                end

                local isMoving = false

                -- Forward movement (W) - crawl forward
                if IsControlPressed(0, INPUT_MOVE_UP_ONLY) then
                    isMoving = true
                    if not IsEntityPlayingAnim(ped, crawlDict, crawlAnim, 3) then
                        TaskPlayAnim(ped, crawlDict, crawlAnim, 8.0, 8.0, -1, 1, 0, false, false, false)
                    end
                end

                -- If not moving, play STATIC idle animation (NO movement!)
                if not isMoving then
                    if not IsEntityPlayingAnim(ped, idleDict, idleAnim, 3) then
                        TaskPlayAnim(ped, idleDict, idleAnim, 1.0, 1.0, -1, 1, 0, false, false, false)
                    end
                end

                -- Turning left (A) - slower turn speed
                if IsControlPressed(0, INPUT_MOVE_LEFT_ONLY) then
                    local heading = GetEntityHeading(ped)
                    SetEntityHeading(ped, heading + 0.5)
                end

                -- Turning right (D) - slower turn speed
                if IsControlPressed(0, INPUT_MOVE_RIGHT_ONLY) then
                    local heading = GetEntityHeading(ped)
                    SetEntityHeading(ped, heading - 0.5)
                end

                -- Disable ALL controls, then enable only WAD, mouse, and chat
                DisableAllControlActions(0)

                -- Enable movement (WAD only, no S)
                EnableControlAction(0, INPUT_MOVE_UP_ONLY, true)    -- W
                EnableControlAction(0, INPUT_MOVE_LEFT_ONLY, true)  -- A
                EnableControlAction(0, INPUT_MOVE_RIGHT_ONLY, true) -- D

                -- Enable mouse look
                EnableControlAction(0, 1, true)  -- Camera X-axis
                EnableControlAction(0, 2, true)  -- Camera Y-axis

                -- Enable chat
                EnableControlAction(0, 245, true) -- Chat (T)
                EnableControlAction(0, 249, true) -- Push to Talk (N)
            end
        else
            -- Stop crawling if conditions change
            if IsCrawling then
                StopCrawl()
            end
            Wait(500) -- Sleep longer when not crawling
        end
    end
end)
