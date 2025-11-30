package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local Class = require("Class")
local Panel = require("Panel")
local Chart = require('Chart')
local Utils  = require("Utils")

-- Define the DailyWeatherChartPanel "class"
local DailyWeatherChartPanel = Class.new(Panel)  -- inherits Panel

-- Constructor
function DailyWeatherChartPanel:new(config)
    -- First call Panel constructor
    local self = DailyWeatherChartPanel.super.new(self, config) -- call Panel:new
    
    self.last_json = nil
    self.chart = nil
    self.forecast1_minmax = { min = 0, max = 100 }
    self.name = 'DailyWeatherChartPanel'

    self.font1 = Utils.getFont("#3B5969FF",8)

    return self
end

-- Update chart data from JSON file
function DailyWeatherChartPanel:update(last_json)
    if self.chart then
        self:remove_panel(self.chart)
        self.chart:destroy()
        self.chart = nil
    end
    self.last_json = last_json

    local probs = {}
    for i=1,#last_json.minutely_15.time,1 do
        for j=1,#last_json.hourly.time,1 do
            if last_json.minutely_15.time[i]==last_json.hourly.time[j] then
                --print(last_json.hourly.time[j] .. ": " .. last_json.hourly.precipitation_probability[j])
                table.insert(probs,last_json.hourly.precipitation_probability[j])
                break
            end
        end
    end
    
    self.chart = self:add_24_hours_forecast(last_json.minutely_15.temperature_2m,probs,last_json.minutely_15.relative_humidity_2m)
    self:add_panel(self.chart)
end

function DailyWeatherChartPanel:add_24_hours_forecast(hourly_tempC,hourly_perticipprob,hourly_humidity)

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
    local err = { initial_error = 0.75, absolute_error = 0.01, per_cent_error = 0.00025, props = polyprops }
    self.forecast1_minmax = chart:add_scaled_series_with_error(hourly_tempC, chart:get_properties("#75A5CDFF"), err)
    
    return chart
end

-- Draw DailyWeatherChartPanel using cairo
function DailyWeatherChartPanel:draw_content(cr)
    DailyWeatherChartPanel.super.draw_content(self,cr)

    if self.last_json then
        
        local chart1Start = self.y_offset
        Utils.drawText(cr, 0,chart1Start + 10,string.format("%.0f°C",self.forecast1_minmax.max))
        Utils.drawText(cr, 380,chart1Start + 10,string.format("%.0f°C",self.forecast1_minmax.max))
        Utils.drawText(cr, 0,chart1Start + 50,string.format("%.0f°C",self.forecast1_minmax.min))
        Utils.drawText(cr, 380,chart1Start + 50,string.format("%.0f°C",self.forecast1_minmax.min))

        local step = 350/95
        local found_first = false
        local mod = 0
        for i=0,95,1 do
            local hourIndex = 0
            local minutelyIndex = i+1
            local cStep = i*step
            for j=1,#self.last_json.hourly.time+1,1 do
                if self.last_json.minutely_15.time[minutelyIndex]==self.last_json.hourly.time[j] then
                    hourIndex = j

                    Utils.drawLine(cr,25+cStep,chart1Start + 50,0,hourIndex%2 == 1 and 5 or 3)

                    if hourIndex%2 == 1 then
                        local hour_then = hourIndex % 24

                        local is_day = self.last_json.minutely_15.is_day[minutelyIndex] == 1
                        local dayNightString = "d"
                        if not is_day then
                            dayNightString = "n"
                        end
                        
                        if hour_then > 10 then
                            Utils.drawText(cr, 15+cStep,chart1Start + 65,string.format("%dh",hour_then))
                        else
                            Utils.drawText(cr, 18+cStep,chart1Start + 65,string.format("%dh",hour_then))
                        end

                        local imagePath = Utils.getWMOIconPath(self.last_json.minutely_15.weather_code[minutelyIndex],dayNightString .. "_t@1x-blue")
                        local image = getImage(imagePath)
                        Utils.draw_scaled_image_surface(cr,image,6+cStep,2+chart1Start + 60,38,38)


                        local val = tonumber(self.last_json.minutely_15.temperature_2m[minutelyIndex])
                        local val2 = tonumber(self.last_json.hourly.apparent_temperature[hourIndex])
                        if val >= 10 then
                            Utils.drawText(cr, 13+cStep,chart1Start + 107,string.format("%1.f°C",val))
                        else
                            Utils.drawText(cr, 16+cStep,chart1Start + 107,string.format("%1.f°C",val))
                        end
                        if val2 >= 10 then
                            Utils.drawText(cr, 13+cStep,chart1Start + 120,string.format("(%1.f°C)",val2),self.font1)
                        else
                            Utils.drawText(cr, 16+cStep,chart1Start + 120,string.format("(%1.f°C)",val2),self.font1)
                        end
                    end
                    break
                end
            end

        end

    end
end

function DailyWeatherChartPanel:destroy()

    if self.chart then
        self:remove_panel(self.chart)
        self.chart:destroy()
    end
    
    self.last_json = nil

    self.font1 = nil
    self.chart = nil
    self.forecast1_minmax = nil
    self.name = nil

    Panel.destroy(self)
end

return DailyWeatherChartPanel