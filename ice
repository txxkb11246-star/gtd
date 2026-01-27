local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local player = Players.LocalPlayer

-- [[ 1. CONFIG: พิกัดทั้งหมด ]] --
local DATA = {
    P1 = {
        pos  = Vector3.new(109.221, 1.244, -94.994),
        dist = 8.628,
        cf   = CFrame.new(109.221, 1.244, -94.994, 0.9242, 0, -0.3819, 0, 1, 0, 0.3819, 0, 0.9242)
    },
    P2 = {
        pos  = Vector3.new(111.705, 1.244, 108.034),
        dist = 9.182,
        cf   = CFrame.new(111.705, 1.244, 108.034, -0.9242, 0, -0.3819, 0, 1, 0, 0.3819, 0, -0.9242)
    },
    P3 = {
        pos  = Vector3.new(-104.770, 1.244, 91.557),
        dist = 6.353,
        cf   = CFrame.new(-104.770, 1.244, 91.557, -0.3819, 0, 0.9242, 0, 1, 0, -0.9242, 0, -0.3819)
    },
    P4_NEW = {
        pos  = Vector3.new(-81.38597106933594, 1.2441591024398804, -73.91551208496094),
        dist = 66.99934850479427,
        cf   = CFrame.new(-81.38597106933594, 1.2441591024398804, -73.91551208496094,
            0.9802873730659485, 0, -0.19757729768753052,
            0, 1, 0,
            0.1975773125886917, 0, 0.9802873134613037)
    },
    P4_OLD = {
        pos  = Vector3.new(-80.16621398925781, 1.244499921798706, -123.14163970947266),
        dist = 9.321658884556506,
        cf   = CFrame.new(-80.16621398925781, 1.244499921798706, -123.14163970947266,
            0.37922346591949463, 0, 0.9253050684928894,
            0, 1, 0,
            -0.925305187702179, 0, 0.37922340631484985)
    }
}

-- [[ 2. REAL-TIME GAME SPEED DETECTOR ]] --

local SPEED_X3_COLOR = Color3.fromRGB(115, 230, 0)
local SPEED_X2_COLOR = Color3.fromRGB(166, 166, 166)

local GAME_SPEED = 2
local speedConn

local function updateSpeed(color)
    local old = GAME_SPEED
    if color == SPEED_X3_COLOR then
        GAME_SPEED = 3
    elseif color == SPEED_X2_COLOR then
        GAME_SPEED = 2
    end
    if old ~= GAME_SPEED then
        print("⚡ Game Speed Changed: x" .. GAME_SPEED)
    end
end

local function startSpeedListener()
    task.spawn(function()
        local gui = player:WaitForChild("PlayerGui"):WaitForChild("GameGuiNoInset", 20)
        if not gui then return end

        local item3 =
            gui.Screen.Top.WaveControls.TickSpeed.Items:WaitForChild("3", 20)
        if not item3 then return end

        updateSpeed(item3.ImageColor3)

        if speedConn then speedConn:Disconnect() end
        speedConn = item3:GetPropertyChangedSignal("ImageColor3"):Connect(function()
            updateSpeed(item3.ImageColor3)
        end)
    end)
end

-- ค่าเดิมออกแบบมาสำหรับ x2
local function scaledWait(t)
    return t * (2 / GAME_SPEED)
end

-- [[ 3. SYSTEM FUNCTIONS ]] --

local forceRestart = false
local hpConnection = nil

local function again()
    pcall(function()
        print("🔄 Restarting Game...")
        RemoteFunctions.RestartGame:InvokeServer()
    end)
end

local function cleanup()
    forceRestart = false
    if hpConnection then
        hpConnection:Disconnect()
        hpConnection = nil
    end
    if speedConn then
        speedConn:Disconnect()
        speedConn = nil
    end
    print("🧹 Cleanup complete.")
end

local function monitorBaseHP()
    task.spawn(function()
        local map = Workspace:WaitForChild("Map", 60)
        if not map then return end

        local baseHP = map:WaitForChild("BaseHP", 60)
        if not baseHP then return end

        local function checkHP(val)
            if val <= 0 and not forceRestart then
                print("💥 Base HP is 0! Auto-Restarting...")
                forceRestart = true
                task.wait(3)
                again()
            end
        end

        checkHP(baseHP.Value)
        hpConnection = baseHP.Changed:Connect(checkHP)
    end)
end

RemoteEvents.ShowGameEnd.OnClientEvent:Connect(function()
    if not forceRestart then
        forceRestart = true
        print("🚩 Game End Detected. Restarting in 3s...")
        task.wait(3)
        again()
    end
end)

-- [[ 4. DEPLOYMENT LOGIC ]] --

local function getRandPos(basePos)
    local r = 4
    return Vector3.new(
        basePos.X + (math.random() * 2 - 1) * r,
        basePos.Y,
        basePos.Z + (math.random() * 2 - 1) * r
    )
end

local function deploy(name, path, config, waitTime)
    if forceRestart then return end

    local finalPos = getRandPos(config.pos)
    local finalCF = CFrame.new(finalPos) * (config.cf - config.cf.Position)

    local success = false
    for i = 1, 3 do
        if forceRestart then return end
        local ok = pcall(function()
            RemoteFunctions.PlaceUnit:InvokeServer("unit_rafflesia", {
                Valid = true,
                PathIndex = path,
                Position = finalPos,
                DistanceAlongPath = config.dist,
                CF = finalCF,
                Rotation = 180
            })
        end)
        if ok then success = true break end
        task.wait(1)
    end

    print(success and "✅ Placed: "..name or "❌ Failed: "..name)

    local start = tick()
    while tick() - start < waitTime do
        if forceRestart then break end
        task.wait(0.5)
    end
end

-- [[ 5. MAIN LOOP ]] --

local function runSession()
    cleanup()
    monitorBaseHP()
    startSpeedListener() -- 👈 ฟังสปีดตลอดเกม

    task.wait(2)
    pcall(function()
        RemoteFunctions.PlaceDifficultyVote:InvokeServer("dif_apocalypse")
    end)

    task.wait(6) -- ❌ ก่อนเริ่มเกม ไม่โดนสปีด

    if forceRestart then return end

    deploy("Raff 1", 1, DATA.P1, scaledWait(5.5))
    deploy("Raff 2", 2, DATA.P2, scaledWait(10.7))
    deploy("Raff 3", 3, DATA.P3, scaledWait(6.8))
    deploy("Raff 4", 4, DATA.P4_NEW, scaledWait(50.3))
    deploy("Raff 5", 3, DATA.P3, scaledWait(5.5))
    deploy("Raff 6", 4, DATA.P4_OLD, 0)

    print("🛡️ All units deployed.")
    while not forceRestart do task.wait(1) end
end

while true do
    runSession()
    again()
    task.wait(2)
end
