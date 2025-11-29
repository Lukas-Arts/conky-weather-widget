package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local Class = require("Class")
local Panel = require("Panel")
local Chart = require('Chart')
local Utils  = require("Utils")

-- Define the WeeklyWeatherChartPanel "class"
local WeeklyWeatherChartPanel = Class.new(Panel)  -- inherits Panel

-- Constructor
function WeeklyWeatherChartPanel:new(config)
    -- First call Panel constructor
    local self = WeeklyWeatherChartPanel.super.new(self, config) -- call Panel:new
    
    self.last_json = nil
    self.chart = nil
    self.forecast2_minmax = { min = 0, max = 100 }
    self.name = 'WeeklyWeatherChartPanel'

    return self
end

-- Update chart data from JSON file
function WeeklyWeatherChartPanel:update(last_json)
    if self.chart then
        self:remove_panel(self.chart)
        self.chart:destroy()
    end
    self.last_json = last_json
    
    local temps=Utils.split_table(last_json.hourly.temperature_2m,24)
    local perticipprobs=Utils.split_table(last_json.hourly.precipitation_probability,24)
    local humidities=Utils.split_table(last_json.hourly.relative_humidity_2m,24)
    
    self.chart = self:add_7_days_forecast(temps.right,perticipprobs.right,humidities.right)
    self:add_panel(self.chart)
end

function WeeklyWeatherChartPanel:add_7_days_forecast(hourly_tempC,hourly_perticipprob,hourly_humidity)
    local chart = Chart:new({
        x_offset = 25,
        y_offset = 0 + self.y_offset,
        x_size = 350,
        y_size = 50,
        border_type = "plot-both",
        show_time_indicator = false
    })

    local border_props = chart:get_properties("#3B5969FF")
    -- Add border lines
    chart:add_borders(border_props)

    local minmax = { min = 0, max = 100 }
    local scaling = chart:get_scaling(minmax, #hourly_perticipprob, 10)
    local props = chart:get_properties("#3B596988")
    props.scale_props = scaling
    chart:add_scaled_series(hourly_humidity, props)
    local props2 = chart:get_properties("#88550066")
    props2.scale_props = scaling
    chart:add_scaled_series(hourly_perticipprob, props2, scaling)

    local polyprops = {
        color = "#3B596988", thickness = 1, antialiasing = false,
        series_type = "polygon", fill = true, fill_color = "#3B596940"
    }
    local err = { initial_error = 1.0, absolute_error = 0.02, per_cent_error = 0.0005, props = polyprops }
    self.forecast2_minmax = chart:add_scaled_series_with_error(hourly_tempC, chart:get_properties("#75A5CDFF"), err)
    
    return chart
end

-- Draw WeeklyWeatherChartPanel using cairo
function WeeklyWeatherChartPanel:draw_content(cr)
    WeeklyWeatherChartPanel.super.draw_content(self,cr)
    if self.last_json then
        local chart2Start = self.y_offset
        Utils.drawText(cr, 0,chart2Start + 10,string.format("%.0f°C",self.forecast2_minmax.max))
        Utils.drawText(cr, 380,chart2Start + 10,string.format("%.0f°C",self.forecast2_minmax.max))
        Utils.drawText(cr, 0,chart2Start + 50,string.format("%.0f°C",self.forecast2_minmax.min))
        Utils.drawText(cr, 380,chart2Start + 50,string.format("%.0f°C",self.forecast2_minmax.min))

        step = 350/143
        for i=0,143,1 do
            if i%12==0 then
                if i%24==0 then
                    Utils.drawLine(cr,25+i*step,chart2Start + 50,0,5)
                else
                    local dayOfWeekString = Utils.getDayOfWeekStringShort(os.date("%w",Utils.getDateFromDateTime(self.last_json.hourly.time[i+25])))
                    Utils.drawText(cr, 20+i*step,chart2Start + 63,dayOfWeekString)
                end
                --Utils.drawText(cr, 200,chart2Start + 65,"|")
                
                is_day = self.last_json.hourly.is_day[i+25] == 1
                dayNightString = "d"
                if not is_day then
                    dayNightString = "n"
                end

                local imagePath = Utils.getWMOIconPath(self.last_json.hourly.weather_code[i+25],dayNightString .. "_t@0.5x-blue")
                local image = getImage(imagePath)
                Utils.draw_scaled_image_surface(cr,image,14+i*step,chart2Start + 63,25,25)

                local val = tonumber(self.last_json.hourly.temperature_2m[i+25])
                local val2 = tonumber(self.last_json.hourly.apparent_temperature[i+25])
                if val >= 10 then
                    Utils.drawText(cr, 17+i*step,chart2Start + 95,string.format("%1.f°C",val),Utils.getFont("#3B5969FF",8))
                else
                    Utils.drawText(cr, 19+i*step,chart2Start + 95,string.format("%1.f°C",val),Utils.getFont("#3B5969FF",8))
                end
                if val2 >= 10 then
                    Utils.drawText(cr, 17+i*step,chart2Start + 105,string.format("(%1.f°C)",val2),Utils.getFont("#3B5969FF",7))
                else
                    Utils.drawText(cr, 20+i*step,chart2Start + 105,string.format("(%1.f°C)",val2),Utils.getFont("#3B5969FF",7))
                end
            end
        end
        Utils.drawLine(cr,375,chart2Start + 50,0,5)

    end
end

function WeeklyWeatherChartPanel:destroy()
    self.last_json = nil
    self.chart = nil
    self.forecast2_minmax = nil
    self.name = nil

    Chart.destroy(self)
end

return WeeklyWeatherChartPanel