--!strict

--// Services
local CollectionService = game:GetService('CollectionService')
local UserInputService = game:GetService('UserInputService')

--// Variables
local NavigationSound = script:WaitForChild('NavigationSound')
local SelectSound = script:WaitForChild('SelectSound')

local Navigator = {}

Navigator.OpenedUIs = {}
Navigator.CurrentUi = nil :: GuiObject?
Navigator.UiColor = nil :: Color3?
Navigator.NeededStroke = false
Navigator.Connection = nil :: RBXScriptConnection?

--// Properities
--Highlighting
Navigator.HighlightColor = Color3.fromRGB(255, 255, 255)

--// Functions
-- Finds a UIStoke or creates one.
local function getStroke(obj: GuiObject): UIStroke
	local stroke = obj:FindFirstChildOfClass('UIStroke') :: UIStroke
	Navigator.NeededStroke = false

	if not stroke then
		stroke = Instance.new('UIStroke', obj)
		stroke.Thickness = 1.5
		stroke.Transparency = 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

		Navigator.NeededStroke = true
	end

	return stroke
end
-- Clones a sound and plays it.
local function playSound(sound: Sound)
	if sound then
		local clone = sound:Clone()
		clone.Parent = script
		clone:Play()
		clone.Ended:Once(function()
			clone:Destroy()
		end)
	end
end
-- Returns the first selectable object in the menu.
local function getFirstSelectable(menu: GuiObject): GuiObject?
	for _, v in ipairs(menu:GetDescendants()) do
		if v:IsA("GuiObject") and CollectionService:HasTag(v, "Selectable") then
			return v
		end
	end
	return nil
end

---
-- Highlights the GuiObject. If you click Enter on the highlighted GuiObject it will open menu for that GuiObject
-- and if you click Backspace it will close the menu and get the last opened menu.
function Navigator.Navigate(obj: GuiObject, highlightColor: Color3?)
	if not obj then return end
	
	if not obj:IsA('GuiObject') or not CollectionService:HasTag(obj, 'Selectable') or not obj.Visible then return end
	
	if Navigator.CurrentUi ~= nil then
		local stroke = Navigator.CurrentUi:FindFirstChildOfClass('UIStroke')
		
		if stroke then
			stroke.Color = Navigator.UiColor or Color3.fromRGB(255, 255, 255)
			
			if Navigator.NeededStroke then
				stroke:Destroy()
			end
		end
	end
	
	if #Navigator.OpenedUIs == 0 then
		Navigator.OpenedUIs[1] = obj.Parent
	end
	
	if Navigator.Connection then Navigator.Connection:Disconnect() end
	
	Navigator.CurrentUi = obj
	
	local stroke = getStroke(obj)
	
	if stroke then
		Navigator.UiColor = stroke.Color
		
		if not highlightColor then
			stroke.Color = Navigator.HighlightColor
			
		elseif highlightColor and typeof(highlightColor) == 'Color3' then
			stroke.Color = highlightColor
		end
	end
	
	playSound(NavigationSound)
	
	Navigator.Connection = UserInputService.InputBegan:Connect(function(input: InputObject, gamePro: boolean)
		if gamePro then return end
		
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			stroke.Transparency = 1
			task.wait(0.1)
			stroke.Transparency = 0
			task.wait(0.01)
			
			Navigator.Select(obj)
		end
	end)
end

-- If there is a highlighted GuiObject, it will unhighlight it.
function Navigator.Denavigate()
	if not Navigator.CurrentUi then return end

	local stroke = Navigator.CurrentUi:FindFirstChildOfClass('UIStroke')
	if stroke then
		if Navigator.NeededStroke then
			stroke:Destroy()
		else
			stroke.Color = Navigator.UiColor or Color3.fromRGB(255, 255, 255)
		end
	end

	Navigator.CurrentUi = nil
	Navigator.UiColor = nil
	Navigator.NeededStroke = false
end

-- Opens the menu of the highlighted GuiObject.
function Navigator.Select(obj: GuiObject)
	if not obj then return end

	if not obj:IsA('GuiObject') or not CollectionService:HasTag(obj, 'Selectable') or not obj:FindFirstChild('Menu') then return end
	
	local ObjectValue = obj:FindFirstChild('Menu') :: ObjectValue
	local Menu = ObjectValue.Value :: GuiObject
	
	if not Menu and typeof(Menu) ~= 'GuiObject' then return end
	
	Navigator.OpenedUIs[#Navigator.OpenedUIs + 1] = Menu
	
	if obj.Parent and obj.Parent:IsA('GuiObject') then
		obj.Parent.Visible = false
	end
	
	playSound(SelectSound)
	
	Menu.Visible = true
	
	local firstSelectable = getFirstSelectable(Menu)

	if firstSelectable then
		Navigator.Navigate(firstSelectable)
	end
end

-- Returns to the previous menu.
function Navigator.Return()
	if #Navigator.OpenedUIs <= 1 then
		Navigator.Denavigate()
		return
	end

	local currentMenu = Navigator.OpenedUIs[#Navigator.OpenedUIs] :: GuiObject?
	if currentMenu then
		currentMenu.Visible = false
	end

	table.remove(Navigator.OpenedUIs, #Navigator.OpenedUIs)

	local previousMenu = Navigator.OpenedUIs[#Navigator.OpenedUIs] :: GuiObject?
	if previousMenu then
		previousMenu.Visible = true
		
		local firstSelectable = getFirstSelectable(previousMenu)
		
		if firstSelectable then
			Navigator.Navigate(firstSelectable)
		end
	end
end

-- Finds the closest GuiObject to the one given, based on the KeyCode of the InputObject.
function Navigator.FindClosest(obj: GuiObject, key: InputObject): GuiObject?
	local keyName = key.KeyCode.Name
	if keyName ~= "Up" and keyName ~= "Down" and keyName ~= "Left" and keyName ~= "Right" then return nil end

	local objCenter = Vector2.new(
		obj.AbsolutePosition.X + obj.AbsoluteSize.X/2,
		obj.AbsolutePosition.Y + obj.AbsoluteSize.Y/2
	)

	local closest: GuiObject? = nil
	local closestDistance = math.huge

	if obj.Parent then
		for _, ui: GuiObject in obj.Parent:GetChildren() do
			if ui ~= obj and ui:IsA("GuiObject") and CollectionService:HasTag(ui, "Selectable") then
				local uiCenter = Vector2.new(
					ui.AbsolutePosition.X + ui.AbsoluteSize.X/2,
					ui.AbsolutePosition.Y + ui.AbsoluteSize.Y/2
				)

				local delta = uiCenter - objCenter
				local distance = delta.Magnitude

				local valid = false
				if keyName == "Up" and delta.Y < 0 and math.abs(delta.X) < math.abs(delta.Y) then valid = true end
				if keyName == "Down" and delta.Y > 0 and math.abs(delta.X) < math.abs(delta.Y) then valid = true end
				if keyName == "Left" and delta.X < 0 and math.abs(delta.Y) < math.abs(delta.X) then valid = true end
				if keyName == "Right" and delta.X > 0 and math.abs(delta.Y) < math.abs(delta.X) then valid = true end

				if valid and distance < closestDistance then
					closest = ui
					closestDistance = distance
				end
			end
		end
	end

	return closest
end

-- Returns the current UI. (Looks more professional then writing "Navigator.CurrentUi") (Optional)
function Navigator.GetCurrentSelection(): GuiObject?
	return Navigator.CurrentUi
end

-- Loops through the opened UIs and makes them invisible, then sets the Navigator.OpenedUIs to {}
function Navigator.ClearAllSelections(): ()
	for i, menu in pairs(Navigator.OpenedUIs) do
		if menu and typeof(menu) == 'GuiObject' then
			menu.Visible = false
		end
	end

	Navigator.CurrentUi = nil :: GuiObject?
	Navigator.UiColor = nil :: Color3?
	Navigator.NeededStroke = false
	Navigator.OpenedUIs = {}
end

return Navigator
