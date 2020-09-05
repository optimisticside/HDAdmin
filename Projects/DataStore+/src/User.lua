-- LOCAL
local dataStoreService = game:GetService("DataStoreService")
local httpService = game:GetService("HttpService")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local teleportService = game:GetService("TeleportService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HDAdmin = replicatedStorage:WaitForChild("HDAdmin")
local Signal = require(HDAdmin:WaitForChild("Signal"))
local Maid = require(HDAdmin:WaitForChild("Maid"))
local State = require(script.Parent.State)
local Serializer = require(script.Parent.Serializer)
local User = {}
User.__index = User



-- CONSTRUCTOR
function User.new(dataStoreName, key)
	local self = {}
	setmetatable(self, User)
	
	-- Maid
	local maid = Maid.new()
	self._maid = maid
	
	-- Main
	self.temp = maid:give(State.new())
	self.perm = maid:give(State.new())
	self.backup = maid:give(State.new())
	self._data = maid:give(State.new())
	
	-- Config
	local currentTick = tick()
	self.onlySaveDataWhenChanged = true
	self.ignoreSaveOnBindToClose = false
	self.teleportPlayerAwayOnFail = false
	self.autoSave = false
	self.autoSaveInterval = 60
	self.maxRetries = 3
	self.cooldown = 8
	self.transformingLoadData = false
	
	-- Setup information
	self.dataStoreName = dataStoreName
	self.dataStore = dataStoreName and key and dataStoreService:GetDataStore(dataStoreName)
	self.key = key
	self.sessionId = httpService:GenerateGUID(false)
	self.isNewUser = nil
	self.isLoaded = false
	self.loaded = maid:give(Signal.new())
	self.saved = maid:give(Signal.new())
	self.player = nil
	self.errorMessageBase = "DataStore+ | Failed to %s DataKey '".. tostring(key).."' ("..dataStoreName.."): "
	self.startData = {}
	
	-- AutoSave
	self.nextAutoSaveTick = currentTick + 5
	if self.autoSave then
		self:initAutoSave()
	end
	
	--BindToClose
	if not runService:IsStudio() then
		game:BindToClose(function()
			if not self.ignoreSaveOnBindToClose then
				self:saveAsync()
			end
		end)
	end

	-- Perm to _Data (serialization)
	local serEvents = {
		changed = "set",
		inserted = "insert",
		removed = "remove",
		paired = "pair",
	}
	for eventName, methodName in pairs(serEvents) do
		self.perm[eventName]:Connect(function(...)
			local packaged = {...}
			for k,v in pairs(packaged) do
				packaged[k] = Serializer.serialize(v, true)
			end
			self._data[methodName](self._data, table.unpack(packaged))
			self._data._tableUpdated = true
		end)
	end

	return self
end



-- METHODS
function User:loadAsync()
	local callType = "load"
	self.isLoaded = false
	
	-- Retrieve previous _data 
	local data = self:_protectedCall(callType, function(finalAttempt)
		return self.dataStore:GetAsync(self.key)
	end)

	-- Setup perm; if nothing found, apply start data. Transform _data into perm (i.e. deserialize)
	if not data then
		data = self.startData
		self.isNewUser = true
	else
		self.isNewUser = false
	end
	self.transformingLoadData = true
	self.perm:transformTo(data,  function(name, content)
		if name:sub(1,1) == "_" then
			return self._data, "isPrivate"
		end
	end)
	self.transformingLoadData = false
	
	-- Find and trigger any backup data
	local backupData = data._backupData
	if backupData then
		self.backup:transformTo(backupData)
		self._data._backupData = nil
	end
	
	-- Complete
	self.isLoaded = true
	self.loaded:Fire()
	return self.perm
end

function User:saveAsync()
	local callType = "save"
	
	-- Return if nothing needs saving
	if self._data._tableUpdated == false and self.backup._tableUpdated == false and self.onlySaveDataWhenChanged then
		return false
	end
	
	-- Cooldown to prevent two calls being made within 7 seconds
	self:_applyCooldown(callType)
	
	-- Save data
	local backupAction = false
	local success = self:_protectedCall(callType, function(finalAttempt)
		return self.dataStore:UpdateAsync(self.key, function(previousData)
			previousData = previousData or self._data
			if previousData._dataId == self._data._dataId then
				-- DataIds match, generate new unique DataId
				self._data._dataId = httpService:GenerateGUID()
				self._data._tableUpdated = false
			elseif finalAttempt then
				-- DataIds do not match, all retries failed, force add backup data to previousData and proceed to backup action 
				warn(string.format("%sDataIds do not match, all retries failed. Saved backup data and and proceeding to backup action.", self.errorMessageBase:format(callType)))
				previousData._backupData = self.backup
				backupAction = true
				return previousData
			else
				-- DataIds do not match, abort save and retry
				warn(string.format("%sDataIds do not match, retrying save...", self.errorMessageBase:format(callType)))
				return nil
			end
			-- Success, return data to be saved
			return self._data
		end)
	end)
	
	-- Clear backup data
	if success then
		self.saved:Fire()
		self.backup:clear()
	end
	
	-- All retries failed, resort to backup action
	if backupAction then
		-- Teleport away (not recommended)
		if self.teleportPlayerAwayOnFail then
			local player = self.player
			if player then
				teleportService:Teleport(game.PlaceId, player)
				return "FinalAttempt: teleported away"
			end
		end
		-- Keep player in server and reload data so dataIDs match
		self:loadAsync()
		return "FinalAttempt: reloaded data"
	end
	
	-- Return
	return success
end

function User:removeAsync()
	local callType = "remove"
	
	-- Cooldown
	self:_applyCooldown(callType)
	
	-- Remove key
	self:_protectedCall(callType, function()
		self.dataStore:RemoveAsync(self.key)
	end)
end

function User:_applyCooldown(callType)
	local currentTick = tick()
	local requestName = "_nextRequest"..callType
	local nextRequest = self[requestName] or currentTick
	if currentTick < nextRequest then
		wait(nextRequest - currentTick)
	end
	self[requestName] = nextRequest + self.cooldown
end

function User:_protectedCall(callType, func)
	local retries = self.maxRetries + 1
	for i = 1, retries do
		local finalAttempt = i == self.maxRetries + 1
		local success, value = pcall(func, finalAttempt)
		if success and (value or callType == "load") then
			return value
		elseif not success and finalAttempt then
			warn(self.errorMessageBase:format(callType), value)
		end
		wait(1)
	end
end



-- UTILITY METHODS
function User:setStartData(startData)
	if type(startData) ~= "table" then
		startData = {startData}
	end
	self.startData = startData
end

function User:initAutoSave(autoSaveInterval)
	local loopId = self.sessionId
	self.autoSaveInterval = tonumber(autoSaveInterval) or self.autoSaveInterval
	if self.saveLoopInitialized then
		return false
	end
	self.saveLoopInitialized = true
	self.autoSave = true
	local firstTime = true
	coroutine.wrap(function()
		self:waitUntilLoaded()
		while self.autoSave and loopId == self.sessionId do
			local currentTick = tick()
			if currentTick >= self.nextAutoSaveTick then
				self.nextAutoSaveTick = currentTick + self.autoSaveInterval
				local maxRetries = self.maxRetries
				if firstTime then
					self.maxRetries = 0
				end
				self:saveAsync()
				if firstTime then
					self.maxRetries = (self.maxRetries == 0 and maxRetries) or self.maxRetries
					firstTime = false
				end
			end
			RunService.Heartbeat:Wait()
		end
		self.saveLoopInitialized = nil
	end)()
end

function User:waitUntilLoaded()
	local loaded = self.isLoaded or self.loaded:Wait()
	return self.perm
end

function User:destroy()
	self.sessionId = nil
	self._maid:clean()
end



return User