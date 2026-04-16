Config = {
    ServerCallbacks = {},
    AutoDatabaseCreator = false,
    TestDriveTime = 30000,
    TeleportBackWhenTestFinishes = true,
    WarpPedToTestVehicle = true,
    SalesShare = 20,
    EnableSocietyAccount = true,
    Permissions = {"admin", "staff", "god"},
    AntiExploit = {
        EnableBan = true,
        EnableWebhook = true,
        WebhookUrl = "",
        RateLimitSeconds = 5,
        RequireRequestToken = true,
        TokenLength = 10
    },
    Language = {
        WarnOnMissing = true,
        Translations = {
            categories = {
                openwheel = "Open Wheel",
                sportsclassics = "Sports Classics",
                offroad = "Off-Road",
                cycles = "Cycles",
                motorcycles = "Motorcycles",
                vans = "Vans",
                super = "Super"
            },
            commands = {
                add_vehicle_stock = "Add Stock To Vehicle"
            }
        }
    },
    Cores = {
        {
            Name = "ESX",
            ResourceName = "es_extended",
            GetFramework = function() return exports["es_extended"]:getSharedObject() end
        },
        {
            Name = "QBCore",
            ResourceName = "qb-core",
            GetFramework = function() return exports["qb-core"]:GetCoreObject() end
        },
        {
            Name = "QBXCore",
            ResourceName = "qbx_core",
            GetFramework = function() return exports["qbx_core"]:GetCoreObject() end
        }
    },
    VehicleShops = {
        {
            ClearAreaOfNPCVehicles = true,
            Management = {
                Enable = false,
                Job = "cardealer"
            },
            EnableStocks = false,
            AllowedCategories = {"cycles", "super", "motorcycles", "vans", "sportsclassics"},
            Coords = {
                ShowroomVehicles = vector4(-47.68, -1094.61, 26.42, 133.71),
                BoughtVehicles = vector4(-32.21, -1091.13, 26.18, 336.48),
                TestVehicles = vector4(-32.21, -1091.13, 26.18, 336.48),
                SellingPoint = vector3(-30.82, -1106.09, 26.42)
            },
            Ped = {
                Enable = true,
                Coords = vector4(-57.13, -1099.05, 26.42, 22.75),
                Model = "a_m_y_hasjew_01",
                animDict = "amb@world_human_hang_out_street@female_arms_crossed@idle_a",
                animName = "idle_a"
            },
            ShowroomVehicles = {
                {coords = vector4(-50.67, -1116.44, 25.97, 2.26)},
                {coords = vector4(-53.56, -1116.84, 25.79, 3.36)},
                {coords = vector4(-56.3, -1116.97, 25.66, 1.13)},
                {coords = vector4(-59.18, -1116.89, 26.17, 1.44)},
                {coords = vector4(-61.83, -1117.06, 25.84, 2.23)}
            },
            Blip = {
                Enable = true,
                coords = vector3(-57.13, -1099.05, 26.42),
                sprite = 820,
                color = 0,
                scale = 0.5,
                text = "Gallery"
            },
            Interaction = {
                Target = {
                    Enable = false,
                    Distance = 2.0,
                    Label = "Open Gallery",
                    Icon = "fa-solid fa-car",
                    Label2 = "Open Management",
                    Icon2 = "fa-solid fa-car"
                },
                Text = {
                    Enable = true,
                    Distance = 3.0,
                    Label = "[E] Gallery"
                }
            }
        },
        {
            ClearAreaOfNPCVehicles = true,
            Management = {
                Enable = false,
                Job = "cardealer2"
            },
            EnableStocks = false,
            AllowedCategories = {"sedans", "offroad", "cycles", "motorcycles", "vans", "super", "sports", "coupes", "compacts", "suvs", "muscle"},
            Coords = {
                ShowroomVehicles = vector4(-1261.76, -358.17, 36.91, 275.01),
                BoughtVehicles = vector4(-1234.99, -344.63, 37.33, 23.41),
                TestVehicles = vector4(-32.21, -1091.13, 26.18, 336.48),
                SellingPoint = vector3(-1235.05, -344.53, 37.33)
            },
            Ped = {
                Enable = true,
                Coords = vector4(-1252.29, -349.42, 36.91, 121.73),
                Model = "a_m_y_hasjew_01",
                animDict = "amb@world_human_hang_out_street@female_arms_crossed@idle_a",
                animName = "idle_a"
            },
            ShowroomVehicles = {
                {coords = vector4(-1261.76, -358.17, 36.91, 275.01)}
            },
            Blip = {
                Enable = true,
                coords = vector3(-1252.29, -349.42, 36.91),
                sprite = 820,
                color = 0,
                scale = 0.5,
                text = "Gallery"
            },
            Interaction = {
                Target = {
                    Enable = false,
                    Distance = 2.0,
                    Label = "Open Gallery",
                    Icon = "fa-solid fa-car",
                    Label2 = "Open Management",
                    Icon2 = "fa-solid fa-car"
                },
                Text = {
                    Enable = true,
                    Distance = 3.0,
                    Label = "[E] Galery"
                }
            }
        }
    }
}

function Config.SetFuel(vehicle, fuel)
    exports["LegacyFuel"]:SetFuel(vehicle, fuel)
end

function Config.GiveKey(plate)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end

function Config.HUD(state)
    TriggerEvent('esx:toggleHUD', state)
end

function Config.AddManagementMoney(job, amount)
    exports['qb-management']:AddMoney(job, amount)
end

Cores = Config.Cores

Locale = {}
Locale.__index = Locale

local function translateKey(phrase, subs)
    if type(phrase) ~= "string" then
        error("TypeError: translateKey function expects arg #1 to be a string")
    end
    if not subs then
        return phrase
    end
    local result = phrase
    for k, v in pairs(subs) do
        local templateToFind = "%%{" .. k .. "}"
        result = result:gsub(templateToFind, tostring(v))
    end
    return result
end

function Locale.new(_, opts)
    local self = setmetatable({}, Locale)
    self.fallback = opts.fallbackLang and Locale:new({
        warnOnMissing = false,
        phrases = opts.fallbackLang.phrases
    }) or false
    self.warnOnMissing = type(opts.warnOnMissing) ~= "boolean" and true or opts.warnOnMissing
    self.phrases = {}
    self:extend(opts.phrases or {})
    return self
end

function Locale:extend(phrases, prefix)
    for key, phrase in pairs(phrases) do
        local prefixKey = prefix and ("%s.%s"):format(prefix, key) or key
        if type(phrase) == "table" then
            self:extend(phrase, prefixKey)
        else
            self.phrases[prefixKey] = phrase
        end
    end
end

function Locale:clear()
    self.phrases = {}
end

function Locale:replace(phrases)
    phrases = phrases or {}
    self:clear()
    self:extend(phrases)
end

function Locale:locale(newLocale)
    if newLocale then
        self.currentLocale = newLocale
    end
    return self.currentLocale
end

function Locale:t(key, subs)
    local phrase
    local result
    subs = subs or {}
    if type(self.phrases[key]) == "string" then
        phrase = self.phrases[key]
    else
        if self.warnOnMissing then
            print(("^3Warning: Missing phrase for key: \"%s\""):format(key))
        end
        if self.fallback then
            return self.fallback:t(key, subs)
        end
        result = key
    end
    if type(phrase) == "string" then
        result = translateKey(phrase, subs)
    end
    return result
end

function Locale:has(key)
    return self.phrases[key] ~= nil
end

function Locale:delete(phraseTarget, prefix)
    if type(phraseTarget) == "string" then
        self.phrases[phraseTarget] = nil
    else
        for key, phrase in pairs(phraseTarget) do
            local prefixKey = prefix and prefix .. "." .. key or key
            if type(phrase) == "table" then
                self:delete(phrase, prefixKey)
            else
                self.phrases[prefixKey] = nil
            end
        end
    end
end

local Translations = Config.Language.Translations

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = Config.Language.WarnOnMissing
})