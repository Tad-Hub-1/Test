local toolbar = plugin:CreateToolbar("Animation Tools")
local button = toolbar:CreateButton("Scan Animations", "Scan all Animation objects in the entire game", "")

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- 🧩 ฟังก์ชันสแกน Animation ทั้งเกม
local function scanAllAnimations()
	local results = {}

	local function scan(obj)
		for _, child in ipairs(obj:GetChildren()) do
			if child:IsA("Animation") then
				table.insert(results, {
					Name = child.Name,
					Id = child.AnimationId,
					Path = child:GetFullName()
				})
			end
			pcall(scan, child)
		end
	end

	for _, service in ipairs(game:GetChildren()) do
		pcall(scan, service)
	end

	return results
end

-- 🧩 ฟังก์ชัน Export JSON
local function exportToJSON(results)
	if #results == 0 then
		warn("ไม่มี Animation ให้บันทึก")
		return
	end
	local json = HttpService:JSONEncode(results)
	local filename = "AnimationScan_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
	if writefile then
		writefile(filename, json)
		print("✅ บันทึกไฟล์เรียบร้อย: " .. filename)
	else
		warn("❌ ไม่สามารถบันทึกไฟล์ (writefile ใช้ไม่ได้ใน environment นี้)")
	end
end

-- 🧩 GUI
local function createGUI(results)
	if CoreGui:FindFirstChild("AnimScannerGUI") then
		CoreGui.AnimScannerGUI:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "AnimScannerGUI"
	screen.ResetOnSpawn = false
	screen.Parent = CoreGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 700, 0, 500)
	frame.Position = UDim2.new(0.5, -350, 0.5, -250)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.Parent = screen

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 35)
	title.BackgroundTransparency = 1
	title.Text = "Animation Scanner Results (" .. #results .. ")"
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -80)
	scroll.Position = UDim2.new(0, 10, 0, 40)
	scroll.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 100, 0, 30)
	closeBtn.Position = UDim2.new(1, -110, 1, -40)
	closeBtn.Text = "Close"
	closeBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Parent = frame
	closeBtn.MouseButton1Click:Connect(function()
		screen:Destroy()
	end)

	local exportBtn = Instance.new("TextButton")
	exportBtn.Size = UDim2.new(0, 120, 0, 30)
	exportBtn.Position = UDim2.new(0, 10, 1, -40)
	exportBtn.Text = "Export JSON"
	exportBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
	exportBtn.TextColor3 = Color3.new(1, 1, 1)
	exportBtn.Parent = frame
	exportBtn.MouseButton1Click:Connect(function()
		exportToJSON(results)
		exportBtn.Text = "Exported!"
		task.wait(1)
		exportBtn.Text = "Export JSON"
	end)

	if #results == 0 then
		local noAnim = Instance.new("TextLabel")
		noAnim.Size = UDim2.new(1, 0, 0, 30)
		noAnim.Text = "ไม่พบ Animation ในโปรเจกต์นี้"
		noAnim.TextColor3 = Color3.new(1, 1, 1)
		noAnim.BackgroundTransparency = 1
		noAnim.Parent = scroll
		return
	end

	for _, anim in ipairs(results) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 30)
		row.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		row.Parent = scroll

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.35, 0, 1, 0)
		nameLbl.Text = anim.Name
		nameLbl.TextColor3 = Color3.new(1, 1, 1)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.BackgroundTransparency = 1
		nameLbl.Parent = row

		local idLbl = Instance.new("TextLabel")
		idLbl.Size = UDim2.new(0.45, 0, 1, 0)
		idLbl.Position = UDim2.new(0.35, 5, 0, 0)
		idLbl.Text = anim.Id ~= "" and anim.Id or "(no id)"
		idLbl.TextColor3 = Color3.fromRGB(150, 200, 255)
		idLbl.TextXAlignment = Enum.TextXAlignment.Left
		idLbl.BackgroundTransparency = 1
		idLbl.Font = Enum.Font.Code
		idLbl.TextSize = 14
		idLbl.Parent = row

		local copyBtn = Instance.new("TextButton")
		copyBtn.Size = UDim2.new(0.2, -5, 0.8, 0)
		copyBtn.Position = UDim2.new(0.8, 0, 0.1, 0)
		copyBtn.Text = "Copy ID"
		copyBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 180)
		copyBtn.TextColor3 = Color3.new(1, 1, 1)
		copyBtn.Parent = row

		copyBtn.MouseButton1Click:Connect(function()
			if anim.Id and anim.Id ~= "" then
				setclipboard(anim.Id)
				copyBtn.Text = "Copied!"
				task.wait(0.8)
				copyBtn.Text = "Copy ID"
			else
				copyBtn.Text = "No ID"
				task.wait(0.8)
				copyBtn.Text = "Copy ID"
			end
		end)
	end
end

-- 🧩 ปุ่มหลักใน Toolbar
button.Click:Connect(function()
	local results = scanAllAnimations()
	createGUI(results)
end)
