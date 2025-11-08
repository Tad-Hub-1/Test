local toolbar = plugin:CreateToolbar("Map Diff Tool")
local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local SNAPSHOT_KEY = "MapDiffSnapshot"
local PATCH_KEY = "MapDiffPatchFile"

local function recursiveScan(object, targetTable)
	local success, path = pcall(function() return object:GetFullName() end)
	local successUID, uid = pcall(function() return object.UniqueId end)
	
	if not success or not successUID then
		return
	end
	
	local data = {
		Path = path,
		Name = object.Name
	}
	
	if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript") then
		data.Source = object.Source
	end
	
	targetTable[uid] = data
	
	pcall(function()
		for _, child in ipairs(object:GetChildren()) do
			recursiveScan(child, targetTable)
		end
	end)
end

local function findObjectByPath(path)
	local obj = game
	local parts = path:split(".")
	for i = 2, #parts do
		if obj then
			obj = obj:FindFirstChild(parts[i])
		else
			return nil
		end
	end
	return obj
end

local function takeSnapshot()
	print("Taking snapshot of current map...")
	local snapshotData = {}
	recursiveScan(game, snapshotData)
	
	local success, jsonString = pcall(HttpService.JSONEncode, HttpService, snapshotData)
	
	if success then
		plugin:SetSetting(SNAPSHOT_KEY, jsonString)
		print("Snapshot (Map A) saved successfully to plugin memory.")
	else
		warn("Failed to encode snapshot data:", jsonString)
	end
end

local function createResultsGUI(changes)
	if CoreGui:FindFirstChild("DiffToolGUI") then
		CoreGui.DiffToolGUI:Destroy()
	end
	
	local screen = Instance.new("ScreenGui")
	screen.Name = "DiffToolGUI"
	screen.ResetOnSpawn = false
	screen.Parent = CoreGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 800, 0, 500)
	frame.Position = UDim2.new(0.5, -400, 0.5, -250)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.Parent = screen
	frame.Active = true
	frame.Draggable = true

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 35)
	title.BackgroundTransparency = 1
	title.Text = "Comparison Results (" .. #changes .. " changes)"
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

	local saveDiffBtn = Instance.new("TextButton")
	saveDiffBtn.Size = UDim2.new(0, 120, 0, 30)
	saveDiffBtn.Position = UDim2.new(0, 10, 1, -40)
	saveDiffBtn.Text = "Save Diff File"
	saveDiffBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
	saveDiffBtn.TextColor3 = Color3.new(1, 1, 1)
	saveDiffBtn.Parent = frame

	saveDiffBtn.MouseButton1Click:Connect(function()
		local success, jsonString = pcall(HttpService.JSONEncode, HttpService, changes)
		if success then
			plugin:SetSetting(PATCH_KEY, jsonString)
			saveDiffBtn.Text = "Saved!"
			print("Diff file saved to plugin memory.")
		else
			saveDiffBtn.Text = "Error!"
			warn("Failed to save diff file:", jsonString)
		end
	end)

	if #changes == 0 then
		local noAnim = Instance.new("TextLabel")
		noAnim.Size = UDim2.new(1, 0, 0, 30)
		noAnim.Text = "No changes found."
		noAnim.TextColor3 = Color3.new(1, 1, 1)
		noAnim.BackgroundTransparency = 1
		noAnim.Parent = scroll
		return
	end

	for _, change in ipairs(changes) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		row.Parent = scroll
		
		local pathText = ""
		
		local typeLbl = Instance.new("TextLabel")
		typeLbl.Size = UDim2.new(0, 100, 1, 0)
		typeLbl.Text = change.Type
		typeLbl.Font = Enum.Font.SourceSansBold
		typeLbl.TextXAlignment = Enum.TextXAlignment.Left
		typeLbl.BackgroundTransparency = 1
		typeLbl.Parent = row

		if change.Type == "Added" then
			typeLbl.TextColor3 = Color3.fromRGB(80, 255, 80)
			pathText = change.Path
			row.Size = UDim2.new(1, -10, 0, 30)
		elseif change.Type == "Removed" then
			typeLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
			pathText = change.Path
			row.Size = UDim2.new(1, -10, 0, 30)
		elseif change.Type == "Changed" then
			typeLbl.TextColor3 = Color3.fromRGB(255, 255, 80)
			pathText = change.Path
			row.Size = UDim2.new(1, -10, 0, 30)
		elseif change.Type == "Moved" then
			typeLbl.TextColor3 = Color3.fromRGB(80, 200, 255)
			pathText = "FROM: " .. change.From .. "\nTO: " .. change.To
			row.Size = UDim2.new(1, -10, 0, 45)
		end

		local pathLbl = Instance.new("TextLabel")
		pathLbl.Size = UDim2.new(1, -190, 1, 0)
		pathLbl.Position = UDim2.new(0, 105, 0, 0)
		pathLbl.Text = pathText
		pathLbl.TextColor3 = Color3.new(1, 1, 1)
		pathLbl.TextXAlignment = Enum.TextXAlignment.Left
		pathLbl.TextYAlignment = Enum.TextYAlignment.Top
		pathLbl.BackgroundTransparency = 1
		pathLbl.Font = Enum.Font.Code
		pathLbl.Parent = row

		local selectBtn = Instance.new("TextButton")
		selectBtn.Size = UDim2.new(0, 70, 0, 24)
		selectBtn.Position = UDim2.new(1, -75, 0, 3)
		selectBtn.Text = "Select"
		selectBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 180)
		selectBtn.TextColor3 = Color3.new(1, 1, 1)
		selectBtn.Parent = row

		selectBtn.MouseButton1Click:Connect(function()
			local pathToSelect = change.Path or change.To
			local obj = findObjectByPath(pathToSelect)
			if obj then
				Selection:Set({obj})
				print("Selected:", obj:GetFullName())
			else
				warn("Could not find object (it might be removed or path changed):", pathToSelect)
			end
		end)
	end
end

local function applyDiff()
	local savedJSON = plugin:GetSetting(PATCH_KEY)
	
	if not savedJSON then
		warn("No diff file found in memory. Please use '2. Compare' and 'Save Diff File' first.")
		return
	end
	
	print("Loading saved diff file...")
	local success, patchData = pcall(HttpService.JSONDecode, HttpService, savedJSON)
	
	if not success then
		warn("Failed to decode diff file. It might be corrupted.", patchData)
		return
	end
	
	print("Applying " .. #patchData .. " changes...")
	
	local skippedCount = 0
	local removedCount = 0
	local changedCount = 0
	
	for _, change in ipairs(patchData) do
		if change.Type == "Removed" then
			local obj = findObjectByPath(change.Path)
			if obj then
				obj:Destroy()
				removedCount = removedCount + 1
			else
				warn("Apply 'Removed' failed: Object not found at ", change.Path)
			end
			
		elseif change.Type == "Changed" then
			local obj = findObjectByPath(change.Path)
			if obj then
				if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
					obj.Source = change.NewSource
					changedCount = changedCount + 1
				else
					warn("Apply 'Changed' failed: Object is not a script at ", change.Path)
				end
			else
				warn("Apply 'Changed' failed: Object not found at ", change.Path)
			end
			
		elseif change.Type == "Added" then
			warn("Skipping 'Added' change: This must be done manually for ", change.Path)
			skippedCount = skippedCount + 1
		elseif change.Type == "Moved" then
			warn("Skipping 'Moved' change: This must be done manually for '", change.From, "'")
			skippedCount = skippedCount + 1
		end
	end
	
	print("Apply complete.")
	print("Summary: " .. changedCount .. " changed, " .. removedCount .. " removed, " .. skippedCount .. " skipped (Added/Moved).")
end

local function getChanges()
	local savedJSON = plugin:GetSetting(SNAPSHOT_KEY)
	
	if not savedJSON then
		warn("No snapshot found in memory. Please use '1. Save Snapshot (Map A)' in your original map first.")
		return nil
	end
	
	print("Loading saved snapshot...")
	local success, snapshotA = pcall(HttpService.JSONDecode, HttpService, savedJSON)
	
	if not success then
		warn("Failed to decode saved snapshot data. It might be corrupted.", snapshotA)
		return nil
	end
	
	print("Scanning current map (Map B)...")
	local snapshotB = {}
	recursiveScan(game, snapshotB)
	
	local changes = {}
	local seenB_UIDs = {}
	
	for uid, oldData in pairs(snapshotA) do
		local newData = snapshotB[uid]
		
		if newData then
			seenB_UIDs[uid] = true
			
			if oldData.Path ~= newData.Path then
				table.insert(changes, {Type = "Moved", From = oldData.Path, To = newData.Path, UID = uid})
			end
			
			if oldData.Source and (oldData.Source ~= newData.Source) then
				table.insert(changes, {Type = "Changed", Path = newData.Path, NewSource = newData.Source, UID = uid})
			end
		else
			table.insert(changes, {Type = "Removed", Path = oldData.Path, UID = uid})
		end
	end
	
	for uid, newData in pairs(snapshotB) do
		if not seenB_UIDs[uid] then
			table.insert(changes, {Type = "Added", Path = newData.Path, UID = uid})
		end
	end
	
	return changes
end

local function compareSnapshots_Mode1()
	print("Comparing... (Full Tool Mode)")
	local changes = getChanges()
	if changes then
		print("Comparison complete. Found " .. #changes .. " changes.")
		createResultsGUI(changes)
	end
end

local function initializeFullTool()
	local snapshotBtn = toolbar:CreateButton("1. Save Snapshot (Map A)", "Save the current game state to plugin memory", "")
	local compareBtn = toolbar:CreateButton("2. Compare w/ Saved (Map B)", "Compare current map to the saved snapshot", "")
	local applyBtn = toolbar:CreateButton("3. Apply Saved Diff", "Apply the saved diff file to the current map", "")
	
	snapshotBtn.Click:Connect(takeSnapshot)
	compareBtn.Click:Connect(compareSnapshots_Mode1)
	applyBtn.Click:Connect(applyDiff)
	
	print("Map Diff Tool (Full Version) initialized.")
end

local function generateReportFile(changes)
	if #changes == 0 then
		print("No changes found. Report not generated.")
		return
	end
	
	local function getPathInfo(path)
		local i = path:match(".*%.()")
		if i and i > 1 then
			local parentPath = path:sub(1, i - 2)
			local objectName = path:sub(i)
			return objectName, parentPath
		else
			return path, "game"
		end
	end

	local reportLines = {}
	table.insert(reportLines, "-- MAP COMPARISON REPORT --")
	table.insert(reportLines, "-- Generated on: " .. os.date("!*t"))
	table.insert(reportLines, "-- Found " .. #changes .. " total changes. --")
	table.insert(reportLines, "")
	
	local added = {}
	local changed = {}
	local removed = {}
	local moved = {}
	
	for _, change in ipairs(changes) do
		if change.Type == "Added" then
			local objectName, parentPath = getPathInfo(change.Path)
			table.insert(added, string.format("[ADDED] %s (in %s)", objectName, parentPath))
			
		elseif change.Type == "Changed" then
			local objectName, parentPath = getPathInfo(change.Path)
			table.insert(changed, string.format("[CHANGED] %s (in %s)", objectName, parentPath))
			
		elseif change.Type == "Removed" then
			local objectName, parentPath = getPathInfo(change.Path)
			table.insert(removed, string.format("[REMOVED] %s (from %s)", objectName, parentPath))
			
		elseif change.Type == "Moved" then
			local objectName, oldParentPath = getPathInfo(change.From)
			local _, newParentPath = getPathInfo(change.To)
			table.insert(moved, string.format("[MOVED] %s (from %s -> %s)", objectName, oldParentPath, newParentPath))
		end
	end
	
	table.insert(reportLines, "========== ADDED (" .. #added .. ") ==========")
	for _, line in ipairs(added) do table.insert(reportLines, line) end
	table.insert(reportLines, "")
	
	table.insert(reportLines, "========== MOVED (" .. #moved .. ") ==========")
	for _, line in ipairs(moved) do table.insert(reportLines, line) end
	table.insert(reportLines, "")
	
	table.insert(reportLines, "========== CHANGED (" .. #changed .. ") ==========")
	for _, line in ipairs(changed) do table.insert(reportLines, line) end
	table.insert(reportLines, "")
	
	table.insert(reportLines, "========== REMOVED (" .. #removed .. ") ==========")
	for _, line in ipairs(removed) do table.insert(reportLines, line) end
	
	local reportText = table.concat(reportLines, "\n")
	
	local reportScript = Instance.new("Script")
	reportScript.Name = "MapDiff_Report_" .. os.date("%Y%m%d_%H%M%S")
	reportScript.Source = reportText
	reportScript.Parent = ServerStorage
	
	Selection:Set({reportScript})
	print("Report generated! Check ServerStorage for the file: " .. reportScript.Name)
end

local function generateReportMode()
	print("Comparing... (Report-Only Mode)")
	local changes = getChanges()
	if changes then
		generateReportFile(changes)
	end
end

local function createModeSelectorGUI()
	if CoreGui:FindFirstChild("DiffToolModeSelector") then
		CoreGui.DiffToolModeSelector:Destroy()
	end
	
	local screen = Instance.new("ScreenGui")
	screen.Name = "DiffToolModeSelector"
	screen.ResetOnSpawn = false
	screen.Parent = CoreGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 400, 0, 180)
	frame.Position = UDim2.new(0.5, -200, 0.5, -90)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screen

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 35)
	title.BackgroundTransparency = 1
	title.Text = "Select Plugin Mode"
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = frame
	
	local mode1Btn = Instance.new("TextButton")
	mode1Btn.Size = UDim2.new(1, -20, 0, 50)
	mode1Btn.Position = UDim2.new(0, 10, 0, 50)
	mode1Btn.Text = "Mode 1: Full Tool (Save, Compare, Apply)"
	mode1Btn.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
	mode1Btn.TextColor3 = Color3.new(1, 1, 1)
	mode1Btn.Parent = frame
	
	local mode2Btn = Instance.new("TextButton")
	mode2Btn.Size = UDim2.new(1, -20, 0, 50)
	mode2Btn.Position = UDim2.new(0, 10, 0, 110)
	mode2Btn.Text = "Mode 2: Generate Report Only"
	mode2Btn.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
	mode2Btn.TextColor3 = Color3.new(1, 1, 1)
	mode2Btn.Parent = frame
	
	mode1Btn.MouseButton1Click:Connect(function()
		initializeFullTool()
		screen:Destroy()
	end)
	
	mode2Btn.MouseButton1Click:Connect(function()
		generateReportMode()
		screen:Destroy()
	end)
end

local mainBtn = toolbar:CreateButton("Map Diff Tool", "Open Map Diff Tool Menu", "")
mainBtn.Click:Connect(createModeSelectorGUI)
