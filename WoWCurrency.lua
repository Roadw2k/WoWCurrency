local ADDON_NAME, Addon = ...

local GOLD = "|cffffd66b"
local WHITE = "|cfff4ead0"
local RESET = "|r"
local COIN_ICON = "Interface\\Icons\\inv_10_fishing_dragonislescoins_bronze"
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local CreateRow

local state = {
    rows = {},
    visibleRows = {},
    currencies = {},
    search = "",
    selectedCategories = {},
    autoCategories = {},
    filterMode = "MANUAL",
    autoExpansion = nil,
    sort = "name",
    ascending = true,
}

local function ColorText(text, color)
    return (color or WHITE) .. tostring(text or "") .. RESET
end

local function Comma(value)
    value = math.floor(tonumber(value) or 0)
    local sign = value < 0 and "-" or ""
    local digits = tostring(math.abs(value))
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. formatted
end

local function FormatMoney(copper)
    copper = math.max(0, tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    return string.format("%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t  %02d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t  %02d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", Comma(gold), silver, bronze)
end

local function SetBackdrop(frame, r, g, b, a, borderAlpha)
    if frame.SetBackdrop then
        frame:SetBackdrop(BACKDROP)
        frame:SetBackdropColor(r, g, b, a)
        frame:SetBackdropBorderColor(0.78, 0.56, 0.18, borderAlpha or 1)
    end
end

local function AddTooltipLine(label, value)
    if value ~= nil and value ~= "" then
        GameTooltip:AddDoubleLine(label, tostring(value), 0.72, 0.68, 0.58, 1, 0.83, 0.42)
    end
end

local function GetFlavor()
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return "Retail" end
    if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return "Classic Era" end
    if WOW_PROJECT_CATACLYSM_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then return "Cataclysm Classic" end
    if WOW_PROJECT_MISTS_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then return "Mists of Pandaria Classic" end
    return "WoW Classic"
end

local function GetCurrencyListSizeCompat()
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        return C_CurrencyInfo.GetCurrencyListSize() or 0
    elseif GetCurrencyListSize then
        return GetCurrencyListSize() or 0
    end
    return 0
end

local function ExpandCurrencyHeaderCompat(index)
    if C_CurrencyInfo and C_CurrencyInfo.ExpandCurrencyList then
        C_CurrencyInfo.ExpandCurrencyList(index, true)
    elseif ExpandCurrencyList then
        ExpandCurrencyList(index, true)
    end
end

local function GetCurrencyInfoCompat(index)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo then
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)
        if not info then return nil end
        return {
            name = info.name,
            isHeader = info.isHeader,
            isHeaderExpanded = info.isHeaderExpanded,
            isTypeUnused = info.isTypeUnused,
            isShowInBackpack = info.isShowInBackpack,
            quantity = info.quantity,
            iconFileID = info.iconFileID,
            maxQuantity = info.maxQuantity,
            maxWeeklyQuantity = info.maxWeeklyQuantity,
            quantityEarnedThisWeek = info.quantityEarnedThisWeek,
            discovered = info.discovered,
            quality = info.quality,
            description = info.description,
            totalEarned = info.totalEarned,
            useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
            isAccountWide = info.isAccountWide,
            isAccountTransferable = info.isAccountTransferable,
            currencyID = info.currencyID,
        }
    elseif GetCurrencyListInfo then
        local name, isHeader, isExpanded, isUnused, isWatched, count, icon, max, canEarnPerWeek, earnedThisWeek = GetCurrencyListInfo(index)
        if not name then return nil end
        return {
            name = name,
            isHeader = isHeader,
            isHeaderExpanded = isExpanded,
            isTypeUnused = isUnused,
            isShowInBackpack = isWatched,
            quantity = count,
            iconFileID = icon,
            maxQuantity = max,
            maxWeeklyQuantity = 0,
            quantityEarnedThisWeek = canEarnPerWeek and earnedThisWeek or 0,
            discovered = true,
        }
    end
end

local function GetCurrencyDetailsCompat(index, info)
    if not info then return {} end

    local details = info
    if info.currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        details = C_CurrencyInfo.GetCurrencyInfo(info.currencyID) or info
    elseif C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListLink and C_CurrencyInfo.GetCurrencyInfoFromLink then
        local link = C_CurrencyInfo.GetCurrencyListLink(index)
        if link then details = C_CurrencyInfo.GetCurrencyInfoFromLink(link) or info end
    end

    return {
        description = details.description or info.description,
        totalEarned = details.totalEarned or info.totalEarned,
        useTotalEarnedForMaxQty = details.useTotalEarnedForMaxQty or info.useTotalEarnedForMaxQty,
        isAccountWide = details.isAccountWide or info.isAccountWide,
        isAccountTransferable = details.isAccountTransferable or info.isAccountTransferable,
        currencyID = details.currencyID or info.currencyID,
    }
end

local function NormalizeCategory(category)
    if category == "Features" or category == "Season 2" then
        return "Midnight"
    end
    return category
end

local function CollectCurrencies()
    wipe(state.currencies)

    local money = GetMoney and GetMoney() or 0
    state.currencies[#state.currencies + 1] = {
        index = 0,
        name = "Gold",
        category = "Character",
        quantity = math.floor(money / 10000),
        copper = money,
        maxQuantity = 0,
        weeklyMax = 0,
        earnedThisWeek = 0,
        totalEarned = 0,
        icon = COIN_ICON,
        description = "The money carried by this character.",
        isMoney = true,
    }

    local category = "General"
    local index = 1

    while index <= GetCurrencyListSizeCompat() do
        local info = GetCurrencyInfoCompat(index)
        if info and info.name then
            if info.isHeader then
                category = NormalizeCategory(info.name)
                if info.isHeaderExpanded == false then
                    ExpandCurrencyHeaderCompat(index)
                end
            elseif not info.isTypeUnused and info.discovered ~= false then
                local details = GetCurrencyDetailsCompat(index, info)
                state.currencies[#state.currencies + 1] = {
                    index = index,
                    name = info.name,
                    category = category,
                    quantity = tonumber(info.quantity) or 0,
                    maxQuantity = tonumber(info.maxQuantity) or 0,
                    weeklyMax = tonumber(info.maxWeeklyQuantity) or 0,
                    earnedThisWeek = tonumber(info.quantityEarnedThisWeek) or 0,
                    icon = info.iconFileID or COIN_ICON,
                    watched = info.isShowInBackpack,
                    quality = info.quality,
                    description = details.description,
                    totalEarned = tonumber(details.totalEarned) or 0,
                    useTotalEarnedForMaxQty = details.useTotalEarnedForMaxQty,
                    isAccountWide = details.isAccountWide,
                    isAccountTransferable = details.isAccountTransferable,
                    currencyID = details.currencyID,
                }
            end
        end
        index = index + 1
    end
end

local function GetCategories()
    local found, categories = {}, {"All"}
    for _, currency in ipairs(state.currencies) do
        if not found[currency.category] then
            found[currency.category] = true
            categories[#categories + 1] = currency.category
        end
    end
    table.sort(categories, function(a, b)
        if a == "All" then return true end
        if b == "All" then return false end
        return a < b
    end)
    return categories
end

local EXPANSION_ZONES = {
    {label = "Midnight", maps = {"quel'thalas", "eversong woods", "zul'aman", "harandar", "voidstorm"}, categories = {"midnight"}},
    {label = "The War Within", maps = {"khaz algar", "isle of dorn", "ringing deeps", "hallowfall", "azj-kahet", "undermine", "k'aresh"}, categories = {"war within", "khaz algar"}},
    {label = "Dragonflight", maps = {"dragon isles", "zaralek cavern", "emerald dream"}, categories = {"dragonflight", "dragon isles"}},
    {label = "Shadowlands", maps = {"shadowlands", "oribos", "the maw", "zereth mortis"}, categories = {"shadowlands"}},
    {label = "Battle for Azeroth", maps = {"kul tiras", "zandalar", "nazjatar", "mechagon"}, categories = {"battle for azeroth", "bfa"}},
    {label = "Legion", maps = {"broken isles", "argus"}, categories = {"legion"}},
    {label = "Warlords of Draenor", maps = {"draenor"}, categories = {"warlords of draenor", "draenor"}},
    {label = "Mists of Pandaria", maps = {"pandaria"}, categories = {"mists of pandaria", "pandaria"}},
    {label = "Wrath of the Lich King", maps = {"northrend"}, categories = {"wrath of the lich king", "northrend"}},
    {label = "Burning Crusade", maps = {"outland"}, categories = {"burning crusade", "outland"}},
}

local function GetZoneExpansion()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local visited = {}
    while mapID and not visited[mapID] do
        visited[mapID] = true
        local info = C_Map.GetMapInfo(mapID)
        if not info then break end
        local mapName = (info.name or ""):lower()
        for _, expansion in ipairs(EXPANSION_ZONES) do
            for _, name in ipairs(expansion.maps) do
                if mapName == name or mapName:find(name, 1, true) then return expansion end
            end
        end
        mapID = info.parentMapID
    end
end

local function UpdateAutoCategories()
    wipe(state.autoCategories)
    local expansion = GetZoneExpansion()
    state.autoExpansion = expansion and expansion.label or nil
    if not expansion then return end

    for _, category in ipairs(GetCategories()) do
        local lowerCategory = category:lower()
        for _, pattern in ipairs(expansion.categories) do
            if lowerCategory:find(pattern, 1, true) then
                state.autoCategories[category] = true
                break
            end
        end
    end
end

local function GetActiveCategories()
    if state.filterMode == "AUTO" and state.autoExpansion then return state.autoCategories end
    return state.selectedCategories
end

local function GetCategoryFilterLabel()
    if state.filterMode == "AUTO" then
        return state.autoExpansion or "All zones"
    end

    local count, selected = 0, nil
    for category in pairs(state.selectedCategories) do
        count = count + 1
        selected = category
    end
    if count == 0 then return "All" end
    if count == 1 then return selected end
    return count .. " categories"
end

local function MatchesFilters(currency)
    local activeCategories = GetActiveCategories()
    if state.filterMode == "AUTO" and state.autoExpansion then
        if not activeCategories[currency.category] then return false end
    elseif next(activeCategories) and not activeCategories[currency.category] then
        return false
    end
    local query = state.search:lower()
    if query ~= "" and not currency.name:lower():find(query, 1, true) and not currency.category:lower():find(query, 1, true) then
        return false
    end
    return true
end

local function SortCurrencies(a, b)
    local av, bv
    if state.sort == "quantity" then
        av, bv = a.quantity, b.quantity
    elseif state.sort == "weekly" then
        av, bv = a.earnedThisWeek, b.earnedThisWeek
    elseif state.sort == "max" then
        av, bv = a.maxQuantity, b.maxQuantity
    elseif state.sort == "category" then
        av, bv = a.category:lower(), b.category:lower()
    else
        av, bv = a.name:lower(), b.name:lower()
    end
    if av == bv then return a.name:lower() < b.name:lower() end
    if state.ascending then return av < bv else return av > bv end
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function ShowCurrencyTooltip(row)
    local currency = row.currency
    if not currency then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(currency.name, 1, 0.82, 0.35)
    if currency.description and currency.description ~= "" then
        GameTooltip:AddLine(currency.description, 0.92, 0.88, 0.78, true)
    end
    GameTooltip:AddLine(" ")
    AddTooltipLine("Category", currency.category)
    if currency.isMoney then
        AddTooltipLine("Amount", FormatMoney(currency.copper))
    else
        AddTooltipLine("Quantity", Comma(currency.quantity))
    end
    if currency.maxQuantity > 0 then AddTooltipLine("Maximum", Comma(currency.maxQuantity)) end
    if currency.weeklyMax > 0 then AddTooltipLine("This week", Comma(currency.earnedThisWeek) .. " / " .. Comma(currency.weeklyMax)) end
    if (tonumber(currency.totalEarned) or 0) > 0 then AddTooltipLine("Total earned", Comma(currency.totalEarned)) end
    if currency.isAccountWide then GameTooltip:AddLine("Warband-wide currency", 0.35, 0.78, 1) end
    if currency.isAccountTransferable then GameTooltip:AddLine("Transferable between characters", 0.35, 0.78, 1) end
    if currency.watched then GameTooltip:AddLine("Shown in backpack", 0.45, 0.9, 0.45) end
    if currency.currencyID then AddTooltipLine("Currency ID", currency.currencyID) end
    GameTooltip:Show()
end

local function CreateFont(parent, size, color, justify)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    font:SetFont(STANDARD_TEXT_FONT, size, "")
    font:SetTextColor(unpack(color or {0.93, 0.88, 0.76}))
    font:SetJustifyH(justify or "LEFT")
    return font
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 28)
    SetBackdrop(button, 0.10, 0.085, 0.055, 0.96, 0.7)
    button.text = CreateFont(button, 12, {0.94, 0.78, 0.38}, "CENTER")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.22, 0.16, 0.07, 1)
        self:SetBackdropBorderColor(1, 0.72, 0.2, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.10, 0.085, 0.055, 0.96)
        self:SetBackdropBorderColor(0.78, 0.56, 0.18, 0.7)
    end)
    return button
end

local function SaveWindowPosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    WoWCurrencyDB.window = {point = point, relativePoint = relativePoint, x = x, y = y}
end

local function RestoreWindowPosition(frame)
    local position = WoWCurrencyDB.window
    frame:ClearAllPoints()
    if position and position.point then
        frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
    else
        frame:SetPoint("CENTER", 0, 30)
    end
end

local function UpdateSortLabels()
    if not Addon.frame then return end
    local arrow = state.ascending and " ^" or " v"
    for key, button in pairs(Addon.frame.sortButtons) do
        button.text:SetText(button.label .. (state.sort == key and arrow or ""))
    end
end

local function UpdateRows()
    local frame = Addon.frame
    if not frame then return end
    wipe(state.visibleRows)
    for _, currency in ipairs(state.currencies) do
        if MatchesFilters(currency) then state.visibleRows[#state.visibleRows + 1] = currency end
    end
    table.sort(state.visibleRows, SortCurrencies)

    while #state.rows < #state.visibleRows do
        state.rows[#state.rows + 1] = CreateRow(frame.content, #state.rows + 1)
    end

    for index, row in ipairs(state.rows) do
        local currency = state.visibleRows[index]
        row.currency = currency
        if currency then
            row:Show()
            row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -((index - 1) * 42))
            row.icon:SetTexture(currency.icon)
            row.name:SetText(currency.name)
            row.category:SetText(currency.category)
            row.quantity:SetText(currency.isMoney and FormatMoney(currency.copper) or Comma(currency.quantity))
            row.maximum:SetText(currency.maxQuantity > 0 and Comma(currency.maxQuantity) or "—")
            if currency.maxQuantity > 0 then
                local current = currency.useTotalEarnedForMaxQty and currency.totalEarned or currency.quantity
                local percent = math.min(1, current / currency.maxQuantity)
                row.progress:SetValue(percent)
                row.progress:Show()
                if percent >= 1 then row.maximum:SetTextColor(1, 0.36, 0.28) else row.maximum:SetTextColor(0.74, 0.68, 0.57) end
            else
                row.progress:Hide()
                row.maximum:SetTextColor(0.74, 0.68, 0.57)
            end
            if currency.weeklyMax > 0 then
                row.weekly:SetText(Comma(currency.earnedThisWeek) .. " / " .. Comma(currency.weeklyMax))
            else
                row.weekly:SetText("—")
            end
            row.account:SetShown(currency.isAccountWide or currency.isAccountTransferable)
            row:SetBackdropColor(index % 2 == 0 and 0.075 or 0.095, index % 2 == 0 and 0.068 or 0.082, 0.05, 0.95)
        else
            row:Hide()
        end
    end

    local contentHeight = math.max(1, #state.visibleRows * 42)
    frame.content:SetHeight(contentHeight)
    frame.empty:SetShown(#state.visibleRows == 0)
    frame.count:SetText(string.format("%d of %d currencies", #state.visibleRows, #state.currencies))
    frame.money:SetText(FormatMoney(GetMoney and GetMoney() or 0))
    UpdateSortLabels()
end

local function Refresh()
    CollectCurrencies()
    UpdateAutoCategories()
    if Addon.frame then
        Addon.frame.categoryButton.text:SetText(GetCategoryFilterLabel())
        Addon.frame.modeButton.text:SetText(state.filterMode == "AUTO" and "Auto" or "Manual")
        UpdateRows()
    end
end

CreateRow = function(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(42)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    SetBackdrop(row, 0.095, 0.082, 0.05, 0.95, 0)
    row:SetBackdropBorderColor(0, 0, 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = CreateFont(row, 13, {0.96, 0.88, 0.68})
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -5)
    row.name:SetWidth(210)
    row.name:SetWordWrap(false)

    row.category = CreateFont(row, 10, {0.55, 0.51, 0.43})
    row.category:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 9, 4)
    row.category:SetWidth(210)
    row.category:SetWordWrap(false)

    row.quantity = CreateFont(row, 13, {1, 0.82, 0.35}, "RIGHT")
    row.quantity:SetPoint("RIGHT", row, "RIGHT", -252, 0)
    row.quantity:SetWidth(145)

    row.maximum = CreateFont(row, 12, {0.74, 0.68, 0.57}, "RIGHT")
    row.maximum:SetPoint("RIGHT", row, "RIGHT", -139, 0)
    row.maximum:SetWidth(90)

    row.weekly = CreateFont(row, 11, {0.63, 0.73, 0.84}, "RIGHT")
    row.weekly:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    row.weekly:SetWidth(110)

    row.progress = CreateFrame("StatusBar", nil, row)
    row.progress:SetSize(90, 2)
    row.progress:SetPoint("BOTTOM", row.maximum, "BOTTOM", 0, -8)
    row.progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    row.progress:SetStatusBarColor(0.92, 0.62, 0.12)
    row.progress:SetMinMaxValues(0, 1)
    row.progress.bg = row.progress:CreateTexture(nil, "BACKGROUND")
    row.progress.bg:SetAllPoints()
    row.progress.bg:SetColorTexture(0.23, 0.20, 0.15, 1)

    row.account = row:CreateTexture(nil, "OVERLAY")
    row.account:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    row.account:SetSize(12, 12)
    row.account:SetPoint("TOPRIGHT", row.icon, "TOPRIGHT", 3, 3)

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.16, 0.12, 0.055, 1)
        ShowCurrencyTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        local i = self.rowIndex
        self:SetBackdropColor(i % 2 == 0 and 0.075 or 0.095, i % 2 == 0 and 0.068 or 0.082, 0.05, 0.95)
        HideTooltip()
    end)
    row.rowIndex = index
    return row
end

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "WoWCurrencyFrame", UIParent, "BackdropTemplate")
    Addon.frame = frame
    frame:SetSize(700, 570)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveWindowPosition(self) end)
    frame:SetScript("OnShow", Refresh)
    SetBackdrop(frame, 0.035, 0.031, 0.024, 0.985, 1)
    RestoreWindowPosition(frame)

    frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.header:SetPoint("TOPLEFT", 1, -1)
    frame.header:SetPoint("TOPRIGHT", -1, -1)
    frame.header:SetHeight(70)
    SetBackdrop(frame.header, 0.11, 0.075, 0.025, 1, 0)
    frame.header:SetBackdropBorderColor(0, 0, 0, 0)

    frame.logo = frame.header:CreateTexture(nil, "ARTWORK")
    frame.logo:SetTexture(COIN_ICON)
    frame.logo:SetSize(44, 44)
    frame.logo:SetPoint("LEFT", 17, 0)
    frame.logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.title = CreateFont(frame.header, 20, {1, 0.79, 0.28})
    frame.title:SetPoint("TOPLEFT", frame.logo, "TOPRIGHT", 12, -10)
    frame.title:SetText("WoW Currency")

    frame.subtitle = CreateFont(frame.header, 11, {0.69, 0.62, 0.48})
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.subtitle:SetText(GetFlavor() .. " • Your wealth at a glance")

    frame.money = CreateFont(frame.header, 12, {0.95, 0.88, 0.68}, "RIGHT")
    frame.money:SetPoint("RIGHT", frame.header, "RIGHT", -52, -13)

    frame.close = CreateButton(frame.header, "×", 28)
    frame.close:SetPoint("TOPRIGHT", -10, -9)
    frame.close.text:SetFont(STANDARD_TEXT_FONT, 20, "")
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    frame.search:SetSize(190, 30)
    frame.search:SetPoint("TOPLEFT", 15, -82)
    frame.search:SetAutoFocus(false)
    frame.search:SetFontObject(GameFontHighlightSmall)
    frame.search:SetTextInsets(31, 8, 0, 0)
    SetBackdrop(frame.search, 0.07, 0.062, 0.048, 1, 0.55)
    frame.search.icon = frame.search:CreateTexture(nil, "ARTWORK")
    frame.search.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    frame.search.icon:SetSize(16, 16)
    frame.search.icon:SetPoint("LEFT", 9, 0)
    frame.search.placeholder = CreateFont(frame.search, 12, {0.45, 0.42, 0.36})
    frame.search.placeholder:SetPoint("LEFT", 31, 0)
    frame.search.placeholder:SetText("Search currencies...")
    frame.search:SetScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        self.placeholder:SetShown(state.search == "")
        UpdateRows()
    end)
    frame.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    frame.categoryButton = CreateButton(frame, "All", 145)
    frame.categoryButton:SetPoint("LEFT", frame.search, "RIGHT", 10, 0)
    frame.categoryButton:SetScript("OnClick", function(self)
        if state.filterMode == "AUTO" then
            state.filterMode = "MANUAL"
            WoWCurrencyDB.filterMode = state.filterMode
            frame.modeButton.text:SetText("Manual")
            self.text:SetText(GetCategoryFilterLabel())
        end
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle("Currency categories")
                root:CreateCheckbox("All", function()
                    return not next(state.selectedCategories)
                end, function()
                    wipe(state.selectedCategories)
                    WoWCurrencyDB.manualCategories = state.selectedCategories
                    self.text:SetText(GetCategoryFilterLabel())
                    UpdateRows()
                end)
                root:CreateDivider()
                for _, category in ipairs(GetCategories()) do
                    if category ~= "All" then
                        local currentCategory = category
                        root:CreateCheckbox(currentCategory, function()
                            return state.selectedCategories[currentCategory] == true
                        end, function()
                            state.selectedCategories[currentCategory] = not state.selectedCategories[currentCategory] or nil
                            WoWCurrencyDB.manualCategories = state.selectedCategories
                            self.text:SetText(GetCategoryFilterLabel())
                            UpdateRows()
                        end)
                    end
                end
            end)
        else

            local categories = GetCategories()
            local current = GetCategoryFilterLabel()
            local nextIndex = 1
            for i, value in ipairs(categories) do
                if value == current then nextIndex = i % #categories + 1 break end
            end
            wipe(state.selectedCategories)
            if categories[nextIndex] ~= "All" then
                state.selectedCategories[categories[nextIndex]] = true
            end
            WoWCurrencyDB.manualCategories = state.selectedCategories
            self.text:SetText(GetCategoryFilterLabel())
            UpdateRows()
        end
    end)

    frame.modeButton = CreateButton(frame, state.filterMode == "AUTO" and "Auto" or "Manual", 80)
    frame.modeButton:SetPoint("LEFT", frame.categoryButton, "RIGHT", 10, 0)
    frame.modeButton:SetScript("OnClick", function(self)
        state.filterMode = state.filterMode == "AUTO" and "MANUAL" or "AUTO"
        WoWCurrencyDB.filterMode = state.filterMode
        self.text:SetText(state.filterMode == "AUTO" and "Auto" or "Manual")
        UpdateAutoCategories()
        frame.categoryButton.text:SetText(GetCategoryFilterLabel())
        UpdateRows()
    end)

    frame.refresh = CreateButton(frame, "Refresh", 80)
    frame.refresh:SetPoint("LEFT", frame.modeButton, "RIGHT", 10, 0)
    frame.refresh:SetScript("OnClick", Refresh)

    frame.count = CreateFont(frame, 11, {0.58, 0.54, 0.46}, "RIGHT")
    frame.count:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    frame.count:SetPoint("TOP", frame.search, "TOP", 0, -9)
    frame.count:SetWidth(120)

    frame.columnHeader = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.columnHeader:SetPoint("TOPLEFT", 15, -122)
    frame.columnHeader:SetPoint("TOPRIGHT", -15, -122)
    frame.columnHeader:SetHeight(27)
    SetBackdrop(frame.columnHeader, 0.085, 0.072, 0.048, 1, 0.35)

    frame.sortButtons = {}
    local columns = {
        {key = "name", label = "CURRENCY", x = 48, width = 210, justify = "LEFT"},
        {key = "quantity", label = "OWNED", x = 317, width = 88, justify = "RIGHT"},
        {key = "max", label = "MAX", x = 430, width = 90, justify = "RIGHT"},
        {key = "weekly", label = "WEEKLY", x = 539, width = 110, justify = "RIGHT"},
    }
    for _, column in ipairs(columns) do
        local button = CreateFrame("Button", nil, frame.columnHeader)
        button:SetPoint("LEFT", column.x, 0)
        button:SetSize(column.width, 27)
        button.label = column.label
        button.text = CreateFont(button, 10, {0.72, 0.59, 0.33}, column.justify)
        button.text:SetAllPoints()
        button:SetScript("OnClick", function()
            local sortKey = column.key
            if state.sort == sortKey then state.ascending = not state.ascending else state.sort = sortKey; state.ascending = true end
            UpdateRows()
        end)
        frame.sortButtons[column.key] = button
    end

    frame.scroll = CreateFrame("ScrollFrame", "WoWCurrencyScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 15, -153)
    frame.scroll:SetPoint("BOTTOMRIGHT", -35, 42)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetWidth(648)
    frame.content:SetHeight(1)
    frame.scroll:SetScrollChild(frame.content)

    for index = 1, 40 do
        state.rows[index] = CreateRow(frame.content, index)
    end

    frame.empty = CreateFont(frame, 14, {0.62, 0.57, 0.47}, "CENTER")
    frame.empty:SetPoint("CENTER", frame.scroll, "CENTER", 0, 15)
    frame.empty:SetText("No currencies match your filters.\nTry another search or category.")

    frame.footer = CreateFont(frame, 10, {0.47, 0.43, 0.36})
    frame.footer:SetPoint("BOTTOMLEFT", 16, 15)
    frame.footer:SetText("Hover a currency for details.     -     Made by Roadw2k")

    frame:Hide()
end

local function UpdateMinimapPosition()
    if not Addon.minimap then return end
    local angle = math.rad(WoWCurrencyDB.minimapAngle or 225)
    local radius = 80
    Addon.minimap:ClearAllPoints()
    Addon.minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function CreateMinimapButton()
    local button = CreateFrame("Button", "WoWCurrencyMinimapButton", Minimap)
    Addon.minimap = button
    button:SetSize(34, 34)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetSize(56, 56)
    button.border:SetPoint("TOPLEFT", 0, 0)

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.background:SetSize(22, 22)
    button.background:SetPoint("CENTER", 0, 1)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(COIN_ICON)
    button.icon:SetSize(22, 22)
    button.icon:SetPoint("CENTER", 0, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAllPoints()

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            WoWCurrencyDB.hideMinimap = true
            button:Hide()
            print(GOLD .. "WoW Currency:" .. RESET .. " minimap button hidden. Type /wc minimap to restore it.")
        else
            Addon:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            WoWCurrencyDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdateMinimapPosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("WoW Currency", 1, 0.82, 0.35)
        GameTooltip:AddLine("Left-click to open", 0.9, 0.86, 0.75)
        GameTooltip:AddLine("Drag to move", 0.9, 0.86, 0.75)
        GameTooltip:AddLine("Right-click to hide", 0.9, 0.86, 0.75)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltip)
    UpdateMinimapPosition()
    button:SetShown(not WoWCurrencyDB.hideMinimap)
end

function Addon:Toggle()
    if not self.frame then CreateMainFrame() end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

local function HandleSlashCommand(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "minimap" then
        WoWCurrencyDB.hideMinimap = false
        Addon.minimap:Show()
        print(GOLD .. "WoW Currency:" .. RESET .. " minimap button restored.")
    elseif command == "reset" then
        WoWCurrencyDB.window = nil
        WoWCurrencyDB.minimapAngle = 225
        if Addon.frame then RestoreWindowPosition(Addon.frame) end
        UpdateMinimapPosition()
        print(GOLD .. "WoW Currency:" .. RESET .. " positions reset.")
    elseif command == "help" then
        print(GOLD .. "WoW Currency commands:" .. RESET)
        print(WHITE .. "/wc|r - toggle the currency window")
        print(WHITE .. "/wc minimap|r - show the minimap button")
        print(WHITE .. "/wc reset|r - reset window and minimap positions")
    else
        Addon:Toggle()
    end
end

SLASH_WOWCURRENCY1 = "/wc"
SlashCmdList.WOWCURRENCY = HandleSlashCommand

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
if C_CurrencyInfo or GetCurrencyListSize then
    events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
end

events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= ADDON_NAME then return end
        WoWCurrencyDB = WoWCurrencyDB or {}
        if WoWCurrencyDB.minimapAngle == nil then WoWCurrencyDB.minimapAngle = 225 end
        WoWCurrencyDB.manualCategories = WoWCurrencyDB.manualCategories or {}
        if WoWCurrencyDB.manualCategories["Features"] or WoWCurrencyDB.manualCategories["Season 2"] then
            WoWCurrencyDB.manualCategories["Midnight"] = true
            WoWCurrencyDB.manualCategories["Features"] = nil
            WoWCurrencyDB.manualCategories["Season 2"] = nil
        end
        state.selectedCategories = WoWCurrencyDB.manualCategories
        state.filterMode = WoWCurrencyDB.filterMode == "AUTO" and "AUTO" or "MANUAL"
        CreateMinimapButton()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if not Addon.minimap then
            WoWCurrencyDB = WoWCurrencyDB or {minimapAngle = 225}
            CreateMinimapButton()
        end
        if Addon.frame and Addon.frame:IsShown() then Refresh() end
    elseif Addon.frame and Addon.frame:IsShown() then
        Refresh()
    end
end)

UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "WoWCurrencyFrame")
