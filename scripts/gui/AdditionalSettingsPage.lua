--
-- AdditionalSettingsPage
--
-- @author Rockstar
-- @fs25 15/12/2024
--


AdditionalSettingsPage = {}

local AdditionalSettingsPage_mt = Class(AdditionalSettingsPage, FrameElement)
local baseDir = g_currentModDirectory

function AdditionalSettingsPage.register()
	local additionalSettingsPage = AdditionalSettingsPage.new()

	g_gui:loadGui(Utils.getFilename("gui/AdditionalSettingsPage.xml", baseDir), "AdditionalSettingsPage", additionalSettingsPage)

	return additionalSettingsPage
end

function AdditionalSettingsPage.new(subclass_mt)
	local self = FrameElement.new(nil, subclass_mt or AdditionalSettingsPage_mt)

	self.isDirty = false
	self.checkboxMapping = {}
	self.optionMapping = {}
	self.buttonMapping = {}

	return self
end

function AdditionalSettingsPage:initialize(settingsManager)
	local addittionalSettings = settingsManager.addittionalSettings

	self.checkboxMapping[self.checkHUD] = addittionalSettings.hud
	self.checkboxMapping[self.checkHourFormat] = addittionalSettings.hourFormat
	self.checkboxMapping[self.checkDialogBoxes] = addittionalSettings.dialogBoxes
	self.checkboxMapping[self.checkEasyMotorStart] = addittionalSettings.easyMotorStart
	self.checkboxMapping[self.checkAutostart] = addittionalSettings.autostart
	self.checkboxMapping[self.checkDoF] = addittionalSettings.dof
	self.checkboxMapping[self.checkCameraCollisions] = addittionalSettings.cameraCollisions
	self.checkboxMapping[self.checkGuiCamera] = addittionalSettings.guiCamera
	self.checkboxMapping[self.checkClockBackground] = addittionalSettings.clockBackground
	self.checkboxMapping[self.checkBlinkingWarnings] = addittionalSettings.blinkingWarnings
	self.checkboxMapping[self.checkClockBold] = addittionalSettings.clockBold
	self.checkboxMapping[self.checkTorch] = addittionalSettings.torch

	self.optionMapping[self.multiCrosshair] = addittionalSettings.crosshair
	self.optionMapping[self.multiDate] = addittionalSettings.date
	self.optionMapping[self.multiClockPosition] = addittionalSettings.clockPosition
	self.optionMapping[self.multiFadeEffect] = addittionalSettings.fadeEffect
	self.optionMapping[self.multiVehicleCamera] = addittionalSettings.vehicleCamera
	self.optionMapping[self.multiPlayerCamera] = addittionalSettings.playerCamera
	self.optionMapping[self.mulitStoreItems] = addittionalSettings.storeItems
	self.optionMapping[self.multiLighting] = addittionalSettings.lighting
	self.optionMapping[self.mulitFramerateLimiter] = addittionalSettings.framerateLimiter
	self.optionMapping[self.multiWalkMode] = addittionalSettings.walkMode
	self.optionMapping[self.multiCrouchMode] = addittionalSettings.crouchMode
	self.optionMapping[self.multiRunMode] = addittionalSettings.runMode

	self.buttonMapping[self.buttonDateColor] = addittionalSettings.clockColor
	self.buttonMapping[self.buttonHudColor] = addittionalSettings.hudColor

	for checkboxElement, settingsKey in pairs(self.checkboxMapping) do
		AdditionalSettingsUtil.callFunction(settingsKey, "onCreateElement", checkboxElement)
	end

	for optionElement, settingsKey in pairs(self.optionMapping) do
		AdditionalSettingsUtil.callFunction(settingsKey, "onCreateElement", optionElement)
	end

	for buttonElement, settingsKey in pairs(self.buttonMapping) do
		AdditionalSettingsUtil.callFunction(settingsKey, "onCreateElement", buttonElement)
	end

	self.settingsManager = settingsManager
end

function AdditionalSettingsPage:onGuiSetupFinished()
	AdditionalSettingsPage:superClass().onGuiSetupFinished(self)

	local oldDisableFunc = self.checkHUD.setDisabled

	local function elementDisableFunc(element, disabled)
		oldDisableFunc(element, disabled)
		element.parent:getDescendantByName("iconDisabled"):setDisabled(not disabled)
	end

	for _, container in pairs(self.additionalSettingsLayout.elements) do
		if container:getDescendantByName("iconDisabled") ~= nil then
			container.elements[1].setDisabled = elementDisableFunc
		end
	end
end

function AdditionalSettingsPage:updateAlternating()
	local isAlternate = true

	for _, container in pairs(self.additionalSettingsLayout.elements) do
		if container.name == "sectionHeader" then
			isAlternate = true
		elseif container:getIsVisibleNonRec() then
			container:setImageColor(nil, unpack(InGameMenuSettingsFrame.COLOR_ALTERNATING[isAlternate]))
			isAlternate = not isAlternate
		end
	end

	self.additionalSettingsLayout:invalidateLayout()
end

function AdditionalSettingsPage:updateAdditionalSettings()
	for checkboxElement, settingsKey in pairs(self.checkboxMapping) do
		AdditionalSettingsUtil.callFunction(settingsKey, "onTabOpen", checkboxElement)
		checkboxElement:setIsChecked(settingsKey.active, true)
	end

	for optionElement, settingsKey in pairs(self.optionMapping) do
		AdditionalSettingsUtil.callFunction(settingsKey, "onTabOpen", optionElement)
		optionElement:setState(settingsKey.state + 1, nil, true)
	end

	for buttonElement, settingsKey in pairs(self.buttonMapping) do
		AdditionalSettingsUtil.callFunction(settingsKey, "onTabOpen", buttonElement)
	end
end

function AdditionalSettingsPage:onFrameOpen()
	self.isDirty = false
	self:updateAlternating()
end

function AdditionalSettingsPage:onFrameClose()
	if self.isDirty then
		self.settingsManager:saveSettingsToXMLFile()
		self.isDirty = false
	end
end

function AdditionalSettingsPage:onTabOpen()
	self:updateAdditionalSettings()
end

function AdditionalSettingsPage:onClickCheckbox(state, checkboxElement)
	local originalTarget = g_additionalSettingsManager.settingsPage
	local checkboxMapping = originalTarget.checkboxMapping[checkboxElement]

	if checkboxMapping ~= nil then
		local newState = state == CheckedOptionElement.STATE_CHECKED

		checkboxMapping.active = newState
		AdditionalSettingsUtil.callFunction(checkboxMapping, "onStateChange", newState, checkboxElement, false)
		originalTarget.isDirty = true
	end
end

function AdditionalSettingsPage:onClickMultiOption(state, optionElement)
	local originalTarget = g_additionalSettingsManager.settingsPage
	local optionMapping = originalTarget.optionMapping[optionElement]

	if optionMapping ~= nil then
		local newState = state - 1

		optionMapping.state = newState
		AdditionalSettingsUtil.callFunction(optionMapping, "onStateChange", newState, optionElement, false)
		originalTarget.isDirty = true
	end
end

function AdditionalSettingsPage:onClickButton(buttonElement)
	local originalTarget = g_additionalSettingsManager.settingsPage
	local buttonMapping = originalTarget.buttonMapping[buttonElement]

	if buttonMapping ~= nil then
		AdditionalSettingsUtil.callFunction(buttonMapping, "onClickButton", buttonElement)
		originalTarget.isDirty = true
	end
end

function AdditionalSettingsPage:onClickAdditionalSettings()
	g_inGameMenu.pageSettings.subCategoryPaging:setState(InGameMenuSettingsFrame.SUB_CATEGORY.ADDITIONAL_SETTINGS, true)
end

function AdditionalSettingsPage:onClickLockedIcon()
end

function AdditionalSettingsPage:onFocusLockedIcon(icon)
	self.additionalSettingsLayout:scrollToMakeElementVisible(icon)
end