local toolbar = plugin:CreateToolbar("Animation Tools")
local button = toolbar:CreateButton("Scan Animations", "Scan all Animation objects in the entire game", "")

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")

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

local function checkOwnership(animationId, ownerId)
	if not animationId or animationId == "" or animationId == "rbxassetid://" then
		return "Empty"
	end
	
	local assetId = tonumber(animationId:match("%d+"))

	if not assetId then
		return "Invalid"
	end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset) 
	end)

	if not success then
		warn("Error getting info for " .. assetId .. ": " .. tostring(info))
		return "Error"
	end

	if info and info.Creator and info.Creator.Id then
		if info.Creator.Id == ownerId then
			return "Owned"
		else
			return "NotOwned"
		end
	end
	
	return "Error"
end

local function copyJSONToClipboard(results)
	if #results == 0 then
		warn("ไม่มี Animation ให้บันทึก")
		return false
	end
	
	local success, json = pcall(HttpService.JSONEncode, HttpService, results)
	
	if not success then
		warn("❌ เกิดข้อผิดพลาดในการแปลง JSON: ", json)
		return false
	end
	
	pcall(setclipboard, json)
	print("✅ คัดลอก JSON ไปยัง Clipboard แล้ว")
	return true
end

local function createGUI(results)
	if CoreGui:FindFirstChild("AnimScannerGUI") then
		CoreGui.AnimScannerGUI:Destroy()
	end
	
	local gameOwnerId = game.CreatorId
	
	local allRowsData = {}
	local isFilterOn = false

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
	title.Active = true
	title.Selectable = false

	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local dragStart = input.Position - frame.AbsolutePosition
			local inputChangedConnection
			local inputEndedConnection
            
			inputChangedConnection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.Change then
					local newPos = UDim2.fromOffset(input.Position.X - dragStart.X, input.Position.Y - dragStart.Y)
					frame.Position = newPos
				end
			end)
            
			inputEndedConnection = input.Ended:Connect(function()
				inputChangedConnection:Disconnect()
				inputEndedConnection:Disconnect()
			end)
		end
	end)

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
	exportBtn.Size = UDim2.new(0, 160, 0, 30)
	exportBtn.Position = UDim2.new(0, 10, 1, -40)
	exportBtn.Text = "Copy JSON to Clipboard"
	exportBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
	exportBtn.TextColor3 = Color3.new(1, 1, 1)
	exportBtn.Parent = frame
	exportBtn.MouseButton1Click:Connect(function()
		if copyJSONToClipboard(results) then 
			exportBtn.Text = "Copied JSON!"
			task.wait(1)
			exportBtn.Text = "Copy JSON to Clipboard"
		else
			exportBtn.Text = "Error!"
			task.wait(1)
			exportBtn.Text = "Copy JSON to Clipboard"
		end
	end)
	
	local toggleFilterBtn = Instance.new("TextButton")
	toggleFilterBtn.Size = UDim2.new(0, 120, 0, 30)
	toggleFilterBtn.Position = UDim2.new(0, 180, 1, -40)
	toggleFilterBtn.Text = "Filter: OFF"
	toggleFilterBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
	toggleFilterBtn.TextColor3 = Color3.new(1, 1, 1)
	toggleFilterBtn.Font = Enum.Font.SourceSansBold
	toggleFilterBtn.Parent = frame

	if #results == 0 then
		local noAnim = Instance.new("TextLabel")
		noAnim.Size = UDim2.new(1, 0, 0, 30)
		noAnim.Text = "ไม่พบ Animation ในโปรเจกต์นี้"
		noAnim.TextColor3 = Color3.new(1, 1, 1)
		noAnim.BackgroundTransparency = 1
		noAnim.Parent = scroll
		return
	end

	local function updateFilterVisibility()
		for _, data in ipairs(allRowsData) do
			if isFilterOn == false then
				data.row.Visible = true
			else
				if data.status == "Owned" or data.status == "Empty" then
					data.row.Visible = false
				else
					data.row.Visible = true
				end
			end
		end
	end
	
	toggleFilterBtn.MouseButton1Click:Connect(function()
		isFilterOn = not isFilterOn
		
		if isFilterOn then
			toggleFilterBtn.Text = "Filter: ON"
			toggleFilterBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		else
			toggleFilterBtn.Text = "Filter: OFF"
			toggleFilterBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
		end
		
		updateFilterVisibility()
	end)


	for _, anim in ipairs(results) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 30)
		row.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		row.Parent = scroll
		
		local rowData = {row = row, status = "Unknown"}
		table.insert(allRowsData, rowData)

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
			local rawId = anim.Id
			
			if rawId and rawId ~= "" then
				local idNumber = rawId:match("%d+") 
				
				if idNumber then
					local success, err = pcall(setclipboard, idNumber)
					
					if success then
						copyBtn.Text = "Copied!"
						task.wait(1)
						copyBtn.Text = "Copy ID"
					else
						copyBtn.Text = "Error"
						warn("SetClipboard Error: ", err)
						task.wait(1)
						copyBtn.Text = "Copy ID"
					end
				else
					copyBtn.Text = "Bad ID"
					task.wait(1)
					copyBtn.Text = "Copy ID"
				end
			else
				copyBtn.Text = "No ID"
				task.wait(1)
				copyBtn.Text = "Copy ID"
			end
		end)
		
		task.spawn(function()
			local status = checkOwnership(anim.Id, gameOwnerId)
			rowData.status = status
			
			if status == "NotOwned" then
				row.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
			elseif status == "Invalid" or status == "Error" then
				row.BackgroundColor3 = Color3.fromRGB(130, 110, 40)
			elseif status == "Empty" then
				row.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			end
			
			if isFilterOn and (status == "Owned" or status == "Empty") then
				row.Visible = false
			end
		end)
	end
end

button.Click:Connect(function()
	print("Scanning animations...")
	local results = scanAllAnimations()
	print("Scan complete. Found " .. #results .. " animations. Creating GUI...")
	createGUI(results)
end)
