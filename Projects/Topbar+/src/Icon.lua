-- LOCAL
local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local player = game:GetService("Players").LocalPlayer
local playerGui = player.PlayerGui
local topbarPlusGui = playerGui:WaitForChild("Topbar+")
local topbarContainer = topbarPlusGui.TopbarContainer
local iconTemplate = topbarContainer["_IconTemplate"]
local HDAdmin = replicatedStorage:WaitForChild("HDAdmin")
local Signal = require(HDAdmin:WaitForChild("Signal"))
local Maid = require(HDAdmin:WaitForChild("Maid"))
local Icon = {}
Icon.__index = Icon



-- CONSTRUCTOR
function Icon.new(name, imageId, order)
	local self = {}
	setmetatable(self, Icon)
	
	local container = iconTemplate:Clone()
	container.Name = name
	container.Visible = true
	local button = container.IconButton
	
	self.objects = {
		["container"] = container,
		["button"] = button,
		["image"] = button.IconImage,
		["notification"] = button.Notification,
		["amount"] = button.Notification.Amount
	}
	
	self.theme = {
		-- TOGGLE EFFECT
		["toggleTweenInfo"] = TweenInfo.new(0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		
		-- OBJECT PROPERTIES
		["container"] = {
			selected = {},
			deselected = {}
		},
		["button"] = {
			selected = {
				ImageColor3 = Color3.fromRGB(245, 245, 245),
				ImageTransparency = 0.1
			},
			deselected = {
				ImageColor3 = Color3.fromRGB(0, 0, 0),
				ImageTransparency = 0.5
			}
		},
		["image"] = {
			selected = {
				ImageColor3 = Color3.fromRGB(57, 60, 65),
			},
			deselected = {
				ImageColor3 = Color3.fromRGB(255, 255, 255),
			}
		},
		["notification"] = {
			selected = {},
			deselected = {},
		},
		["amount"] = {
			selected = {},
			deselected = {},
		},
	}
	self.toggleStatus = "deselected"
	self:applyThemeToAllObjects()
	
	self.name = name
	self.imageId = imageId or 0
	self:setImageSize(20)
	self.order = order or 1
	self.enabled = true
	self.rightSide = false
	self.totalNotifications = 0
	self.toggleFunction = function() end
	self.hoverFunction = function() end
	self.deselectWhenOtherIconSelected = true
	
	local maid = Maid.new()
	self._maid = maid
	self._fakeChatConnections = Maid.new()
	self.updated = maid:give(Signal.new())
	self.selected = maid:give(Signal.new())
	self.deselected = maid:give(Signal.new())
	self.endNotifications = maid:give(Signal.new())
	maid:give(container)
	
	--[[
	local hoverInputs = {"InputBegan", "InputEnded"}
	local originalTransparency = button.ImageTransparency
	self:setHoverFunction(function(inputName)
		local hovering = inputName == "InputBegan"
		button.ImageTransparency = (hovering and originalTransparency + 0.2) or (self.theme.button.selected.ImageTransparency or originalTransparency)
	end)
	for _, inputName in pairs(hoverInputs) do
		button[inputName]:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				self.hoverFunction(inputName)
			end
		end)
	end
	--]]
	self.maxTouchTime = 0.5
	
	if userInputService.MouseEnabled or userInputService.GamepadEnabled then
		button.MouseButton1Click:Connect(function()
			if self.toggleStatus == "selected" then
				self:deselect()
			else
				self:select()
			end
		end)
	elseif userInputService.TouchEnabled then
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				local firstPosition = Vector2.new(input.Position.X,input.Position.Y)
				local firstTime = tick()
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						local currentPosition = Vector2.new(input.Position.X,input.Position.Y)
						local currentTime = tick()
						print(currentTime-firstTime)
						if currentTime-firstTime <= self.maxTouchTime then
							local magnitude = (firstPosition-currentPosition).Magnitude
							print(magnitude)
							if magnitude <= 32 then
								if self.toggleStatus == "selected" then
									self:deselect()
								else
									self:select()
								end
							end
						end
					end
					input:Destroy()
				end)
			end
		end)
	end
	
	if imageId then
		self:setImage(imageId)
	end
	
	local iconInteract = {}
	local interact = require(script:WaitForChild("InteractionMenu"))
	iconInteract.new = function(...)
		local interactionMenuReturn = interact.new(self,...)
		self.interactionMenuReturn = interactionMenuReturn
		return interactionMenuReturn
	end
	for i,v in pairs(interact) do
		if v ~= interact.new then
			table.insert(iconInteract,v)
		end
	end
	self.interactionMenu = iconInteract
	
	container.Parent = topbarContainer
	
	return self
end



-- METHODS
function Icon:setImage(imageId)
	local textureId = (tonumber(imageId) and "http://www.roblox.com/asset/?id="..imageId) or imageId
	self.imageId = textureId
	self.objects.image.Image = textureId
	self.theme.image = self.theme.image or {}
	self.theme.image.selected = self.theme.image.selected or {}
	self.theme.image.selected.Image = textureId
end

function Icon:setOrder(order)
	self.order = tonumber(order) or 1
	self.updated:Fire()
end

function Icon:setLeft()
	self.rightSide = false
	self.updated:Fire()
end

function Icon:setRight()
	self.rightSide = true
	self.updated:Fire()
end

function Icon:setImageSize(pixelsX, pixelsY)
	pixelsX = tonumber(pixelsX) or self.imageSize
	if not pixelsY then
		pixelsY = pixelsX
	end
	self.imageSize = Vector2.new(pixelsX, pixelsY)
	self.objects.image.Size = UDim2.new(0, pixelsX, 0, pixelsY)
end

function Icon:setEnabled(bool)
	self.enabled = bool
	self.objects.container.Visible = bool
	self.updated:Fire()
end

function Icon:setBaseZIndex(baseValue)
	local container = self.objects.container
	baseValue = tonumber(baseValue) or container.ZIndex
	local difference = baseValue - container.ZIndex
	if difference == 0 then
		return "The baseValue is the same"
	end
	for _, object in pairs(self.objects) do
		object.ZIndex = object.ZIndex + difference
	end
end

function Icon:setToggleMenu(guiObject)
	if not guiObject or not guiObject:IsA("GuiObject") then
		guiObject = nil
	end
	self.toggleMenu = guiObject
end

function Icon:setToggleFunction(toggleFunction)
	if type(toggleFunction) == "function" then
		self.toggleFunction = toggleFunction
	end
end

function Icon:setHoverFunction(hoverFunction)
	if type(hoverFunction) == "function" then
		self.hoverFunction = hoverFunction
	end
end

function Icon:setTheme(themeDetails)
	local function parseDetails(objectName, toggleDetails)
		local errorBaseMessage = "Topbar+ | Failed to set theme:"
		local object = self.objects[objectName]
		if not object then
			if objectName == "toggleTweenInfo" then
				self.theme.toggleTweenInfo = toggleDetails
			else
				warn(("%s invalid objectName '%s'"):format(errorBaseMessage, objectName))
			end
			return false
		end
		for toggleStatus, propertiesTable in pairs(toggleDetails) do
			local originalPropertiesTable = self.theme[objectName][toggleStatus]
			if not originalPropertiesTable then
				warn(("%s invalid toggleStatus '%s'. Use 'selected' or 'deselected'."):format(errorBaseMessage, toggleStatus))
				return false
			end
			local oppositeToggleStatus = (toggleStatus == "selected" and "deselected") or "selected"
			local oppositeGroup = self.theme[objectName][oppositeToggleStatus]
			local group = self.theme[objectName][toggleStatus]
			for key, value in pairs(propertiesTable) do
				local oppositeKey = oppositeGroup[key]
				if not oppositeKey then
					oppositeGroup[key] = group[key]
				end
				group[key] = value
			end
			if toggleStatus == self.toggleStatus then
				self:applyThemeToObject(objectName, toggleStatus)
			end
		end
	end
	for objectName, toggleDetails in pairs(themeDetails) do
		parseDetails(objectName, toggleDetails)
	end
end

function Icon:applyThemeToObject(objectName, toggleStatus)
	local object = self.objects[objectName]
	if object then
		local propertiesTable = self.theme[objectName][(toggleStatus or self.toggleStatus)]
		local toggleTweenInfo = self.theme.toggleTweenInfo
		local invalidProperties = {"Image"}
		local finalPropertiesTable = {}
		for propName, propValue in pairs(propertiesTable) do
			if table.find(invalidProperties, propName) then
				object[propName] = propValue
			else
				finalPropertiesTable[propName] = propValue
			end
		end
		tweenService:Create(object, toggleTweenInfo, finalPropertiesTable):Play()
	end
end

function Icon:applyThemeToAllObjects(...)
	for objectName, _ in pairs(self.theme) do
		self:applyThemeToObject(objectName, ...)
	end
end

function Icon:select()
	self.toggleStatus = "selected"
	self:applyThemeToAllObjects()
	self.toggleFunction()
	if self.toggleMenu then
		self.toggleMenu.Visible = true
	end
	self.selected:Fire()
end

function Icon:deselect()
	self.toggleStatus = "deselected"
	self:applyThemeToAllObjects()
	self.toggleFunction()
	if self.toggleMenu then
		self.toggleMenu.Visible = false
	end
	self.deselected:Fire()
end

function Icon:notify(clearNoticeEvent)
	coroutine.wrap(function()
		if not clearNoticeEvent then
			clearNoticeEvent = self.deselected
		end
		self.totalNotifications = self.totalNotifications + 1
		self.objects.amount.Text = (self.totalNotifications < 100 and self.totalNotifications) or "99+"
		self.objects.notification.Visible = true
		
		local notifComplete = Signal.new()
		local endEvent = self.endNotifications:Connect(function()
			notifComplete:Fire()
		end)
		local customEvent = clearNoticeEvent:Connect(function()
			notifComplete:Fire()
		end)
			
		notifComplete:Wait()
		
		endEvent:Disconnect()
		customEvent:Disconnect()
		notifComplete:Disconnect()
		
		self.totalNotifications = self.totalNotifications - 1
		if self.totalNotifications < 1 then
			self.objects.notification.Visible = false
		end
	end)()
end

function Icon:clearNotifications()
	self.endNotifications:Fire()
end

function Icon:destroy()
	self:clearNotifications()
	self._maid:clean()
	self._fakeChatConnections:clean()
	if self.interactionMenuReturn then
		self.interactionMenuReturn:destroy()
	end
end



return Icon
