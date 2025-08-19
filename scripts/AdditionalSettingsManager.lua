--
-- AdditionalSettingsManager
--
-- @author Rockstar
-- @date 27/03/2021
--
--
-- @fs22 24/11/2021
--
--
-- @fs25 07/12/2024
--


gEnv = getmetatable(_G).__index

AdditionalSettingsManager = {
	LOAD_STATE = {
		NO = 0,
		MAP_LOAD = 1,
		MAP_LOAD_FINISHED = 2,
		MISSION_START = 3
	}
}

local AdditionalSettingsManager_mt = Class(AdditionalSettingsManager)

function AdditionalSettingsManager.new(modDir, settingsDir, modEnv, args, customMt)
	local self = setmetatable({}, customMt or AdditionalSettingsManager_mt)

	AdditionalSettingsUtil.registerEvent("onLoad")
	AdditionalSettingsUtil.registerEvent("onLoadFinished")
	AdditionalSettingsUtil.registerEvent("onMissionStarted")
	AdditionalSettingsUtil.registerEvent("onDelete")
	AdditionalSettingsUtil.registerEvent("onUpdate")
	AdditionalSettingsUtil.registerEvent("onDraw")
	AdditionalSettingsUtil.registerEvent("onPreDraw")
	AdditionalSettingsUtil.registerEvent("onPostDraw")

	addModEventListener(self)

	g_currentMission:registerToLoadOnMapFinished(self)
	g_messageCenter:subscribeOneshot(MessageType.CURRENT_MISSION_LOADED, self.onMissionStarted, self)

	createFolder(settingsDir)

	self.modSettings = {
		directory = settingsDir,
		xmlFilename = settingsDir .. "settings.xml"
	}

	self.baseDirectory = modDir
	self.addonsDirectory = modDir .. "addons/"
	self.customEnvironment = modEnv

	self.modVersion = g_modManager:getModByName(modEnv).version
	self.resetAllowed = false

	self:addModEnvironmentTexts()
	self.addittionalSettings = self:loadAdditionalSettings()

	local gui = AdditionalSettingsGui.new()
	local tabPosition = 3

	self.settingsPage = gui:addPage(tabPosition)

	return self
end

function AdditionalSettingsManager:loadAdditionalSettings()
	return {
		hud = HUDSetting.new(),
		crosshair = CrosshairSetting.new(),
		date = DateSetting.new(),
		clockPosition = ClockPositionSetting.new(),
		hourFormat = HourFormatSetting.new(),
		fadeEffect = FadeEffectSetting.new(),
		dialogBoxes = DialogBoxesSetting.new(),
		vehicleCamera = VehicleCameraSetting.new(),
		playerCamera = PlayerCameraSetting.new(),
		easyMotorStart = EasyMotorStartSetting.new(),
		autostart = AutostartSetting.new(),
		storeItems = StoreItemsSetting.new(),
		lighting = LightingSetting.new(),
		dof = DoFSetting.new(),
		cameraCollisions = CameraCollisionsSetting.new(),
		guiCamera = GuiCameraSetting.new(),
		quitGame = QuitGameSetting.new(),
		clockColor = ClockColorSetting.new(),
		framerateLimiter = FramerateLimiterSetting.new(),
		clockBackground = ClockBackgroundSetting.new(),
		blinkingWarnings = BlinkingWarningsSetting.new(),
		clockBold = ClockBoldSetting.new(),
		hudColor = HudColorSetting.new(),
		torch = TorchSetting.new(),
		walkMode = WalkModeSetting.new(),
		crouchMode = CrouchModeSettings.new(),
		runMode = RunModeSettings.new(),
		debug = DebugSettings.new()
	}
end

function AdditionalSettingsManager:addModEnvironmentTexts()
	for name, value in pairs(g_i18n.texts) do
		if string.startsWith(name, "global_") then
			gEnv.g_i18n:setText(name:sub(8), value)
		end
	end

	if g_languageShort == "pl" and g_i18n:getText("ui_inGameMenuDevices") == "Urządzeń" then
		local replacedText = "Urządzenia"

		for _, subCategoryTab in pairs(g_inGameMenu.pageSettings.subCategoryTabs) do
			if subCategoryTab.text == utf8ToUpper(g_i18n:getText("ui_inGameMenuDevices")) then
				subCategoryTab:setText(replacedText)

				if subCategoryTab.elements[1] ~= nil then
					subCategoryTab.elements[1]:setSize(subCategoryTab.size[1])
				end

				break
			end
		end

		gEnv.g_i18n:setText("ui_inGameMenuDevices", replacedText)
	end
end

function AdditionalSettingsManager:loadMap(filename)
	AdditionalSettingsUtil.appendedFunction(FSCareerMissionInfo, "saveToXMLFile", self, "saveToXMLFile")
	AdditionalSettingsUtil.overwrittenFunction(gEnv, "draw", self, "env_draw", true)

	AdditionalSettingsUtil.raiseEvent("onLoad", filename)

	self.settingStates = self:loadSettingsFromXMLFile()
	self:applySettingStates(AdditionalSettingsManager.LOAD_STATE.MAP_LOAD)

	if self.settingsPage ~= nil then
		self.settingsPage:initialize(self)
	end
end

function AdditionalSettingsManager:onLoadMapFinished()
	AdditionalSettingsUtil.raiseEvent("onLoadFinished")
	self:applySettingStates(AdditionalSettingsManager.LOAD_STATE.MAP_LOAD_FINISHED)
end

function AdditionalSettingsManager:onMissionStarted()
	AdditionalSettingsUtil.raiseEvent("onMissionStarted")
	self:applySettingStates(AdditionalSettingsManager.LOAD_STATE.MISSION_START)

	self.settingStates = nil
end

function AdditionalSettingsManager:deleteMap()
	AdditionalSettingsUtil.raiseEvent("onDelete")
end

function AdditionalSettingsManager:update(dt)
	AdditionalSettingsUtil.raiseEvent("onUpdate", dt)
end

function AdditionalSettingsManager:draw()
	AdditionalSettingsUtil.raiseEvent("onDraw")
end

function AdditionalSettingsManager:env_draw(superFunc)
	local isRunning = g_currentMission ~= nil and g_currentMission.isLoaded and not g_gui:getIsGuiVisible() and not g_currentMission.hud:getIsFading() and g_currentMission.isRunning

	if isRunning then
		AdditionalSettingsUtil.raiseEvent("onPreDraw")
	end

	superFunc()

	if isRunning then
		AdditionalSettingsUtil.raiseEvent("onPostDraw")
	end
end

function AdditionalSettingsManager:getSettingByName(name)
	return self.addittionalSettings[name]
end

function AdditionalSettingsManager:getSettingStateByName(name)
	local setting = self:getSettingByName(name)

	if setting ~= nil then
		if setting.active ~= nil then
			return setting.active
		elseif setting.state ~= nil then
			return setting.state
		end
	end
end

function AdditionalSettingsManager:getUIElement(setting)
	if self.settingsPage ~= nil then
		for checkbox, key in pairs(self.settingsPage.checkboxMapping) do
			if key == setting then
				return checkbox
			end
		end

		for option, key in pairs(self.settingsPage.optionMapping) do
			if key == setting then
				return option
			end
		end

		for button, key in pairs(self.settingsPage.buttonMapping) do
			if key == setting then
				return button
			end
		end
	end
end

function AdditionalSettingsManager:saveToXMLFile(missionInfo)
	self:saveSettingsToXMLFile()
end

function AdditionalSettingsManager:saveSettingsToXMLFile()
	local xmlFile = XMLFile.create("additionalSettingsXML", self.modSettings.xmlFilename, "settings")

	if xmlFile ~= nil then
		xmlFile:setString("settings#version", self.modVersion)

		for id, setting in pairs(self.addittionalSettings) do
			if setting.loadState ~= AdditionalSettingsManager.LOAD_STATE.NO then
				local key = string.format("settings.%s", id)
				local customState = AdditionalSettingsUtil.callFunction(setting, "onSaveSetting", xmlFile, key)

				if not customState then
					if setting.active ~= nil then
						xmlFile:setBool(key, setting.active)
					elseif setting.state ~= nil then
						xmlFile:setInt(key, setting.state)
					end
				end
			end
		end

		xmlFile:save()
		xmlFile:delete()
	end
end

function AdditionalSettingsManager:loadSettingsFromXMLFile()
	local settingStates = {}
	local xmlFile = XMLFile.loadIfExists("additionalSettingsXML", self.modSettings.xmlFilename)

	if xmlFile ~= nil then
		if self.resetAllowed and self.modVersion ~= xmlFile:getString("settings#version") then
			AdditionalSettingsUtil.warning("Mod update detected, settings will be reset.")
		else
			for id, setting in pairs(self.addittionalSettings) do
				local savedState = nil
				local key = string.format("settings.%s", id)
				local customState, savedState = AdditionalSettingsUtil.callFunction(setting, "onLoadSetting", xmlFile, key)

				if not customState then
					if setting.active ~= nil then
						local active = xmlFile:getBool(key)

						if active ~= nil and setting.active ~= active then
							savedState = active
						end
					elseif setting.state ~= nil then
						local state = xmlFile:getInt(key)

						if state ~= nil and setting.state ~= state then
							savedState = state
						end
					end
				end

				settingStates[id] = savedState
			end
		end

		xmlFile:delete()
	end

	return settingStates
end

function AdditionalSettingsManager:applySettingStates(loadState)
	for id, setting in pairs(self.addittionalSettings) do
		if setting.loadState == loadState then
			local state = self.settingStates[id]

			if state ~= nil then
				if setting.active ~= nil and setting.active ~= state then
					setting.active = state
					AdditionalSettingsUtil.callFunction(setting, "onStateChange", state, self:getUIElement(setting), true)
				elseif setting.state ~= nil and setting.state ~= state then
					setting.state = state
					AdditionalSettingsUtil.callFunction(setting, "onStateChange", state, self:getUIElement(setting), true)
				end
			end
		end
	end
end

local function init(modDir, settingsDir,  modEnv)
	Mission00.setMissionInfo = Utils.prependedFunction(Mission00.setMissionInfo, function (...)
		gEnv.g_additionalSettingsManager = AdditionalSettingsManager.new(modDir, settingsDir, modEnv, {...})
	end)
end

init(g_currentModDirectory, g_currentModSettingsDirectory, g_currentModName)