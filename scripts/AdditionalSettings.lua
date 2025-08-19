--
-- AdditionalSettings
--
-- @author Rockstar
-- @fs25 07/12/2024
--


HUDSetting = {}

local HUDSetting_mt = Class(HUDSetting)

function HUDSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or HUDSetting_mt)

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	return self
end

function HUDSetting:onStateChange(state, checkboxElement, loadFromSavegame)
	g_currentMission.hud:setIsVisible(state)

	if checkboxElement ~= nil then
		local target = checkboxElement.target
		local disabled = not state or g_additionalSettingsManager:getSettingStateByName("date") == 0

		target.multiCrosshair:setDisabled(not state)
		target.multiDate:setDisabled(not state)
		target.checkHourFormat:setDisabled(not state)
		target.buttonHudColor:setDisabled(not state)
		target.multiClockPosition:setDisabled(disabled)
		target.checkClockBackground:setDisabled(disabled)
		target.buttonDateColor:setDisabled(disabled)
		target.checkClockBold:setDisabled(disabled)
	end
end

function HUDSetting:onTabOpen(checkboxElement)
	self.active = g_currentMission.hud:getIsVisible()
end


CrosshairSetting = {}

local CrosshairSetting_mt = Class(CrosshairSetting)

function CrosshairSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or CrosshairSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	return self
end

function CrosshairSetting:onLoad(filename)
	AdditionalSettingsUtil.appendedFunction(HandToolHands, "onLoad", self, "onLoadHands")
	AdditionalSettingsUtil.appendedFunction(HandToolChainsaw, "onLoad", self, "onLoadChainsaw")
	AdditionalSettingsUtil.appendedFunction(HandToolHorseBrush, "onLoad", self, "onLoadHorseBrush")
	AdditionalSettingsUtil.appendedFunction(HandToolSprayCan, "onUpdate", self, "onUpdateSprayCan")
end

function CrosshairSetting:onLoadHands(handToolHands, ...)
	if handToolHands.isClient then
		local specHands = handToolHands.spec_hands

		self:overwriteDefault(specHands.crosshair)
		self:overwriteInteract(specHands.pickUpCrosshair)
		self:overwriteInteract(specHands.throwCrosshair)
	end
end

function CrosshairSetting:onLoadChainsaw(handToolChainsaw, ...)
	if handToolChainsaw.isClient then
		local specChainsaw = handToolChainsaw.spec_chainsaw

		self:overwriteDefault(specChainsaw.crosshair)
	end
end

function CrosshairSetting:onLoadHorseBrush(handToolHorseBrush, ...)
	if handToolHorseBrush.isClient then
		local specHorseBrush = handToolHorseBrush.spec_horseBrush

		self:overwriteDefault(specHorseBrush.defaultCrosshair)
		self:overwriteInteract(specHorseBrush.brushCrosshair)
	end
end

function CrosshairSetting:onUpdateSprayCan(handToolSprayCan, ...)
	if handToolSprayCan.isClient then
		local specSprayCan = handToolSprayCan.spec_sprayCan

		if handToolSprayCan.overwrittenTreeTypeCrosshair ~= specSprayCan.treeTypeCrosshair then
			handToolSprayCan.overwrittenTreeTypeCrosshair = specSprayCan.treeTypeCrosshair
			self:overwriteInteract(specSprayCan.treeTypeCrosshair, function () return specSprayCan.foundTargetTree ~= nil end)
		end

		if handToolSprayCan.overwriteTreeCrosshair == nil then
			handToolSprayCan.overwriteTreeCrosshair = true
			self:overwriteInteract(specSprayCan.treeCrosshair)
		end
	end
end

function CrosshairSetting:overwriteDefault(crosshair, func)
	local render = crosshair.render

	crosshair.render = function(...)
		if self.state == 0 and (func == nil or func()) then
			render(...)
		end
	end
end

function CrosshairSetting:overwriteInteract(crosshair, func)
	local render = crosshair.render

	crosshair.render = function(...)
		if self.state ~= 2 and (func == nil or func()) then
			render(...)
		end
	end
end

function CrosshairSetting:onTabOpen(optionElement)
	optionElement:setDisabled(not g_currentMission.hud:getIsVisible())
end


DateSetting = {}

local DateSetting_mt = Class(DateSetting)

function DateSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or DateSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)
	AdditionalSettingsUtil.registerEventListener("onDelete", self)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	self.dateFormat = ""

	self.blinking = true
	self.blinkTime = 0
	self.blinkSec = -1

	self:updateClockSettings()

	local function getDateText(text)
		if g_i18n:hasText("ags_" .. text) then
			return g_i18n:getText("ags_" .. text)
		end

		return g_i18n:getText(text)
	end

	self.dayName = {
		["Monday"] = getDateText("ui_financesDay1"),
		["Tuesday"] = getDateText("ui_financesDay2"),
		["Wednesday"] = getDateText("ui_financesDay3"),
		["Thursday"] = getDateText("ui_financesDay4"),
		["Friday"] = getDateText("ui_financesDay5"),
		["Saturday"] = getDateText("ui_financesDay6"),
		["Sunday"] = getDateText("ui_financesDay7")
	}

	self.monthName = {
		["January"] = getDateText("ui_month1"),
		["February"] = getDateText("ui_month2"),
		["March"] = getDateText("ui_month3"),
		["April"] = getDateText("ui_month4"),
		["May"] = getDateText("ui_month5"),
		["June"] = getDateText("ui_month6"),
		["July"] = getDateText("ui_month7"),
		["August"] = getDateText("ui_month8"),
		["September"] = getDateText("ui_month9"),
		["October"] = getDateText("ui_month10"),
		["November"] = getDateText("ui_month11"),
		["December"] = getDateText("ui_month12")
	}

	local function dateSubstr(text, indexOfFirstCharacter, indexOfLastCharacter, dot)
		local trimText = utf8Substr(text, indexOfFirstCharacter, indexOfLastCharacter)

		if dot and utf8Strlen(text) > indexOfLastCharacter then
			trimText = trimText .. "."
		end

		return trimText
	end

	self.dayNameShort = {}

	for dayName, text in pairs(self.dayName) do
		self.dayNameShort[dayName] = dateSubstr(text, 0, 3, false)
	end

	self.monthNameShort = {}

	for monthName, text in pairs(self.monthName) do
		self.monthNameShort[monthName] = dateSubstr(text, 0, 3, true)
	end

	local dateString = "%d/%m/%Y"

	if g_languageShort == "en" then
		dateString = "%Y-%m-%d"
	elseif g_languageShort == "de" then
		dateString = "%d.%m.%Y"
	elseif g_languageShort == "jp" then
		dateString = "%Y/%m/%d"
	end

	self.dateString = dateString

	self.bgOverlay = g_overlayManager:createOverlay("gui.shortcutBox1_middle", 0, 0, 0, 0)
	self.bgOverlayRight = g_overlayManager:createOverlay("gui.shortcutBox1_right", 0, 0, 0, 0)
	self.bgOverlayLeft = g_overlayManager:createOverlay("gui.shortcutBox1_left", 0, 0, 0, 0)

	return self
end

function DateSetting:onLoad(filename)
	AdditionalSettingsUtil.prependedFunction(g_currentMission.hud.gameInfoDisplay, "draw", self, "draw")

	g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.UI_SCALE], self.onUIScaleChanged, self)
end

function DateSetting:onDelete()
	g_messageCenter:unsubscribeAll(self)
end

function DateSetting:onStateChange(state, optionElement, loadFromSavegame)
	self:updateCurrentDateFormat(state, g_additionalSettingsManager:getSettingStateByName("hourFormat"))

	if optionElement ~= nil then
		local target = optionElement.target
		local disabled = not g_currentMission.hud:getIsVisible() or state == 0

		target.multiClockPosition:setDisabled(disabled)
		target.checkClockBackground:setDisabled(disabled)
		target.buttonDateColor:setDisabled(disabled)
		target.checkClockBold:setDisabled(disabled)
	end
end

function DateSetting:onCreateElement(optionElement)
	local textHour = g_i18n:getText("ags_ui_currentTimeHour")
	local textDate = g_i18n:getText("ags_ui_currentTimeDate")
	local textDateShort = g_i18n:getText("ags_ui_currentTimeDateShort")
	local textDateLong = g_i18n:getText("ags_ui_currentTimeDateLong")

	optionElement:setTexts({
		g_i18n:getText("ui_off"),
		textHour,
		string.format("%s + %s", textHour, textDate),
		string.format("%s + %s (%s)", textHour, textDate, textDateShort),
		string.format("%s + %s (%s)", textHour, textDate, textDateLong)
	})
end

function DateSetting:onTabOpen(optionElement)
	optionElement:setDisabled(not g_currentMission.hud:getIsVisible())
end

function DateSetting:onUIScaleChanged(uiScale)
	self:updateClockSettings()
end

function DateSetting:updateClockSettings()
	self.textSize = g_currentMission.hud.gameInfoDisplay.moneyTextSize * 0.8
	self.bgOffset = 0.3 * self.textSize

	local playerLeftX = g_hudAnchorLeft
	local playerRightX = g_hudAnchorRight
	local playerBottomY = g_hudAnchorBottom / 2
	local playerTopY = 1 - playerBottomY
	local darkBg = {0, 0, 0, 0.8}
	local lightBg = {0.00439, 0.00478, 0.00368, 0.65}
	local ingameMapBg = {0, 0, 0, 0.75}

	self.clockSettings = {
		[0] = {
			horizontalAlignment = RenderText.ALIGN_RIGHT,
			verticalAligment = RenderText.VERTICAL_ALIGN_MIDDLE,
			playerBgColor = darkBg,
			playerPosition = {
				posX = playerRightX,
				posY = playerTopY
			}
		},
		[1] = {
			horizontalAlignment = RenderText.ALIGN_RIGHT,
			verticalAligment = RenderText.VERTICAL_ALIGN_MIDDLE,
			playerBgColor = lightBg,
			playerPosition = {
				posX = playerRightX,
				posY = playerBottomY
			}
		},
		[2] = {
			horizontalAlignment = RenderText.ALIGN_LEFT,
			verticalAligment = RenderText.VERTICAL_ALIGN_MIDDLE,
			playerBgColor = lightBg,
			playerPosition = {
				posX = playerLeftX,
				posY = playerTopY
			}
		},
		[3] = {
			horizontalAlignment = RenderText.ALIGN_LEFT,
			verticalAligment = RenderText.VERTICAL_ALIGN_MIDDLE,
			playerBgColor = ingameMapBg,
			playerPosition = {
				posX = playerLeftX,
				posY = playerBottomY
			}
		},
		[4] = {
			horizontalAlignment = RenderText.ALIGN_CENTER,
			verticalAligment = RenderText.VERTICAL_ALIGN_MIDDLE,
			playerBgColor = lightBg,
			playerPosition = {
				posX = 0.5,
				posY = playerTopY
			}
		},
		[5] = {
			horizontalAlignment = RenderText.ALIGN_CENTER,
			verticalAligment = RenderText.VERTICAL_ALIGN_MIDDLE,
			playerBgColor = lightBg,
			playerPosition = {
				posX = 0.5,
				posY = playerBottomY
			}
		}
	}
end

function DateSetting:updateCurrentDateFormat(state, hourFormat)
	local hour = "%H"
	local am_pm = ""

	if not hourFormat then
		hour = "%I"
		am_pm = " %p"
	end

	local dateFormat = hour .. ":%M:%S" .. am_pm

	if state == 2 then
		dateFormat = dateFormat .. " | " .. self.dateString
	elseif state == 3 or state == 4 then
		dateFormat = dateFormat .. " | dayName, monthDay monthName %Y"
	end

	self.dateFormat = dateFormat
end

function DateSetting:draw(gameInfoDisplay)
	if self.state ~= 0 and g_gui.currentGuiName == "" then
		local dateFormat = self.dateFormat

		if self.state == 3 or self.state == 4 then
			local monthDay = string.gsub(getDate("%d"), "^0+", "")
			local dayName = getDate("%A")
			local monthName = getDate("%B")
			local dayNameM = self.dayName[dayName]
			local monthNameM = self.monthName[monthName]

			if self.state == 3 then
				dayNameM = self.dayNameShort[dayName]
				monthNameM = self.monthNameShort[monthName]
			end

			dateFormat = string.gsub(dateFormat, "monthDay", monthDay)
			dateFormat = string.gsub(dateFormat, "dayName", dayNameM or dayName)
			dateFormat = string.gsub(dateFormat, "monthName", monthNameM or monthName)
		end

		dateFormat = getDate(dateFormat)

		if self.blinking then
			local seconds = tonumber(dateFormat:sub(7, 8))

			if seconds ~= nil then
				if seconds ~= self.blinkSec then
					self.blinkSec = seconds
					self.blinkTime = 0
				else
					self.blinkTime = self.blinkTime + g_currentDt
				end

				if self.blinkTime <= 250 or self.blinkTime >= 750 then
					dateFormat = string.gsub(dateFormat, ":", " ")
				end
			end
		end

		local clockSettings = self.clockSettings[g_additionalSettingsManager:getSettingStateByName("clockPosition")]

		setTextBold(g_additionalSettingsManager:getSettingStateByName("clockBold"))
		setTextAlignment(clockSettings.horizontalAlignment)
		setTextVerticalAlignment(clockSettings.verticalAligment)

		local position = clockSettings.playerPosition

		if clockSettings.vehiclePosition ~= nil and g_currentMission.hud.controlledVehicle ~= nil then
			position = clockSettings.vehiclePosition
		end

		local posX, posY = position.posX, position.posY
		local textSize = self.textSize

		if g_additionalSettingsManager:getSettingStateByName("clockBackground") then
			local bgOffset = self.bgOffset

			if clockSettings.bgOffset ~= nil then
				posX = posX + clockSettings.bgOffset
			end

			local bgOverlay = self.bgOverlay
			local bgOverlayRight = self.bgOverlayRight
			local bgOverlayLeft = self.bgOverlayLeft
			local width, height = getTextWidth(textSize, dateFormat), getTextHeight(textSize, dateFormat)
			local bgPosX, bgPosY = posX, posY - height * 0.12
			local bgWidth, bgHeight = width + bgOffset * 2, height + bgOffset * 2
			local corWidth, corHeight = bgHeight * 0.135, bgHeight

			bgWidth = bgWidth - (corWidth * 2)

			local rightPosX = bgPosX
			local leftPosX = bgPosX - bgWidth - corWidth
			local bgPosX1 = bgPosX - corWidth
			local horizontalAlignment = Overlay.ALIGN_HORIZONTAL_CENTER

			if clockSettings.horizontalAlignment == RenderText.ALIGN_RIGHT then
				horizontalAlignment = Overlay.ALIGN_HORIZONTAL_RIGHT
				posX = posX - bgOffset
			elseif clockSettings.horizontalAlignment == RenderText.ALIGN_LEFT then
				horizontalAlignment = Overlay.ALIGN_HORIZONTAL_LEFT
				posX = posX + bgOffset
				leftPosX = bgPosX
				rightPosX = bgPosX + bgWidth + corWidth
				bgPosX1 = bgPosX + corWidth
			elseif clockSettings.horizontalAlignment == RenderText.ALIGN_CENTER then
				horizontalAlignment = Overlay.ALIGN_HORIZONTAL_CENTER

				local corOffset = (bgWidth + corWidth) * 0.5

				leftPosX = bgPosX - corOffset
				rightPosX = bgPosX + corOffset
				bgPosX1 = bgPosX
			end

			local verticalAligment = Overlay.ALIGN_VERTICAL_MIDDLE

			if clockSettings.verticalAligment == RenderText.VERTICAL_ALIGN_TOP then
				verticalAligment = Overlay.ALIGN_VERTICAL_TOP
				posY = posY - bgOffset
			elseif clockSettings.verticalAligment == RenderText.VERTICAL_ALIGN_BOTTOM then
				verticalAligment = Overlay.ALIGN_VERTICAL_BOTTOM
				posY = posY + bgOffset
			end

			local backgroundColor = clockSettings.playerBgColor

			if clockSettings.vehicleBgColor ~= nil and g_currentMission.hud.controlledVehicle ~= nil then
				backgroundColor = clockSettings.vehicleBgColor
			end

			bgOverlay:setPosition(bgPosX1, bgPosY)
			bgOverlay:setDimension(bgWidth, bgHeight)
			bgOverlay:setColor(unpack(backgroundColor))
			bgOverlay:setAlignment(verticalAligment, horizontalAlignment)
			bgOverlay:draw()

			bgOverlayRight:setPosition(rightPosX, bgPosY)
			bgOverlayRight:setDimension(corWidth, corHeight)
			bgOverlayRight:setColor(unpack(backgroundColor))
			bgOverlayRight:setAlignment(verticalAligment, horizontalAlignment)
			bgOverlayRight:draw()

			bgOverlayLeft:setPosition(leftPosX, bgPosY)
			bgOverlayLeft:setDimension(corWidth, corHeight)
			bgOverlayLeft:setColor(unpack(backgroundColor))
			bgOverlayLeft:setAlignment(verticalAligment, horizontalAlignment)
			bgOverlayLeft:draw()
		else
			local shOffset = textSize * HUDTextDisplay.SHADOW_OFFSET_FACTOR

			setTextColor(0, 0, 0, 1)
			renderText(posX + shOffset, posY - shOffset, textSize, dateFormat)
		end

		local clockColorSetting = g_additionalSettingsManager:getSettingByName("clockColor")

		setTextColor(unpack(clockColorSetting:getCurrentColor()))
		renderText(posX, posY, textSize, dateFormat)
		setTextAlignment(RenderText.ALIGN_LEFT)
		setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
		setTextColor(1, 1, 1, 1)
	end
end


ClockPositionSetting = {}

local ClockPositionSetting_mt = Class(ClockPositionSetting)

function ClockPositionSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or ClockPositionSetting_mt)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	return self
end

function ClockPositionSetting:onTabOpen(optionElement)
	optionElement:setDisabled(not g_currentMission.hud:getIsVisible() or g_additionalSettingsManager:getSettingStateByName("date") == 0)
end


HourFormatSetting = {}

local HourFormatSetting_mt = Class(HourFormatSetting)

function HourFormatSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or HourFormatSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	return self
end

function HourFormatSetting:onLoad(filename)
	AdditionalSettingsUtil.overwrittenFunction(g_currentMission.hud.gameInfoDisplay, "draw", self, "draw")
end

function HourFormatSetting:onTabOpen(checkboxElement)
	checkboxElement:setDisabled(not g_currentMission.hud:getIsVisible())
end

function HourFormatSetting:onStateChange(state, checkboxElement, loadFromSavegame)
	local dateSettings = g_additionalSettingsManager:getSettingByName("date")

	dateSettings:updateCurrentDateFormat(dateSettings.state, state)
end

function HourFormatSetting:draw(gameInfoDisplay, superFunc)
	local format = string.format

	string.format = function (form, ...)
		if not self.active then
			local dateForm = "%02d:%02d"

			if form == dateForm then
				local args = {...}
				local hour = args[1]
				local minute = args[2]

				if hour ~= nil and minute ~= nil then
					local amPm = " AM"

					if hour >= 12 then
						amPm = " PM"
					end

					if hour == 0 then
						hour = 12
					elseif hour > 12 then
						hour = hour - 12
					end

					return format(dateForm .. amPm, hour, minute)
				end
			end
		end
		return format(form, ...)
	end

	local retValue = superFunc(gameInfoDisplay)

	string.format = format

	return retValue
end


FadeEffectSetting = {}

local FadeEffectSetting_mt = Class(FadeEffectSetting)

function FadeEffectSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or FadeEffectSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onUpdate", self)
	AdditionalSettingsUtil.registerEventListener("onPreDraw", self)
	AdditionalSettingsUtil.appendedFunction(CameraManager, "setActiveCamera", self, "setActiveCamera")
	AdditionalSettingsUtil.overwrittenFunction(g_gui, "changeScreen", self, "changeScreen")

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	local fadeOverlay = Overlay.new(g_baseHUDFilename, 0, 0, 1, 1)

	fadeOverlay:setUVs(GuiUtils.getUVs({8, 8, 2, 2}))
	fadeOverlay:setColor(0, 0, 0, 0)

	self.fadeScreenElement = HUDElement.new(fadeOverlay)
	self.fadeAnimation = TweenSequence.NO_SEQUENCE
	self.effectDuration = 0

	return self
end

function FadeEffectSetting:onUpdate(dt)
	if g_currentMission:getIsClient() then
		if not self.fadeAnimation:getFinished() then
			self.fadeAnimation:update(dt)
		end
	end
end

function FadeEffectSetting:onPreDraw()
	if self.fadeScreenElement:getVisible() then
		self.fadeScreenElement:draw()
	end
end

function FadeEffectSetting:onCreateElement(optionElement)
	local texts = {
		g_i18n:getText("ui_off")
	}

	for i = 100, 1000 + 0.0001, 100 do
		table.insert(texts, string.format("%d ms", i))
	end

	optionElement:setTexts(texts)
end

function FadeEffectSetting:getFadeEffectDurationFromIndex(index)
	return math.clamp(index * 100, 0, 1000)
end

function FadeEffectSetting:onStateChange(state, optionElement, loadFromSavegame)
	self.effectDuration = self:getFadeEffectDurationFromIndex(state)
end

function FadeEffectSetting:fadeScreen()
	if not g_currentMission.hud:getIsFading() and self.effectDuration ~= 0 then
		local seq = TweenSequence.new(self.fadeScreenElement)

		seq:addTween(Tween.new(self.fadeScreenElement.setAlpha, 1, 0, self.effectDuration))
		seq:start()

		self.fadeAnimation = seq
	end
end

function FadeEffectSetting:setActiveCamera(cameraManager, camera)
	if camera ~= nil and cameraManager.cameraInfo[camera] ~= nil and cameraManager.activeCameraNode == camera then
		self:fadeScreen()
	end
end

function FadeEffectSetting:changeScreen(gui, superFunc, source, screenClass, returnScreenClass)
	local disableFadeEffect = gui.currentGuiName == "ChatDialog"
	local retValue = superFunc(gui, source, screenClass, returnScreenClass)

	if not disableFadeEffect and gui.currentGuiName == "" then
		self:fadeScreen()
	end

	return retValue
end


DialogBoxesSetting = {}

local DialogBoxesSetting_mt = Class(DialogBoxesSetting)

function DialogBoxesSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or DialogBoxesSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onUpdate", self)
	AdditionalSettingsUtil.prependedFunction(InfoDialog, "setText", self, "setText")

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	self.infoTexts = {
		"shop_messageBoughtAnimals",
		"shop_messageBoughtChainsaw",
		"shop_messageBoughtHandToolInventory",
		"shop_messageBoughtHandToolPickedUp",
		"shop_messageBoughtPlaceable",
		"shop_messageConfigurationChanged",
		"shop_messageGardenCenterPurchaseReady",
		"shop_messageLeasingReady",
		"shop_messagePurchaseReady",
		"shop_messageReturnedVehicle",
		"shop_messageSoldAnimals",
		"shop_messageSoldObject",
		"shop_messageSoldVehicle",
		"shop_messageThanksForBuying",
		"ui_vehicleResetDone"
	}

	self.dialogInstance = nil

	return self
end

function DialogBoxesSetting:onUpdate(dt)
	if g_currentMission:getIsClient() and not self.active and self.dialogInstance ~= nil then
		self.dialogInstance:close()

		if self.dialogInstance.onOk ~= nil then
			if self.dialogInstance.target ~= nil then
				self.dialogInstance.onOk(self.dialogInstance.target, self.dialogInstance.args)
			else
				self.dialogInstance.onOk(self.dialogInstance.args)
			end
		end

		self.dialogInstance = nil
	end
end

function DialogBoxesSetting:setText(infoDialog, text)
	if not self.active then
		for _, str in pairs(self.infoTexts) do
			if text == g_i18n:getText(str) then
				self.dialogInstance = infoDialog
				break
			end
		end
	end
end


VehicleCameraSetting = {}

local VehicleCameraSetting_mt = Class(VehicleCameraSetting)

function VehicleCameraSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or VehicleCameraSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	self.yaw = 0
	self.pitch = 0
	self.value = 0

	return self
end

function VehicleCameraSetting:onLoad(filename)
	AdditionalSettingsUtil.overwrittenFunction(VehicleCamera, "actionEventLookLeftRight", self, "actionEventLookLeftRight")
	AdditionalSettingsUtil.overwrittenFunction(VehicleCamera, "actionEventLookUpDown", self, "actionEventLookUpDown")
end

function VehicleCameraSetting:onCreateElement(optionElement)
	local texts = {
		g_i18n:getText("ui_off")
	}

	for i = 10, 100 + 0.0001, 10 do
		table.insert(texts, string.format("%d%%", i))
	end

	optionElement:setTexts(texts)
end

function VehicleCameraSetting:getSmoothCameraValueFromIndex(index)
	return math.clamp(5 - index * 0.35, 1.5, 5)
end

function VehicleCameraSetting:onStateChange(state, optionElement, loadFromSavegame)
	self.value = self:getSmoothCameraValueFromIndex(state)
end

function VehicleCameraSetting:getSmoothValue(pitch, inputValue, isMouse)
	if isMouse then
		inputValue = inputValue * 0.001 * 16.666
	else
		inputValue = inputValue * 0.001 * g_currentDt
	end

	self[pitch] = inputValue + math.pow(0.99579, g_currentDt * self.value) * (self[pitch] - inputValue)

	return self[pitch]
end

function VehicleCameraSetting:actionEventLookLeftRight(vehicleCamera, superFunc, actionName, inputValue, callbackState, isAnalog, isMouse)
	if self.state == 0 then
		superFunc(vehicleCamera, actionName, inputValue, callbackState, isAnalog, isMouse)
	else
		vehicleCamera.lastInputValues.leftRight = vehicleCamera.lastInputValues.leftRight + self:getSmoothValue("yaw", inputValue, isMouse)
	end
end

function VehicleCameraSetting:actionEventLookUpDown(vehicleCamera, superFunc, actionName, inputValue, callbackState, isAnalog, isMouse)
	if self.state == 0 then
		superFunc(vehicleCamera, actionName, inputValue, callbackState, isAnalog, isMouse)
	else
		vehicleCamera.lastInputValues.upDown = vehicleCamera.lastInputValues.upDown + self:getSmoothValue("pitch", inputValue, isMouse)
	end
end


PlayerCameraSetting = {}

local PlayerCameraSetting_mt = Class(PlayerCameraSetting)

function PlayerCameraSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or PlayerCameraSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	self.yaw = 0
	self.pitch = 0
	self.value = 0

	return self
end

function PlayerCameraSetting:onLoad(filename)
	AdditionalSettingsUtil.overwrittenFunction(PlayerInputComponent, "onInputLookLeftRight", self, "onInputLookLeftRight")
	AdditionalSettingsUtil.overwrittenFunction(PlayerInputComponent, "onInputLookUpDown", self, "onInputLookUpDown")
end

function PlayerCameraSetting:onCreateElement(optionElement)
	local texts = {
		g_i18n:getText("ui_off")
	}

	for i = 10, 100 + 0.0001, 10 do
		table.insert(texts, string.format("%d%%", i))
	end

	optionElement:setTexts(texts)
end

function PlayerCameraSetting:getSmoothCameraValueFromIndex(index)
	return math.clamp(5 - index * 0.35, 1.5, 5)
end

function PlayerCameraSetting:onStateChange(state, optionElement, loadFromSavegame)
	self.value = self:getSmoothCameraValueFromIndex(state)
end

function PlayerCameraSetting:getSmoothValue(pitch, inputValue, isMouse)
	if isMouse then
		inputValue = inputValue * 0.001 * 16.666
	else
		inputValue = inputValue * 0.001 * g_currentDt
	end

	self[pitch] = inputValue + math.pow(0.99579, g_currentDt * self.value) * (self[pitch] - inputValue)

	return self[pitch]
end

function PlayerCameraSetting:onInputLookLeftRight(playerInputComponent, superFunc, actionName, inputValue, callbackState, isAnalog, isMouse)
	if self.state == 0 then
		superFunc(playerInputComponent, actionName, inputValue, callbackState, isAnalog, isMouse)
	else
		if not playerInputComponent.locked then
			playerInputComponent.cameraRotationY = playerInputComponent.cameraRotationY + self:getSmoothValue("yaw", inputValue, isMouse)
		end

		playerInputComponent.isMouseRotation = isMouse
	end
end

function PlayerCameraSetting:onInputLookUpDown(playerInputComponent, superFunc, actionName, inputValue, callbackState, isAnalog, isMouse)
	if self.state == 0 then
		superFunc(playerInputComponent, actionName, inputValue, callbackState, isAnalog, isMouse)
	else
		if not playerInputComponent.locked then
			if g_gameSettings:getValue(GameSettings.SETTING.INVERT_Y_LOOK) then
				inputValue = inputValue * -1
			end

			playerInputComponent.cameraRotationX = playerInputComponent.cameraRotationX + self:getSmoothValue("pitch", inputValue, isMouse)
		end

		playerInputComponent.isMouseRotation = isMouse
	end
end


EasyMotorStartSetting = {}

local EasyMotorStartSetting_mt = Class(EasyMotorStartSetting)

function EasyMotorStartSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or EasyMotorStartSetting_mt)

	AdditionalSettingsUtil.overwrittenFunction(Drivable, "actionEventAccelerate", self, "actionEventAccelerate")

	self.active = false
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	return self
end

function EasyMotorStartSetting:onTabOpen(checkboxElement)
	checkboxElement:setDisabled(g_currentMission.missionInfo.automaticMotorStartEnabled)
end

function EasyMotorStartSetting:actionEventAccelerate(drivable, superFunc, actionName, inputValue, callbackState, isAnalog)
	if inputValue ~= 0 then
		local isPowered, isPoweredWarning = drivable:getIsPowered()

		if not isPowered and isPoweredWarning ~= nil then
			if self.active and not drivable:getIsAIActive() and not drivable:getIsMotorStarted() and drivable:getCanMotorRun() and isPoweredWarning == g_i18n:getText("warning_motorNotStarted") then
				drivable:startMotor()
			else
				g_currentMission:showBlinkingWarning(isPoweredWarning, 2000)
			end
		end

		local isAllowed, warning = drivable:getIsPlayerVehicleControlAllowed()

		if isAllowed then
			drivable:setAccelerationPedalInput(inputValue)
			return
		end

		if warning ~= nil then
			g_currentMission:showBlinkingWarning(warning, 2000)
		end
	end
end


AutostartSetting = {}

local AutostartSetting_mt = Class(AutostartSetting)

function AutostartSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or AutostartSetting_mt)
	local isParamSet = StartParams.getIsSet("autoStart")

	self.active = isParamSet
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	self.isParamSet = isParamSet

	return self
end

function AutostartSetting:onCreateElement(checkboxElement)
	checkboxElement.parent:setVisible(not self.isParamSet)
end

function AutostartSetting:onStateChange(state, checkboxElement, loadFromSavegame)
	if not self.isParamSet then
		StartParams.setValue("autoStart", state and "" or nil)
	end
end


StoreItemsSetting = {}

local StoreItemsSetting_mt = Class(StoreItemsSetting)

function StoreItemsSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or StoreItemsSetting_mt)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	return self
end

function StoreItemsSetting:makeSelfCallback(func)
	return function(...)
		return func(self, g_shopMenu, ...)
	end
end

function StoreItemsSetting:getIsItemVisible(item)
	if item == nil then
		return false
	end

	local state = self.state

	if state == 0 then
		return true
	end

	local isMod = false
	local isDlc = false

	if item.customEnvironment ~= nil then
		local isDLCEnv = string.startsWith(item.customEnvironment, g_uniqueDlcNamePrefix)

		isMod = not isDLCEnv
		isDlc = isDLCEnv
	end

	if state == 1 then
		return not isMod and not isDlc
	elseif state == 2 then
		return isMod or isDlc
	elseif state == 3 then
		return isMod
	else
		return isDlc
	end
end

function StoreItemsSetting:onStateChange(state, optionElement, loadFromSavegame)
	g_shopController.displayBrands = {}
	g_shopController.displayBrandNames = {}
	g_shopController.displayBrandCategories = {}
	g_shopController.shopCategories = {}

	g_shopMenu.pageShopBrands.categories = {}
	g_shopMenu.pageShopBrands.categoryTypes = {}
	g_shopMenu.pageShopVehicles.categories = {}
	g_shopMenu.pageShopVehicles.categoryTypes = {}

	local foundBrands = {}
	local foundCategory = {}

	for _, storeItem in ipairs(g_storeManager:getItems()) do
		if self:getIsItemVisible(storeItem) then
			if storeItem.showInStore and (#storeItem.categoryNames ~= 0 and (storeItem.species ~= StoreSpecies.PLACEABLE and (storeItem.species ~= StoreSpecies.ANIMAL and (storeItem.extraContentId == nil or g_extraContentSystem:getIsItemIdUnlocked(storeItem.extraContentId))))) then
				local brand = g_brandManager:getBrandByIndex(storeItem.brandIndex)

				if brand ~= nil and (not foundBrands[storeItem.brandIndex] and (storeItem.species == StoreSpecies.VEHICLE or storeItem.species == StoreSpecies.HANDTOOL)) then
					foundBrands[storeItem.brandIndex] = true

					if brand.name ~= "NONE" then
						g_shopController:addBrandForDisplay(brand)
					end
				end

				for i = 1, #storeItem.categoryNames do
					local category = g_storeManager:getCategoryByName(storeItem.categoryNames[i])

					if category ~= nil and not foundCategory[storeItem.categoryNames[i]] then
						foundCategory[storeItem.categoryNames[i]] = true
						g_shopController:addCategoryForDisplay(category, g_shopController.shopCategories, storeItem.imageFilename)
					end
				end
			end
		end
	end

	table.sort(g_shopController.displayBrands, ShopController.brandSortFunction)

	local foundLabel = nil

	for _, displayBrand in ipairs(g_shopController.displayBrands) do
		local label = utf8ToUpper(utf8Substr(displayBrand.label, 0, 1))

		if foundLabel ~= label then
			g_shopController.displayBrandNames[label] = {}
			table.insert(g_shopController.displayBrandCategories, {name = label})
			foundLabel = label
		end

		table.insert(g_shopController.displayBrandNames[label], displayBrand)
	end

	for _, category in pairs(g_shopController.shopCategories) do
		table.sort(category, ShopController.categorySortFunction)
	end

	local itemsCategoryName = ""

	if state ~= 0 and optionElement ~= nil then
		itemsCategoryName = string.format(" (%s)", optionElement.texts[state + 1])
	end

	local shopPages = {
		[g_shopMenu.pageShopBrands] = {
			g_shopController:getBrandCategories(),
			g_shopController:getBrandNames(),
			self:makeSelfCallback(self.onClickBrand),
			g_shopMenu:makeSelfCallback(g_shopMenu.onSelectCategory),
			g_i18n:getText(ShopMenu.L10N_SYMBOL.HEADER_BRANDS) .. itemsCategoryName,
			ShopMenu.SLICE_ID.BRANDS,
			ShopMenu.LIST_CELL_NAME_BRAND,
			ShopMenu.LIST_EMPTY_CELL_NAME_CATEGORY
		},
		[g_shopMenu.pageShopVehicles] = {
			g_storeManager:getCategoryTypes(),
			g_shopController:getShopCategories(),
			self:makeSelfCallback(self.onClickItemCategory),
			g_shopMenu:makeSelfCallback(g_shopMenu.onSelectCategory),
			g_i18n:getText(ShopMenu.L10N_SYMBOL.HEADER_VEHICLES) .. itemsCategoryName,
			ShopMenu.SLICE_ID.VEHICLES,
			ShopMenu.LIST_CELL_NAME_CATEGORY,
			ShopMenu.LIST_EMPTY_CELL_NAME_CATEGORY
		}
	}

	for page, attr in pairs(shopPages) do
		page:reset()
		page:initialize(unpack(attr))
		page.categoryList:reloadData()
	end
end

function StoreItemsSetting:onClickBrand(shopMenu, brandId, brandCategoryIconUVs, brandCategoryDisplayName, categoryDisplayName)
	local brandItems = g_shopController:getItemsByBrand(brandId)
	local currentDisplayItems = brandItems

	if self.state ~= 0 then
		local displayItems = {}

		for i = 1, #brandItems do
			if self:getIsItemVisible(brandItems[i].storeItem) then
				table.insert(displayItems, brandItems[i])
			end
		end

		currentDisplayItems = displayItems
	end

	shopMenu.currentDisplayItems = currentDisplayItems
	shopMenu.pageShopItemDetails:setDisplayItems(currentDisplayItems, false)
	shopMenu.pageShopItemDetails:setCategory(g_i18n:getText(ShopMenu.L10N_SYMBOL.HEADER_BRANDS), brandCategoryIconUVs, categoryDisplayName)
	shopMenu.currentItemDetailsType = ShopMenu.DETAILS.BRAND
	shopMenu.currentBrandId = brandId
	shopMenu:pushDetail(shopMenu.pageShopItemDetails)
	shopMenu.pageShopItemDetails:resetListSelection()
end

function StoreItemsSetting:onClickItemCategory(shopMenu, categoryName, baseCategoryIconUVs, baseCategoryDisplayName, categoryDisplayName, filter)
	local categoryItems = g_shopController:getItemsByCategory(categoryName)
	local currentDisplayItems = categoryItems

	if self.state ~= 0 then
		local displayItems = {}

		for i = 1, #categoryItems do
			if self:getIsItemVisible(categoryItems[i].storeItem) then
				table.insert(displayItems, categoryItems[i])
			end
		end

		currentDisplayItems = displayItems
	end

	shopMenu.currentCategoryName = categoryName
	shopMenu.currentDisplayItems = currentDisplayItems
	shopMenu.currentCategoryFilter = filter
	shopMenu.currentItemDetailsType = ShopMenu.DETAILS.VEHICLE
	shopMenu.pageShopItemDetails:setDisplayItems(currentDisplayItems)

	if categoryName == ShopController.COINS_CATEGORY and not g_inAppPurchaseController:getIsAvailable() then
		InfoDialog.show(g_i18n:getText("ui_iap_notAvailable"), nil, nil, DialogElement.TYPE_INFO)
		return
	end

	local isInAppPurchase = false

	for i = 1, #shopMenu.currentDisplayItems do
		if shopMenu.currentDisplayItems[i].storeItem.isInAppPurchase then
			isInAppPurchase = true
			break
		end
	end

	if isInAppPurchase then
		g_inAppPurchaseController:setPendingPurchaseCallback(function()
			if shopMenu:getIsOpen() then
				shopMenu:updateCurrentDisplayItems()
			end
		end)
	else
		g_inAppPurchaseController:setPendingPurchaseCallback(nil)
	end

	shopMenu.pageShopItemDetails:setCategory(baseCategoryIconUVs, baseCategoryDisplayName, categoryDisplayName)
	shopMenu:pushDetail(shopMenu.pageShopItemDetails)
	shopMenu.pageShopItemDetails:resetListSelection()
end


LightingSetting = {}

local LightingSetting_mt = Class(LightingSetting)

function LightingSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or LightingSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)
	AdditionalSettingsUtil.registerEventListener("onDelete", self)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	return self
end

function LightingSetting:onLoad(filename)
	AdditionalSettingsUtil.overwrittenFunction(g_currentMission.environment, "setCustomLighting", self, "setCustomLighting")
	AdditionalSettingsUtil.overwrittenFunction(gEnv, "setEnvMap", self, "setEnvMap", true)

	local lightingDirectory = g_additionalSettingsManager.modSettings.directory .. "lighting/"
	local defaultLightingDirectory = lightingDirectory .. "default/"

	createFolder(lightingDirectory)

	AdditionalSettingsUtil.copyFiles(g_additionalSettingsManager.addonsDirectory .. "lighting/", defaultLightingDirectory, {"colorGrading.xml", "colorGradingNight.xml", "lighting.xml", "name.xml"}, false)

	self.customLighting, self.customLightingTexts = self:loadCustomLightingConfigurations(lightingDirectory)
	self.lightingDirectory = lightingDirectory

	addConsoleCommand("agsReloadCustomLighting", "", "consoleCommandReloadCustomLighting", self)
end

function LightingSetting:onDelete()
	removeConsoleCommand("agsReloadCustomLighting")
end

function LightingSetting:onStateChange(state, optionElement, loadFromSavegame)
	local lighting
	local customLighting = self:getCurrentLighting()

	if customLighting ~= nil then
		lighting = customLighting.lighting
	end

	g_currentMission.environment:setCustomLighting(lighting)
end

function LightingSetting:onCreateElement(optionElement)
	optionElement:setTexts(self.customLightingTexts)

	local toolTipelement = optionElement.elements[1]
	toolTipelement:setText(string.format(toolTipelement:getText(), self.lightingDirectory))
end

function LightingSetting:onSaveSetting(xmlFile, key)
	local id = g_currentMission.missionInfo.map.id
	local isMap = true

	local customLighting = self:getCurrentLighting()

	if customLighting ~= nil then
		id = customLighting.id
		isMap = customLighting.isMap

		xmlFile:setString(key .. "#id", id)
		xmlFile:setBool(key .. "#isMap", isMap)
	end

	return true
end

function LightingSetting:onLoadSetting(xmlFile, key)
	local state = 0

	local id = xmlFile:getString(key .. "#id")
	local isMap = xmlFile:getBool(key .. "#isMap")

	if id ~= nil and isMap ~= nil then
		for i, customLighting in pairs(self.customLighting) do
			if customLighting.id == id and customLighting.isMap == isMap then
				state = i
			end
		end
	end

	return true, state
end

function LightingSetting:loadCustomLightingConfigurations(directory)
	local customLighting = {}
	local customLightingTexts = {g_i18n:getText("ui_off")}
	local files = Files.new(directory)

	for _, v in pairs(files.files) do
		local filename = v.filename

		if not v.isDirectory then
			filename = v.filename:sub(1, -5)
		end

		local baseDirectory = directory .. filename .. "/"
		local xmlFilename = baseDirectory .. "lighting.xml"
		local baseKey = "lighting"

		if not fileExists(xmlFilename) then
			xmlFilename = baseDirectory .. "environment.xml"
			baseKey = "environment.lighting"
		end

		local lightingXML = XMLFile.loadIfExists("lightingXML", xmlFilename)

		if lightingXML ~= nil then
			local lighting = Lighting.new()

			lighting:load(lightingXML, baseKey, baseDirectory)
			lighting:setSnowHeightThreshold(SnowSystem.MIN_LAYER_HEIGHT)

			local orgEnvMapTimes = #lighting.envMapTimes
			local orgEnvMapBasePath = lighting.envMapBasePath

			if lightingXML:getBool(baseKey .. ".envMap#attr10", #lighting.envMapTimes == 0 or lighting.envMapBasePath == nil) then
				self:setLightingAttributes(lighting)
			end

			local text = filename
			local nameXML = XMLFile.loadIfExists("nameXML", baseDirectory .. "name.xml")

			if nameXML ~= nil then
				text = nameXML:getI18NValue("name", "", g_additionalSettingsManager.customEnvironment, true)
				nameXML:delete()
			end

			table.insert(customLighting, {lighting = lighting, id = filename, isMap = false})
			table.insert(customLightingTexts, string.format("%s (%s)", text, g_i18n:getText("ags_ui_folder")))

			AdditionalSettingsUtil.info("Lighting configuration loaded (%s):\n  -lighting: '%s'\n  -envMapBasePath: '%s'\n  -envMapTimes: '%d'\n  -useStoreEnvMap: '%s'\n", text, xmlFilename, orgEnvMapBasePath, orgEnvMapTimes, lighting.attr10 == true)

			lightingXML:delete()
		else
			AdditionalSettingsUtil.error("File '%s' not found!", xmlFilename)
		end
	end

	for i = 1, g_mapManager:getNumOfMaps() do
		local map = g_mapManager:getMapDataByIndex(i)
		local baseDirectory = map.baseDirectory
		local mapXMLFilename = Utils.getFilename(map.mapXMLFilename, baseDirectory)
		local mapXML = XMLFile.load("MapXML", mapXMLFilename)

		if mapXML ~= nil then
			local environmentXMLFilename = Utils.getFilename(mapXML:getString("map.environment#filename"), baseDirectory)

			if environmentXMLFilename == "data/maps/mapUS/config/environment.xml" and map.title ~= g_i18n:getText("mapUS_title") or environmentXMLFilename == "data/maps/mapAS/config/environment.xml" and map.title ~= g_i18n:getText("mapAS_title") or environmentXMLFilename == "data/maps/mapEU/config/environment.xml" and map.title ~= g_i18n:getText("mapEU_title") then
				AdditionalSettingsUtil.info("Default lighting configuration: (%s) '%s'.\n", map.title, environmentXMLFilename)
			else
				local environmentXML = XMLFile.load("environmentXML", environmentXMLFilename)

				if environmentXML ~= nil then
					local lighting = nil

					if map == g_currentMission.missionInfo.map then
						lighting = g_currentMission.environment.baseLighting
					else
						lighting = Lighting.new()
						lighting:load(environmentXML, "environment.lighting", baseDirectory)
						lighting:setSnowHeightThreshold(SnowSystem.MIN_LAYER_HEIGHT)
					end

					local orgEnvMapTimes = #lighting.envMapTimes
					local orgEnvMapBasePath = lighting.envMapBasePath

					if environmentXML:getBool("environment.lighting.envMap#attr10", #lighting.envMapTimes == 0 or lighting.envMapBasePath == nil) then
						self:setLightingAttributes(lighting)
					end

					table.insert(customLighting, {lighting = lighting, id = map.id, isMap = true})
					table.insert(customLightingTexts, string.format("%s (%s)", map.title, g_i18n:getText("ui_map")))

					AdditionalSettingsUtil.info("Lighting configuration loaded (%s):\n  -lighting: '%s'\n  -envMapBasePath: '%s'\n  -envMapTimes: '%d'\n  -useStoreEnvMap: '%s'\n", map.title, environmentXMLFilename, orgEnvMapBasePath, orgEnvMapTimes, lighting.attr10 == true)

					environmentXML:delete()
				end
			end

			mapXML:delete()
		end
	end

	local beaseLighting = g_currentMission.environment.baseLighting

	if #beaseLighting.envMapTimes == 0 or beaseLighting.envMapBasePath == nil then
		self:setLightingAttributes(beaseLighting)
	end

	return customLighting, customLightingTexts
end

function LightingSetting:setLightingAttributes(lighting)
	lighting.attr10 = true
	lighting.envMapBasePath = "data/store/ui/envMaps/shop/"
	lighting.envMapTimes = {0}
end

function LightingSetting:getCurrentLighting()
	if self.state ~= 0 then
		return self.customLighting[self.state]
	end

	return nil
end

function LightingSetting:setCustomLighting(environment, superFunc, lighting)
	if lighting == nil then
		local customLighting = self:getCurrentLighting()

		if customLighting ~= nil then
			lighting = customLighting.lighting
		end
	end

	superFunc(environment, lighting)
end

function LightingSetting:setEnvMap(superFunc, envMapTime0Cloud0, envMapTime0Cloud1, envMapTime1Cloud0, envMapTime1Cloud1, blendWeight0, blendWeight1, blendWeight2, blendWeight3, force, attr10)
	if attr10 == false then
		local customLighting = self:getCurrentLighting()

		if customLighting ~= nil then
			if customLighting.lighting.attr10 then
				attr10 = true
			end
		elseif g_currentMission.environment.lighting == g_currentMission.environment.baseLighting then
			if g_currentMission.environment.baseLighting.attr10 then
				attr10 = true
			end
		end
	end

	superFunc(envMapTime0Cloud0, envMapTime0Cloud1, envMapTime1Cloud0, envMapTime1Cloud1, blendWeight0, blendWeight1, blendWeight2, blendWeight3, force, attr10)
end

function LightingSetting:consoleCommandReloadCustomLighting()
	self.state = 0
	self:onStateChange(0, nil, false)

	self.customLighting, self.customLightingTexts = self:loadCustomLightingConfigurations(self.lightingDirectory)

	local optionElement = g_additionalSettingsManager:getUIElement(self)

	optionElement:setTexts(self.customLightingTexts)
	optionElement:setState(1, nil, true)

	return AdditionalSettingsUtil.info("Custom lighting settings updated, available configurations: %d", #self.customLighting)
end


DoFSetting = {}

local DoFSetting_mt = Class(DoFSetting)

function DoFSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or DoFSetting_mt)

	AdditionalSettingsUtil.overwrittenFunction(g_depthOfFieldManager, "applyInfo", self, "applyInfo")

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	self.defaultStateBackup = g_depthOfFieldManager.defaultState
	self.customState = {0.01, 0.01, 0.01, 10000, 10000, false}

	return self
end

function DoFSetting:applyInfo(depthOfFieldManager, superFunc, nearCoCRadius, nearBlurEnd, farCoCRadius, farBlurStart, farBlurEnd, applyToSky)
	if not self.active then
		depthOfFieldManager:reset()
	else
		superFunc(depthOfFieldManager, nearCoCRadius, nearBlurEnd, farCoCRadius, farBlurStart, farBlurEnd, applyToSky)
	end
end

function DoFSetting:onStateChange(state, checkboxElement, loadFromSavegame)
	local defaultState = self.customState

	if state then
		defaultState = self.defaultStateBackup
	end

	g_depthOfFieldManager.defaultState = defaultState

	local cameraNode = g_cameraManager:getActiveCamera()

	if cameraNode ~= nil and g_cameraManager.cameraInfo[cameraNode].dofInfo ~= nil then
		g_depthOfFieldManager:applyInfo(g_cameraManager.cameraInfo[cameraNode].dofInfo)
	else
		g_depthOfFieldManager:reset()
	end
end


CameraCollisionsSetting = {}

local CameraCollisionsSetting_mt = Class(CameraCollisionsSetting)

function CameraCollisionsSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or CameraCollisionsSetting_mt)

	if not g_modIsLoaded["FS25_disableVehicleCameraCollision"] then
		AdditionalSettingsUtil.overwrittenFunction(VehicleCamera, "getCollisionDistance", self, "getCollisionDistance")
	end

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	return self
end

function CameraCollisionsSetting:onCreateElement(checkboxElement)
	checkboxElement.parent:setVisible(not g_modIsLoaded["FS25_disableVehicleCameraCollision"])
end

function CameraCollisionsSetting:getCollisionDistance(vehicleCamera, superFunc)
	if not self.active then
		return false, nil, nil, nil, nil, nil
	end

	return superFunc(vehicleCamera)
end


GuiCameraSetting = {}

local GuiCameraSetting_mt = Class(GuiCameraSetting)

function GuiCameraSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or GuiCameraSetting_mt)

	AdditionalSettingsUtil.overwrittenFunction(GuiTopDownCamera, "getMouseEdgeScrollingMovement", self, "getMouseEdgeScrollingMovement")

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	return self
end

function GuiCameraSetting:getMouseEdgeScrollingMovement(guiTopDownCamera, superFunc)
	if not self.active then
		return 0, 0
	end

	return superFunc(guiTopDownCamera)
end


QuitGameSetting = {}

local QuitGameSetting_mt = Class(QuitGameSetting)

function QuitGameSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or QuitGameSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)

	self.loadState = AdditionalSettingsManager.LOAD_STATE.NO

	return self
end

function QuitGameSetting:onLoad(filename)
	self.quitGameButton = {
		showWhenPaused = true,
		inputAction = InputAction.MENU_EXTRA_2,
		text = g_i18n:getText("ags_button_quitGame"),
		callback = self.quitButtonCallback
	}

	AdditionalSettingsUtil.overwrittenFunction(g_inGameMenu.pageSave, "updateMenuButtons", self, "updateMenuButtons")

	self:addIngameButtons()

	g_inGameMenu.pageSave.quitButtonInfo.text = g_i18n:getText("ags_button_quitMenu")
	g_inGameMenu.pageSave:updateMenuButtons()
end

function QuitGameSetting:updateMenuButtons(pageSave, superFunc)
	pageSave.menuButtonInfo = {pageSave.backButtonInfo, pageSave.nextPageButtonInfo, pageSave.prevPageButtonInfo}

	if not pageSave.gameplayHintSelector:getIsFocused() then
		table.insert(pageSave.menuButtonInfo, pageSave.selectButtonInfo)
	end

	if pageSave.hasMasterRights then
		table.insert(pageSave.menuButtonInfo, pageSave.saveButtonInfo)
	end

	table.insert(pageSave.menuButtonInfo, self.quitGameButton)
	table.insert(pageSave.menuButtonInfo, pageSave.quitButtonInfo)

	pageSave:setMenuButtonInfoDirty()
end

function QuitGameSetting:quitButtonCallback()
	if g_inGameMenu.isSaving then
		return
	end

	if not g_inGameMenu.playerAlreadySaved and not (g_inGameMenu.missionDynamicInfo.isMultiplayer and g_inGameMenu.missionDynamicInfo.isClient) then
		local callback = function (yes)
			if yes then
				if g_inGameMenu.missionDynamicInfo.isMultiplayer and g_inGameMenu.isServer then
					g_inGameMenu.server:broadcastEvent(ShutdownEvent.new())
				end

				requestExit()
			end
		end

		YesNoDialog.show(callback, nil, g_i18n:getText(InGameMenu.L10N_SYMBOL.END_WITHOUT_SAVING))
	else
		requestExit()
	end
end

function QuitGameSetting:addIngameButtons()
	local buttonToClone = g_inGameMenu.menuButton[1]
	local newButton1 = buttonToClone:clone(buttonToClone.parent)
	local newButton2 = buttonToClone:clone(buttonToClone.parent)

	newButton1.id = "menuButton[7]"
	newButton2.id = "menuButton[8]"

	table.insert(g_inGameMenu.menuButton, newButton1)
	table.insert(g_inGameMenu.menuButton, newButton2)
end


ClockColorSetting = {}

local ClockColorSetting_mt = Class(ClockColorSetting)

function ClockColorSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or ClockColorSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)
	AdditionalSettingsUtil.registerEventListener("onDelete", self)

	self.state = 3
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	self.customColor = nil

	return self
end

function ClockColorSetting:onLoad(filename)
	self.clockFilename = g_additionalSettingsManager.modSettings.directory .. "clockColors.xml"

	AdditionalSettingsUtil.copyFiles(g_additionalSettingsManager.addonsDirectory, g_additionalSettingsManager.modSettings.directory, {"clockColors.xml"}, false)

	self:loadColors()
	addConsoleCommand("agsReloadClockColors", "", "consoleCommandReloadClockColors", self)
end

function ClockColorSetting:onDelete()
	removeConsoleCommand("agsReloadClockColors")
end

function ClockColorSetting:loadColors()
	self.colors = {}

	local useDefaultColors = false
	local colorXML = XMLFile.loadIfExists("colorXML", self.clockFilename)

	if colorXML ~= nil then
		useDefaultColors = colorXML:getBool("colors#useDefaultColors", false)

		if colorXML:hasProperty("colors.color(0)") then
			colorXML:iterate("colors.color", function (index, key)
				local c = colorXML:getVector(key .. "#color", {0, 0, 0}, 3)
				local n = g_i18n:convertText(colorXML:getString(key .. "#name", ""), g_additionalSettingsManager.customEnvironment)

				c[4] = 1
				table.insert(self.colors, {color = c, name = n, isMat = true})
			end)
		end

		colorXML:delete()
	else
		AdditionalSettingsUtil.error("File '%s' not found!", self.clockFilename)
	end

	if #self.colors == 0 then
		useDefaultColors = true
	end

	if useDefaultColors then
		for i = 1, #VehicleConfigurationItemColor.DEFAULT_COLORS do
			local defaultColor = VehicleConfigurationItemColor.DEFAULT_COLORS[i]
			local c, n = g_vehicleMaterialManager:getMaterialTemplateColorAndTitleByName(defaultColor)

			if c ~= nil then
				c[4] = 1
				table.insert(self.colors, {color = c, name = n, isMat = true})
			end
		end
	end
end

function ClockColorSetting:onTabOpen(buttonElement)
	buttonElement:setDisabled(not g_currentMission.hud:getIsVisible() or g_additionalSettingsManager:getSettingStateByName("date") == 0)
end

function ClockColorSetting:onStateChange(state, buttonElement, loadFromSavegame)
	if loadFromSavegame then
		self:onPickedColor(state + 1, {loadSaved = true}, {customColor = self.customColor})
	end
end

function ClockColorSetting:onCreateElement(buttonElement)
	self.changeColorButton = buttonElement.elements[1]
	self:updateColorButton()
end

function ClockColorSetting:onClickButton(buttonElement)
	ColorPickerDialog.show(self.onPickedColor, self, nil, self.colors, self.state + 1, nil, self.customColor, true, true, true)

	return true
end

function ClockColorSetting:onPickedColor(colorIndex, args, customArgs)
	local clickOk = colorIndex ~= nil or customArgs ~= nil

	if clickOk then
		if colorIndex ~= nil then
			if colorIndex > #self.colors then
				colorIndex = 1
			end

			self.state = colorIndex - 1
		end

		local customColor = nil

		if customArgs ~= nil and customArgs.customColor ~= nil then
			customColor = customArgs.customColor
			customColor[4] = 1
		end

		self.customColor = customColor

		self:updateColorButton()

		if args ~= nil and args.loadSaved then
			return
		end

		g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CONFIG_SPRAY)
	end
end

function ClockColorSetting:getCurrentColor()
	if self.customColor ~= nil then
		return self.customColor
	end

	local color = self.colors[self.state + 1]

	if color ~= nil then
		return color.color
	end

	return self.colors[1].color
end

function ClockColorSetting:updateColorButton()
	if self.changeColorButton ~= nil then
		self.changeColorButton:setImageColor(nil, unpack(self:getCurrentColor()))
	end
end

function ClockColorSetting:onSaveSetting(xmlFile, key)
	if self.customColor ~= nil then
		xmlFile:setVector(key .. "#customColor", self.customColor)

		return true
	end
end

function ClockColorSetting:onLoadSetting(xmlFile, key)
	local customColor = xmlFile:getVector(key .. "#customColor", nil, 4)

	if customColor ~= nil then
		self.customColor = customColor

		return true, 9999999
	end
end

function ClockColorSetting:consoleCommandReloadClockColors()
	self:loadColors()
	self:onPickedColor(4)

	return AdditionalSettingsUtil.info("Clock colors updated!")
end


FramerateLimiterSetting = {}

local FramerateLimiterSetting_mt = Class(FramerateLimiterSetting)

function FramerateLimiterSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or FramerateLimiterSetting_mt)

	self.state = 4

	local loadState = AdditionalSettingsManager.LOAD_STATE.NO

	if g_dedicatedServer == nil and gEnv.g_isDevelopmentVersion then
		loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START
		Platform.hasAdjustableFrameLimit = false
	end

	self.loadState = loadState
	self.limit = {30, 40, 50, 60, 75, 100, 120, 144, 165, 240}

	return self
end

function FramerateLimiterSetting:onCreateElement(optionElement)
	optionElement.parent:setVisible(self.loadState ~= AdditionalSettingsManager.LOAD_STATE.NO)

	local texts = {
		g_i18n:getText("ui_off")
	}

	for _, limit in pairs(self.limit) do
		table.insert(texts, tostring(limit))
	end

	optionElement:setTexts(texts)
end

function FramerateLimiterSetting:onStateChange(state, optionElement, loadFromSavegame)
	local maxFrameLimit = DedicatedServer.MAX_FRAME_LIMIT

	DedicatedServer.MAX_FRAME_LIMIT = self.limit[state] or math.huge
	DedicatedServer:raiseFramerate()
	DedicatedServer.MAX_FRAME_LIMIT = maxFrameLimit
end


ClockBackgroundSetting = {}

local ClockBackgroundSetting_mt = Class(ClockBackgroundSetting)

function ClockBackgroundSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or ClockBackgroundSetting_mt)

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	return self
end

function ClockBackgroundSetting:onTabOpen(checkboxElement)
	checkboxElement:setDisabled(not g_currentMission.hud:getIsVisible() or g_additionalSettingsManager:getSettingStateByName("date") == 0)
end


BlinkingWarningsSetting = {}

local BlinkingWarningsSetting_mt = Class(BlinkingWarningsSetting)

function BlinkingWarningsSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or BlinkingWarningsSetting_mt)

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	AdditionalSettingsUtil.overwrittenFunction(g_currentMission, "showBlinkingWarning", self, "showBlinkingWarning")

	return self
end

function BlinkingWarningsSetting:showBlinkingWarning(currentMission, superFunc, text, duration, priority)
	if self.active then
		superFunc(currentMission, text, duration, priority)
	end
end


ClockBoldSetting = {}

local ClockBoldSetting_mt = Class(ClockBoldSetting)

function ClockBoldSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or ClockBoldSetting_mt)

	self.active = true
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	return self
end

function ClockBoldSetting:onTabOpen(checkboxElement)
	checkboxElement:setDisabled(not g_currentMission.hud:getIsVisible() or g_additionalSettingsManager:getSettingStateByName("date") == 0)
end


HudColorSetting = {}

local HudColorSetting_mt = Class(HudColorSetting)

function HudColorSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or HudColorSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)
	AdditionalSettingsUtil.registerEventListener("onDelete", self)
	AdditionalSettingsUtil.overwrittenFunction(InfoDisplayKeyValueBox, "draw", self, "infoDisplayKeyValueBox_draw")
	AdditionalSettingsUtil.overwrittenFunction(MixerWagonHUDExtension, "draw", self, "mixerWagonHUDExtension_draw")

	self.modsOverlays = {}

	local cpEnv = self:getModEnvByModName("FS25_Courseplay")

	if cpEnv ~= nil then
		if cpEnv.CpHudInfoTexts ~= nil and cpEnv.CpHudInfoTexts.init ~= nil and cpEnv.CpHudInfoTexts.colorHeader ~= nil then
			AdditionalSettingsUtil.overwrittenFunction(cpEnv.CpHudInfoTexts, "init", self, "cpHudInfoTexts_init")
		end

		if cpEnv.CpBaseHud ~= nil and cpEnv.CpBaseHud.init ~= nil and cpEnv.CpBaseHud.HEADER_COLOR ~= nil then
			AdditionalSettingsUtil.overwrittenFunction(cpEnv.CpBaseHud, "init", self, "cpBaseHud_init")
		end
	end

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	self.hudColorBackup = HUD.COLOR.ACTIVE
	self.customColor = nil

	return self
end

function HudColorSetting:onLoad(filename)
	self.uiFilename = g_additionalSettingsManager.modSettings.directory .. "uiColors.xml"

	AdditionalSettingsUtil.copyFiles(g_additionalSettingsManager.addonsDirectory, g_additionalSettingsManager.modSettings.directory, {"uiColors.xml"}, false)

	self:loadColors()

	addConsoleCommand("agsReloadHudColors", "", "consoleCommandReloadHudColors", self)

	local speedBg = g_currentMission.hud.speedMeter.speedBg

	speedBg:setImage(g_additionalSettingsManager.baseDirectory .. "gui/ui_elements.png")
	speedBg:setUVs(GuiUtils.getUVs("2px 2px 232px 232px", {512, 256}))
	speedBg:setColor(unpack(HUD.COLOR.ACTIVE))
end

function HudColorSetting:onDelete()
	removeConsoleCommand("agsReloadHudColors")
end

function HudColorSetting:loadColors()
	self.colors = {}

	local useDefaultColors = false
	local colorXML = XMLFile.loadIfExists("colorXML", self.uiFilename)

	if colorXML ~= nil then
		useDefaultColors = colorXML:getBool("colors#useDefaultColors", false)

		if colorXML:hasProperty("colors.color(0)") then
			colorXML:iterate("colors.color", function (index, key)
				local c = colorXML:getVector(key .. "#color", {0, 0, 0}, 3)
				local n = g_i18n:convertText(colorXML:getString(key .. "#name", ""), g_additionalSettingsManager.customEnvironment)

				c[4] = 1
				table.insert(self.colors, {color = c, name = n, isMat = true})
			end)
		end

		colorXML:delete()
	else
		AdditionalSettingsUtil.error("File '%s' not found!", self.uiFilename)
	end

	if #self.colors == 0 then
		useDefaultColors = true
	end

	if useDefaultColors then
		for i = 1, #VehicleConfigurationItemColor.DEFAULT_COLORS do
			local defaultColor = VehicleConfigurationItemColor.DEFAULT_COLORS[i]
			local c, n = g_vehicleMaterialManager:getMaterialTemplateColorAndTitleByName(defaultColor)

			if c ~= nil then
				c[4] = 1
				table.insert(self.colors, {color = c, name = n, isMat = true})
			end
		end
	end
end

function HudColorSetting:onTabOpen(buttonElement)
	buttonElement:setDisabled(not g_currentMission.hud:getIsVisible())
end

function HudColorSetting:onStateChange(state, buttonElement, loadFromSavegame)
	if loadFromSavegame then
		self:onPickedColor(state + 1, {loadSaved = true}, {customColor = self.customColor})
	end
end

function HudColorSetting:onCreateElement(buttonElement)
	self.changeColorButton = buttonElement.elements[1]
	self:updateColorButton()
end

function HudColorSetting:onClickButton(buttonElement)
	ColorPickerDialog.show(self.onPickedColor, self, nil, self.colors, self.state + 1, nil, self.customColor, true, true, true)

	return true
end

function HudColorSetting:onPickedColor(colorIndex, args, customArgs)
	local clickOk = colorIndex ~= nil or customArgs ~= nil

	if clickOk then
		if colorIndex ~= nil then
			if colorIndex > #self.colors then
				colorIndex = 1
			end

			self.state = colorIndex - 1
		end

		local customColor = nil

		if customArgs ~= nil and customArgs.customColor ~= nil then
			customColor = customArgs.customColor
			customColor[4] = 1
		end

		self.customColor = customColor

		self:updateColorButton()
		self:updateHudElements()

		if args ~= nil and args.loadSaved then
			return
		end

		g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CONFIG_SPRAY)
	end
end

function HudColorSetting:getCurrentColor()
	if self.customColor ~= nil then
		return self.customColor
	end

	local color = self.colors[self.state + 1]

	if color ~= nil then
		return color.color
	end

	return self.colors[1].color
end

function HudColorSetting:updateColorButton()
	if self.changeColorButton ~= nil then
		self.changeColorButton:setImageColor(nil, unpack(self:getCurrentColor()))
	end
end

function HudColorSetting:updateHudElements()
	local currentColor = self:getCurrentColor()

	HUD.COLOR.ACTIVE = currentColor

	self:changeOverlaysColor(g_currentMission.hud.contextActionDisplay, {"iconOverlay"}, currentColor)
	self:changeOverlaysColor(g_currentMission.hud.gameInfoDisplay, {"calendarIcon", "weatherIcon", "clockIcon", "clockHandHour", "clockHandMinute", "fastForwardIcon", "temperature", "temperatureUp", "temperatureDown"}, currentColor)
	self:changeOverlaysColor(g_currentMission.hud.speedMeter, {"workingHours", "cruiseControl", "aiWorkerIcon", "aiSteeringIcon", "gearBg", "speedBg"}, currentColor)

	local evEnv = self:getModEnvByModName("FS25_EnhancedVehicle")

	if evEnv ~= nil then
		if evEnv.FS25_EnhancedVehicle_HUD ~= nil and evEnv.FS25_EnhancedVehicle_HUD.COLOR ~= nil and evEnv.FS25_EnhancedVehicle_HUD.COLOR.ACTIVE ~= nil then
			evEnv.FS25_EnhancedVehicle_HUD.COLOR.ACTIVE = currentColor
		end

		if evEnv.FS25_EnhancedVehicle ~= nil then
			if evEnv.FS25_EnhancedVehicle.hud ~= nil and evEnv.FS25_EnhancedVehicle.hud.colorActive ~= nil then
				evEnv.FS25_EnhancedVehicle.hud.colorActive = currentColor
			end

			if evEnv.FS25_EnhancedVehicle.color ~= nil and evEnv.FS25_EnhancedVehicle.color.fs25green ~= nil then
				evEnv.FS25_EnhancedVehicle.color.fs25green = currentColor
			end
		end
	end

	local cpEnv = self:getModEnvByModName("FS25_Courseplay")

	if cpEnv ~= nil then
		if cpEnv.CpHudInfoTexts ~= nil and cpEnv.CpHudInfoTexts.colorHeader ~= nil then
			cpEnv.CpHudInfoTexts.colorHeader = currentColor
		end

		if cpEnv.CpBaseHud ~= nil and cpEnv.CpBaseHud.HEADER_COLOR ~= nil then
			cpEnv.CpBaseHud.HEADER_COLOR = currentColor
		end
	end

	for _, overlay in pairs(self.modsOverlays) do
		overlay:setColor(unpack(currentColor))
	end
end

function HudColorSetting:changeOverlaysColor(element, overlays, color)
	if element == nil or overlays == nil or color == nil then
		return
	end

	for _, overlay in pairs(overlays) do
		if element[overlay] ~= nil and element[overlay].setColor ~= nil then
			element[overlay]:setColor(unpack(color))
		end
	end
end

function HudColorSetting:onSaveSetting(xmlFile, key)
	if self.customColor ~= nil then
		xmlFile:setVector(key .. "#customColor", self.customColor)

		return true
	end
end

function HudColorSetting:onLoadSetting(xmlFile, key)
	local customColor = xmlFile:getVector(key .. "#customColor", nil, 4)

	if customColor ~= nil then
		self.customColor = customColor

		return true, 9999999
	end
end

function HudColorSetting:consoleCommandReloadHudColors()
	self:loadColors()
	self:onPickedColor(1)

	return AdditionalSettingsUtil.info("Hud colors updated!")
end

function HudColorSetting:getModEnvByModName(name)
	if name ~= nil and g_modIsLoaded[name] ~= nil then
		return _G[name]
	end
end

function HudColorSetting:findOverlaysByColor(func, args, color)
	local setColorBackup = Overlay.setColor

	Overlay.setColor = function(overlay, r, g, b, a)
		if color ~= nil then
			local sR, sG, sB = unpack(color)

			if sR == r and sG == g and sB == b then
				table.insert(self.modsOverlays, overlay)
			end
		end

		setColorBackup(overlay, r, g, b, a)
	end

	if func ~= nil and args ~= nil then
		func(unpack(args))
	end

	Overlay.setColor = setColorBackup
end

function HudColorSetting:infoDisplayKeyValueBox_draw(infoDisplayKeyValueBox, superFunc, ...)
	infoDisplayKeyValueBox.warningIcon:setColor(unpack(HUD.COLOR.ACTIVE))

	return superFunc(infoDisplayKeyValueBox, ...)
end

function HudColorSetting:mixerWagonHUDExtension_draw(mixerWagonHUDExtension, superFunc, ...)
	local hudColor = HUD.COLOR.ACTIVE

	HUD.COLOR.ACTIVE = self.hudColorBackup

	local retValues = {superFunc(mixerWagonHUDExtension, ...)}

	HUD.COLOR.ACTIVE = hudColor

	return unpack(retValues)
end

function HudColorSetting:cpHudInfoTexts_init(cpHudInfoTexts, superFunc, ...)
	self:findOverlaysByColor(superFunc, {cpHudInfoTexts, ...}, cpHudInfoTexts.colorHeader)
end

function HudColorSetting:cpBaseHud_init(cpBaseHud, superFunc, ...)
	self:findOverlaysByColor(superFunc, {cpBaseHud, ...}, cpBaseHud.HEADER_COLOR)
end


TorchSetting = {}

local TorchSetting_mt = Class(TorchSetting)

function TorchSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or TorchSetting_mt)

	AdditionalSettingsUtil.registerEventListener("onLoad", self)

	self.active = false
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MISSION_START

	return self
end

function TorchSetting:onLoad(filename)
	AdditionalSettingsUtil.overwrittenFunction(Player, "setFlashlightIsActive", self, "setFlashlightIsActive")
end

function TorchSetting:setFlashlightIsActive(player, superFunc, isActive, ...)
	if self.active and not isActive and player.currentHandTool ~= nil and player.currentHandTool.isFlashlight then
		player:setCurrentHandTool(nil)
	else
		superFunc(player, isActive, ...)
	end
end


WalkModeSetting = {}

local WalkModeSetting_mt = Class(WalkModeSetting)

function WalkModeSetting.new(custom_mt)
	local self = setmetatable({}, custom_mt or WalkModeSetting_mt)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	AdditionalSettingsUtil.appendedFunction(PlayerInputComponent, "update", self, "update")
	AdditionalSettingsUtil.appendedFunction(PlayerInputComponent, "onInputRun", self, "onInputRun")

	self.runModeEnabled = false
	self.runModeBlocked = false
	self.runModeState = 0

	self.inputRunClick = false

	self.lastClickTime = nil
	self.doubleClickInterval = 400

	return self
end

function WalkModeSetting:update(playerInputComponent, dt)
	if self.state == 1 then
		if playerInputComponent.walkAxis > 0 then
			if not self.runModeEnabled and playerInputComponent.runAxis > 0 then
				self.runModeEnabled = true
			end
		elseif self.runModeEnabled or self.force then
			self.runModeEnabled = false
			self.runModeBlocked = false
			self.runModeState = 0
		end

		local runningSpeed = 1

		if self.runModeState == 2 then
			local runModeSetting = g_additionalSettingsManager:getSettingByName("runMode")

			runningSpeed = runModeSetting:getRunningSpeed()
		end

		playerInputComponent.runAxis = self.runModeEnabled and not self.runModeBlocked and runningSpeed or 0
	else
		self.runModeEnabled = false
		self.runModeBlocked = false
		self.runModeState = 0
	end
end

function WalkModeSetting:onInputRun(playerInputComponent, _, inputValue)
	if self.state == 1 then
		local keyPressed = not playerInputComponent.locked and inputValue > 0

		if keyPressed and not self.inputRunClick then
			self.runModeState = self.runModeState + 1

			local numStages = 2

			if g_additionalSettingsManager:getSettingStateByName("runMode") > 0 then
				if self.lastClickTime == nil or self.lastClickTime <= g_time - self.doubleClickInterval then
					self.lastClickTime = g_time
				else
					if self.runModeState == 2 then
						numStages = 3
					end

					self.lastClickTime = nil
				end
			end

			if self.runModeState >= numStages then
				self.runModeState = 0
			end

			if self.runModeEnabled then
				self.runModeBlocked = self.runModeState == 0
			end

			self.inputRunClick = true
		elseif not keyPressed and self.inputRunClick then
			self.inputRunClick = false
		end
	else
		self.inputRunClick = false
	end
end

function WalkModeSetting:onStateChange(state, optionElement, loadFromSavegame)
	if optionElement ~= nil then
		local target = optionElement.target

		target.multiRunMode:setDisabled(state == 0)
	end
end


CrouchModeSettings = {}

local CrouchModeSettings_mt = Class(CrouchModeSettings)

function CrouchModeSettings.new(custom_mt)
	local self = setmetatable({}, custom_mt or CrouchModeSettings_mt)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	AdditionalSettingsUtil.appendedFunction(PlayerInputComponent, "update", self, "update")
	AdditionalSettingsUtil.appendedFunction(PlayerInputComponent, "onInputCrouch", self, "onInputCrouch")

	self.crouchModeEnabled = false
	self.inputCrouchClick = false

	return self
end

function CrouchModeSettings:update(playerInputComponent, dt)
	if self.state == 1 then
		playerInputComponent.crouchValue = self.crouchModeEnabled and 1 or 0
		playerInputComponent.lockedCrouchValue = self.crouchModeEnabled and 1 or 0
	else
		self.crouchModeEnabled = false
	end
end

function CrouchModeSettings:onInputCrouch(playerInputComponent, _, inputValue)
	if self.state == 1 then
		local keyPressed = not playerInputComponent.locked and inputValue > 0

		if keyPressed and not self.inputCrouchClick then
			self.crouchModeEnabled = not self.crouchModeEnabled

			self.inputCrouchClick = true
		elseif not keyPressed and self.inputCrouchClick then
			self.inputCrouchClick = false
		end
	else
		self.inputCrouchClick = false
	end
end


RunModeSettings = {}

local RunModeSettings_mt = Class(RunModeSettings)

function RunModeSettings.new(custom_mt)
	local self = setmetatable({}, custom_mt or RunModeSettings_mt)

	self.state = 0
	self.loadState = AdditionalSettingsManager.LOAD_STATE.MAP_LOAD

	self.modes = {1.5, 2, 2.5, 3, 3.5, 4}

	return self
end

function RunModeSettings:onTabOpen(optionElement)
	optionElement:setDisabled(g_additionalSettingsManager:getSettingStateByName("walkMode") == 0)
end

function RunModeSettings:onCreateElement(optionElement)
	local texts = {
		g_i18n:getText("ui_off")
	}

	for _, mode in pairs(self.modes) do
		table.insert(texts, string.format("%.1fX", mode))
	end

	optionElement:setTexts(texts)
end

function RunModeSettings:getRunningSpeed()
	if self.state == 0 then
		return 1
	end

	return self.modes[self.state] or 1
end


DebugSettings = {}

local DebugSettings_mt = Class(DebugSettings)

function DebugSettings.new(custom_mt)
	local self = setmetatable({}, custom_mt or DebugSettings_mt)

	self.loadState = AdditionalSettingsManager.LOAD_STATE.NO

	if gEnv.g_isDevelopmentVersion then
		AdditionalSettingsUtil.registerEventListener("onLoad", self)
		AdditionalSettingsUtil.registerEventListener("onDelete", self)
		AdditionalSettingsUtil.overwrittenFunction(HUD, "drawBaseHUD", self, "overwritttenFunc")
		AdditionalSettingsUtil.overwrittenFunction(Player, "createConsoleCommands", self, "overwritttenFunc")
	end

	return self
end

function DebugSettings:onLoad(filename)
	addConsoleCommand("agsPrintTable", "", "consoleCommandPrintTable", self)
end

function DebugSettings:onDelete()
	removeConsoleCommand("agsPrintTable")
end

function DebugSettings:overwritttenFunc(target, superFunc, ...)
	local isDevelopmentVersion = gEnv.g_isDevelopmentVersion

	gEnv.g_isDevelopmentVersion = false
	superFunc(target, ...)
	gEnv.g_isDevelopmentVersion = isDevelopmentVersion
end

function DebugSettings:consoleCommandPrintTable(inputTable, depth, maxDepth)
	if inputTable ~= nil then
		setFileLogPrefixTimestamp(false)

		depth = depth or 0
		maxDepth = maxDepth or 0

		print("")
		print("==================== START ====================")
		gEnv.loadstring(string.format("DebugUtil.printTableRecursively(%s, '-', %d ,%d)", inputTable, depth, maxDepth))()
		print("==================== END ====================")

		setFileLogPrefixTimestamp(g_logFilePrefixTimestamp)
	else
		return "Usage: agsPrintTable <table> <depth> <maxDepth>"
	end
end