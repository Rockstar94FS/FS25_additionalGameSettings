--
-- AdditionalSettingsGui
--
-- @author Rockstar
-- @fs25 16/12/2024
--


AdditionalSettingsGui = {}

local AdditionalSettingsGui_mt = Class(AdditionalSettingsGui)

function AdditionalSettingsGui.new(custom_mt)
	local self = setmetatable({}, custom_mt or AdditionalSettingsGui_mt)
	local settingsFrame = g_inGameMenu.pageSettings

	AdditionalSettingsUtil.appendedFunction(settingsFrame, "onFrameOpen", self, "settings_onFrameOpen")
	AdditionalSettingsUtil.prependedFunction(settingsFrame, "onFrameClose", self, "settings_onFrameClose")
	AdditionalSettingsUtil.overwrittenFunction(settingsFrame.subCategoryPaging, "onClickCallback", self, "settings_onClickCallback")
	AdditionalSettingsUtil.overwrittenFunction(settingsFrame, "inputEvent", self, "settings_inputEvent")

	local saveFrame = g_inGameMenu.pageSave

	AdditionalSettingsUtil.appendedFunction(saveFrame, "onFrameOpen", self, "save_onFrameOpen")
	AdditionalSettingsUtil.overwrittenFunction(saveFrame.gameSettingsButton, "onClickCallback", self, "save_onButtonGameSettings")

	self.settingsFrame = settingsFrame
	self.screenController = nil

	return self
end

function AdditionalSettingsGui:addPage(position)
	position = math.min(AdditionalSettingsUtil.tableCount(InGameMenuSettingsFrame.SUB_CATEGORY) + 1, position)

	local currentGui = FocusManager.currentGui
	local screenController = AdditionalSettingsPage.register()
	local settingsFrame = self.settingsFrame
	local additionalSettingsPage = screenController.additionalSettingsPage
	local additionalSettingsTab = screenController.additionalSettingsTab

	self:addElementAtPosition(additionalSettingsPage, settingsFrame.subCategoryPages[1].parent, position)
	self:addElementAtPosition(additionalSettingsTab, settingsFrame.subCategoryBox, position)

	table.insert(settingsFrame.subCategoryPages, position, additionalSettingsPage)
	table.insert(settingsFrame.subCategoryTabs, position, additionalSettingsTab)

	for subCategory, id in pairs(InGameMenuSettingsFrame.SUB_CATEGORY) do
		if id >= position then
			InGameMenuSettingsFrame.SUB_CATEGORY[subCategory] = id + 1
		end
	end

	InGameMenuSettingsFrame.SUB_CATEGORY.ADDITIONAL_SETTINGS = position

	table.insert(InGameMenuSettingsFrame.HEADER_SLICES, position, "gui.icon_options_device")
	table.insert(InGameMenuSettingsFrame.HEADER_TITLES, position, "ags_ui_ingameMenuAdditionalSettings")

	settingsFrame:updateAbsolutePosition()

	local getDescendants = settingsFrame.getDescendants

	settingsFrame.getDescendants = function()
		return additionalSettingsPage:getDescendants()
	end

	settingsFrame:exposeControlsAsFields(settingsFrame.name)
	settingsFrame.getDescendants = getDescendants

	additionalSettingsPage:setTarget(settingsFrame, additionalSettingsPage.target)
	additionalSettingsTab:setTarget(settingsFrame, additionalSettingsTab.target)

	FocusManager:setGui(settingsFrame.name)
	FocusManager:removeElement(additionalSettingsPage)
	FocusManager:removeElement(additionalSettingsTab)
	FocusManager:loadElementFromCustomValues(additionalSettingsPage)
	FocusManager:loadElementFromCustomValues(additionalSettingsTab)
	FocusManager:setGui(currentGui)

	self.screenController = screenController

	return screenController
end

function AdditionalSettingsGui:addElementAtPosition(element, target, position)
	if element.parent ~= nil then
		element.parent:removeElement(element)
	end

	table.insert(target.elements, position, element)

	element.parent = target
end

function AdditionalSettingsGui:settings_onFrameOpen(settingsFrame)
	settingsFrame.isOpening = true

	if self.screenController ~= nil then
		self.screenController:onFrameOpen()
	end

	settingsFrame.isOpening = false
end

function AdditionalSettingsGui:settings_onFrameClose(settingsFrame)
	if self.screenController ~= nil then
		self.screenController:onFrameClose()
	end
end

function AdditionalSettingsGui:save_onFrameOpen(saveFrame)
	if saveFrame.serverSettingsButton ~= nil then
		saveFrame.serverSettingsButton:setVisible(saveFrame.hasMasterRights and g_currentMission.missionDynamicInfo.isMultiplayer)
		saveFrame.buttonsLayout:invalidateLayout()
	end
end

function AdditionalSettingsGui:save_onButtonGameSettings(saveFrame, superFunc)
	local subCategoryPaging = self.settingsFrame.subCategoryPaging
	local state = tonumber(subCategoryPaging.texts[subCategoryPaging:getState()])

	superFunc(saveFrame)

	-- if state ~= InGameMenuSettingsFrame.SUB_CATEGORY.CONTROLS then
		subCategoryPaging:setState(state, true)
	-- end
end

function AdditionalSettingsGui:settings_onClickCallback(settingsFrame, superFunc, state)
	local retValue = superFunc(settingsFrame, state)
	local value = settingsFrame.subCategoryPaging.texts[state]

	if value ~= nil and tonumber(value) == InGameMenuSettingsFrame.SUB_CATEGORY.ADDITIONAL_SETTINGS then
		if self.screenController ~= nil then
			self.screenController:onTabOpen()
		end

		local additionalSettingsLayout = settingsFrame.additionalSettingsLayout

		settingsFrame.settingsSlider:setDataElement(additionalSettingsLayout)
		FocusManager:linkElements(settingsFrame.subCategoryPaging, FocusManager.TOP, additionalSettingsLayout.elements[#additionalSettingsLayout.elements].elements[1])
		FocusManager:linkElements(settingsFrame.subCategoryPaging, FocusManager.BOTTOM, additionalSettingsLayout:findFirstFocusable(true))
	end

	return retValue
end

function AdditionalSettingsGui:settings_inputEvent(settingsFrame, superFunc, action, value, eventUsed)
	local retValue = superFunc(settingsFrame, action, value, eventUsed)
	local pressedAccept = false
	local element = FocusManager.currentFocusData.focusElement

	if element ~= nil and not element.needExternalClick then
		pressedAccept = action == InputAction.MENU_ACCEPT

		if pressedAccept and not FocusManager:isFocusInputLocked(action) and element:getIsFocused() and element:getIsVisible() then
			FocusManager.focusSystemMadeChanges = true
			element:onFocusActivate()
			FocusManager.focusSystemMadeChanges = false
		end
	end

	return retValue or pressedAccept
end