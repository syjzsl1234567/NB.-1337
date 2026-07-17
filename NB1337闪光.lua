local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 配置
local AimLock = false
local Smooth = 0.08
local RenderRange = 800
local AimRadius = 130

local CrossCircleSize = 72
local LineWidth = 1
local BoxWidth = 2

-- 常驻UI绘制
local CrossHair = Drawing.new("Circle")
CrossHair.Radius = CrossCircleSize
CrossHair.Thickness = 2
CrossHair.Color = Color3.new(1, 0.15, 0.15)
CrossHair.Filled = false

local FPSLabel = Drawing.new("Text")
FPSLabel.Size = 18
FPSLabel.Color = Color3.new(0, 1, 1)
FPSLabel.Center = true

local PlayerNum = Drawing.new("Text")
PlayerNum.Size = 16
PlayerNum.Color = Color3.new(0, 1, 1)
PlayerNum.Center = true

local WaterMark = Drawing.new("Text")
WaterMark.Text = "NB1337辅助（闪光）\nQQ群：1076180222"
WaterMark.Size = 18
WaterMark.Color = Color3.new(1, 1, 1)
WaterMark.Center = true

-- 敌人绘制永久缓存池
local enemyDrawPool = {}

-- 左侧开关按钮
local Gui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Btn = Instance.new("TextButton", Gui)
Btn.Size = UDim2.new(0, 120, 0, 45)
Btn.Position = UDim2.new(0.02, 0, 0.35, 0)
Btn.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
Btn.Text = "视角锁定: 关"
Btn.TextColor3 = Color3.new(1, 1, 1)
Btn.BorderSizePixel = 0
Btn.MouseButton1Click:Connect(function()
    AimLock = not AimLock
    Btn.Text = AimLock and "视角锁定: 开" or "视角锁定: 关"
end)

local frameCount = 0
local lastFpsTime = os.clock()

RunService.RenderStepped:Connect(function()
    frameCount += 1
    local now = os.clock()
    if now - lastFpsTime >= 1 then
        lastFpsTime = now
        frameCount = 0
    end

    local w = Camera.ViewportSize.X
    local h = Camera.ViewportSize.Y
    local screenCenter = Vector2.new(w / 2, h / 2)
    -- 射线起点：屏幕最顶端居中
    local rayOrigin = Vector2.new(w / 2, 10)

    -- 居中准星圈
    CrossHair.Position = screenCenter
    CrossHair.Visible = true

    -- 中上FPS+人数
    FPSLabel.Text = "FPS: " .. frameCount
    FPSLabel.Position = Vector2.new(w / 2, h * 0.08)
    FPSLabel.Visible = true

    local allPlayers = Players:GetPlayers()
    PlayerNum.Text = "房间人数: " .. #allPlayers .. "/" .. Players.MaxPlayers
    PlayerNum.Position = Vector2.new(w / 2, h * 0.14)
    PlayerNum.Visible = true

    -- 底部水印
    WaterMark.Position = Vector2.new(w / 2, h - 60)
    WaterMark.Visible = true

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local aimTarget = nil
    local minDist = RenderRange

    for _, ply in ipairs(allPlayers) do
        if ply == LocalPlayer then continue end

        -- 首次创建永久绘制套件
        if not enemyDrawPool[ply.UserId] then
            enemyDrawPool[ply.UserId] = {
                Box = Drawing.new("Square"),
                Line = Drawing.new("Line"),
                Name = Drawing.new("Text"),
                Dist = Drawing.new("Text")
            }
            local d = enemyDrawPool[ply.UserId]
            d.Box.Thickness = BoxWidth
            d.Box.Color = Color3.new(1, 0.2, 0.2)
            d.Box.Filled = false

            d.Line.Thickness = LineWidth
            d.Line.Color = Color3.new(1, 0.4, 0.2)

            d.Name.Size = 14
            d.Name.Color = Color3.new(1, 1, 1)
            d.Name.Center = true

            d.Dist.Size = 12
            d.Dist.Color = Color3.new(1, 1, 0)
            d.Dist.Center = true
        end

        local draw = enemyDrawPool[ply.UserId]
        local char = ply.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        -- 死亡/离线直接隐藏
        if not root or not hum or hum.Health <= 0 then
            draw.Box.Visible = false
            draw.Line.Visible = false
            draw.Name.Visible = false
            draw.Dist.Visible = false
            continue
        end

        local dist = (myRoot.Position - root.Position).Magnitude
        if dist > RenderRange then
            draw.Box.Visible = false
            draw.Line.Visible = false
            draw.Name.Visible = false
            draw.Dist.Visible = false
            continue
        end

        -- 更新方框
        local bodySize = Vector3.new(1.1, 3.3, 1.1)
        local pMin = Camera:WorldToViewportPoint(root.CFrame:PointToWorldSpace(-bodySize / 2))
        local pMax = Camera:WorldToViewportPoint(root.CFrame:PointToWorldSpace(bodySize / 2))
        draw.Box.Position = Vector2.new(math.min(pMin.X, pMax.X), math.min(pMin.Y, pMax.Y))
        draw.Box.Size = Vector2.new(math.abs(pMin.X - pMax.X), math.abs(pMin.Y - pMax.Y))
        draw.Box.Visible = true

        -- 射线：屏幕最顶端 → 敌人中心
        local scrCenter = Camera:WorldToViewportPoint(root.Position)
        local vec = Vector2.new(scrCenter.X, scrCenter.Y)
        draw.Line.From = rayOrigin
        draw.Line.To = vec
        draw.Line.Visible = true

        -- 名称距离
        draw.Name.Text = ply.Name
        draw.Name.Position = Vector2.new(vec.X, draw.Box.Position.Y - 22)
        draw.Name.Visible = true

        draw.Dist.Text = math.floor(dist) .. "m"
        draw.Dist.Position = Vector2.new(vec.X, draw.Box.Position.Y + draw.Box.Size.Y + 8)
        draw.Dist.Visible = true

        -- 目标判定，修复闪烁：只替换更近目标，不频繁切换
        local offset = (vec - screenCenter).Magnitude
        local isInAim = offset < AimRadius
        if isInAim then
            if not aimTarget or dist < minDist then
                aimTarget = root
                minDist = dist
            end
        elseif not aimTarget then
            if dist < minDist then
                aimTarget = root
                minDist = dist
            end
        end
    end

    -- 防抖自瞄，彻底解决闪烁跳屏
    if AimLock and aimTarget then
        local targetPos = aimTarget.Position + Vector3.new(0, 1.2, 0)
        local camPos = Camera.CFrame.Position
        local targetCFrame = CFrame.new(camPos, targetPos)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Smooth)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    CrossHair.Visible = true
    FPSLabel.Visible = true
    PlayerNum.Visible = true
    WaterMark.Visible = true
end)