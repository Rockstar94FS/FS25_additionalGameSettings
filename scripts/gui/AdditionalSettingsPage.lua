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
	self.elementMapping = {}

	return self
end

function AdditionalSettingsPage:initialize(settings)
	for _, setting in pairs(settings) do
		local element = setting.elementName and self[setting.elementName]

		if element then
			self.elementMapping[element] = setting
			AdditionalSettingsUtil.callFunction(setting, "onCreateElement", element)
		end
	end
end

function AdditionalSettingsPage:onGuiSetupFinished()
	AdditionalSettingsPage:superClass().onGuiSetupFinished(self)

	local oldDisableFunc = self.checkHUD.setDisabled

	for _, container in pairs(self.additionalSettingsLayout.elements) do
		if container:getDescendantByName("iconDisabled") ~= nil then
			function container.setDisabled(container, disabled)
				oldDisableFunc(container, disabled)
				container:getDescendantByName("iconDisabled"):setDisabled(not disabled)
			end
		end
	end
end

function AdditionalSettingsPage:updateAlternating()
	local isAlternate = true

	for _, container in pairs(self.additionalSettingsLayout.elements) do
		if container.name == "sectionHeader" then
			isAlternate = true
		elseif container.visible then
			container:setImageColor(nil, unpack(InGameMenuSettingsFrame.COLOR_ALTERNATING[isAlternate]))
			isAlternate = not isAlternate
		end
	end

	self.additionalSettingsLayout:invalidateLayout()
end

function AdditionalSettingsPage:updateAdditionalSettings()
	for element, settingsKey in pairs(self.elementMapping) do
		AdditionalSettingsUtil.callFunction(settingsKey, "onTabOpen", element)

		local class = element:class()

		if class == BinaryOptionElement then
			element:setIsChecked(settingsKey.state, true)
		elseif class == MultiTextOptionElement then
			element:setState(settingsKey.state + 1, nil, true)
		elseif class == OptionSliderElement then
			element:setState(settingsKey.state, nil, true)
		end
	end
end

function AdditionalSettingsPage:onFrameOpen()
	self.isDirty = false
	self:updateAlternating()
end

function AdditionalSettingsPage:onFrameClose()
	if self.isDirty then
		g_additionalSettingsManager:saveSettingsToXMLFile()
		self.isDirty = false
	end
end

function AdditionalSettingsPage:onTabOpen()
	self:updateAdditionalSettings()
end

function AdditionalSettingsPage:onClickCheckbox(state, checkboxElement)
	local originalTarget = g_additionalSettingsManager.settingsPage
	local setting = originalTarget.elementMapping[checkboxElement]

	if setting ~= nil then
		local newState = state == CheckedOptionElement.STATE_CHECKED

		setting.state = newState
		AdditionalSettingsUtil.callFunction(setting, "onStateChange", newState, checkboxElement, false)
		originalTarget.isDirty = true
	end
end

function AdditionalSettingsPage:onClickMultiOption(state, optionElement)
	local originalTarget = g_additionalSettingsManager.settingsPage
	local setting = originalTarget.elementMapping[optionElement]

	if setting ~= nil then
		local newState = state - 1

		setting.state = newState
		AdditionalSettingsUtil.callFunction(setting, "onStateChange", newState, optionElement, false)
		originalTarget.isDirty = true
	end
end

function AdditionalSettingsPage:onClickButton(buttonElement)
	local originalTarget = g_additionalSettingsManager.settingsPage
	local setting = originalTarget.elementMapping[buttonElement]

	if setting ~= nil then
		AdditionalSettingsUtil.callFunction(setting, "onClickButton", buttonElement)
		originalTarget.isDirty = true
	end
end

function AdditionalSettingsPage:onClickSlider(value, sliderElement)
	local originalTarget = g_additionalSettingsManager.settingsPage
	local setting = originalTarget.elementMapping[sliderElement]

	if setting ~= nil then
		setting.state = value
		AdditionalSettingsUtil.callFunction(setting, "onStateChange", value, sliderElement, false)
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