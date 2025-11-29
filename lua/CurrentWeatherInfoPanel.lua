package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local Class = require("Class")
local Panel = require("Panel")
local Utils  = require("Utils")

-- Define the CurrentWeatherInfoPanel "class"
local CurrentWeatherInfoPanel = Class.new(Panel)  -- inherits Panel

-- Constructor
function CurrentWeatherInfoPanel:new(config)
    -- First call Panel constructor
    local self = CurrentWeatherInfoPanel.super.new(self, config) -- call Panel:new
    
    self.name = 'CurrentWeatherInfoPanel'

    self.buffered_chart_image = nil

    return self
end

-- Update chart data from JSON file
function CurrentWeatherInfoPanel:update(last_json, current_time)
    -- destroy old buffer image if not nil
    if self.buffered_chart_image then
        cairo_surface_destroy(self.buffered_chart_image)
    end

    -- create an image surface (ARGB32 = 32-bit color with alpha)
    self.buffered_chart_image = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, self.x_size, self.y_size)

    -- create a cairo context for drawing to the buffer
    local cr = cairo_create(self.buffered_chart_image)
    -- clear buffer
    cairo_set_source_rgba(cr, 0, 0, 0, 0)  -- transparent
    cairo_paint(cr)

    local current_condition = last_json.current
    local hour_now = tonumber(os.date("%H"))
    local hour_now_index = math.floor((hour_now)+1)
    
    local sunrise_ts = Utils.getDateFromDateTime(last_json.daily.sunrise[1],current_time)
    local sunset_ts = Utils.getDateFromDateTime(last_json.daily.sunset[1],current_time)
    local is_day = sunrise_ts < current_time and current_time < sunset_ts
    local dayNightString = "d"
    if not is_day then
        dayNightString = "n"
    end
    
    Utils.draw_scaled_image_surface(cr,getImage(Utils.getWMOIconPath(current_condition.weather_code,dayNightString .. "_t@2x-blue")),-5,-13,100,100)
    Utils.drawText(cr, 90,22,Utils.getDescriptionFromWMOIconCode(current_condition.weather_code),Utils.getFont("#3B5969FF",14))
    Utils.drawText(cr, 90,37,"Temp: " .. current_condition.temperature_2m .. "°C (" .. last_json.hourly.apparent_temperature[hour_now_index] .. "°C)")
    Utils.drawText(cr, 90,52,"Wolken: " .. current_condition.cloud_cover .. "%")
    local chanceOfPrecipitation = tonumber(last_json.hourly.precipitation_probability[hour_now_index])
    Utils.drawText(cr, 90,67,"Niederschlag: " .. chanceOfPrecipitation .. "%")

    Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/sun/sunrise_blue1.png"),232,4,26,26)
    Utils.drawText(cr, 268,22,Utils.splitString(last_json.daily.sunrise[1],"T")[2])
    Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/sun/sunset_blue1.png"),318,4,26,26)
    Utils.drawText(cr, 350,22,Utils.splitString(last_json.daily.sunset[1],"T")[2])
    Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/arrow/cardinal-points_clean_blue.png"),226,32,38,38)
    local winddirDegreeMod=(current_condition.wind_direction_10m % 45)
    winddirDegreeMod=math.floor(current_condition.wind_direction_10m - winddirDegreeMod)
    Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/arrow/arrow_blue2-" .. winddirDegreeMod .. ".png"),227,32,38,38)

    Utils.drawText(cr, 268,47,"Wind: " .. current_condition.wind_direction_10m .. "°, " .. current_condition.wind_speed_10m .."km/h")
    Utils.drawText(cr, 268,62,"Luftf.: " .. current_condition.relative_humidity_2m .. "% Druck: " .. current_condition.surface_pressure .."hPa")

    cairo_destroy(cr)
end

-- Draw CurrentWeatherInfoPanel using cairo
function CurrentWeatherInfoPanel:draw_content(cr)
    CurrentWeatherInfoPanel.super.draw_content(self,cr)

    if self.buffered_chart_image then
        cairo_set_source_surface(cr, self.buffered_chart_image, self.x_offset, self.y_offset)
        cairo_paint(cr)
    end
end

function CurrentWeatherInfoPanel:destroy()
    self.name = nil

    Panel.destroy(self)
end

return CurrentWeatherInfoPanel