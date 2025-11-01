
package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local cairo = require 'cairo'
local Chart = require 'Chart'
local Utils  = require("Utils")

current_frame = 0
last_update = 0
last_json_update = 0
last_json = {}
my_charts = {}
imageCache = {}
forecast1_minmax = { min = 0, max = 100 }
forecast2_minmax = { min = 0, max = 100 }

function getImage(imagePath)
    local icon = imageCache[imagePath]
    if icon == nil then
        print('loading image: ' .. imagePath)
        local surface = cairo_image_surface_create_from_png(imagePath)
        imageCache[imagePath] = surface
        return surface
    else
        return icon
    end
end

function add_24_hours_forecast(hourly_tempC,hourly_perticipprob,hourly_humidity)

    local chart = Chart:new({
        x_offset = 25,
        y_offset = 110,
        x_size = 350,
        y_size = 50,
        border_type = "plot-both",
        show_time_indicator = false
    })

    chart.lines = {}
    local border_probs = chart:get_properties("#3B5969FF")
    -- Add border lines
    chart:add_borders(border_probs)

    local minmax = { min = 0, max = 100 }
    local scaling = chart:get_scaling(minmax, #hourly_perticipprob, 10)
    chart:add_scaled_series(hourly_humidity, chart:get_properties("#3B596988"), scaling)
    local probs = chart:get_properties("#88550066")
    chart:add_scaled_series(hourly_perticipprob, probs, scaling)

    local polyprops = {
        color = "#3B596988", thickness = 1, antialiasing = false,
        series_type = "polygon", fill = true, fill_color = "#3B596940"
    }
    local err = { initial_error = 0.75, absolute_error = 0.01, per_cent_error = 0.00025, props = polyprops }
    forecast1_minmax = chart:add_scaled_series_with_error(hourly_tempC, chart:get_properties("#75A5CDFF"), err)
    
    table.insert(my_charts,chart)
end

function add_7_days_forecast(hourly_tempC,hourly_perticipprob,hourly_humidity)

    local chart = Chart:new({
        x_offset = 25,
        y_offset = 250,
        x_size = 350,
        y_size = 50,
        border_type = "plot-both"
    })

    chart.lines = {}
    local border_probs = chart:get_properties("#3B5969FF")
    -- Add border lines
    chart:add_borders(border_probs)

    local minmax = { min = 0, max = 100 }
    local scaling = chart:get_scaling(minmax, #hourly_perticipprob, 10)
    chart:add_scaled_series(hourly_humidity, chart:get_properties("#3B596988"), scaling)
    local probs = chart:get_properties("#88550066")
    chart:add_scaled_series(hourly_perticipprob, probs, scaling)

    local polyprops = {
        color = "#3B596988", thickness = 1, antialiasing = false,
        series_type = "polygon", fill = true, fill_color = "#3B596940"
    }
    local err = { initial_error = 1.0, absolute_error = 0.02, per_cent_error = 0.0005, props = polyprops }
    forecast2_minmax = chart:add_scaled_series_with_error(hourly_tempC, chart:get_properties("#75A5CDFF"), err)
    
    table.insert(my_charts,chart)
end

function draw_radar_image(cr,x,y,width,height)
    -- paint radar image if available
    local frame_dir = os.getenv("HOME") .. "/.conky/weather-widget/gif_frames/"
    local frames = Utils.scandir(frame_dir)
    if #frames > 0 then
        current_frame = (current_frame + 1) % (#frames+1)
        if current_frame == 0 then
            current_frame = 1
        end
        -- print("current frame: ",current_frame,#frames)
        
        local current_file = frame_dir .. frames[current_frame]
        
        
        -- print("current: ",current_file)
        Utils.draw_scaled_image(cr,current_file,x,y,width,height)
        
        -- draw image border
        Utils.drawBox(cr,x,y,width,height)
        
        --draw detailview border
        r, g, b, a = Utils.hex2rgb("#3B596988")
        cairo_set_source_rgba(cr, r, g, b, a)
        cairo_move_to(cr, x+142,y)
        cairo_line_to(cr, x+142,y+142)
        cairo_line_to(cr, x,y+142)
        cairo_stroke(cr)
        
        local target_x = %YOUR_HOME_X% + x
        local target_y = %YOUR_HOME_Y% + y
        local target2_x = 71 + x
        local target2_y = 71 + y
        -- draw target indicator at YOUR_HOME_X / YOUR_HOME_Y of the image
        local lineProps = Utils.getLineProps("#BB596988")
        Utils.drawBox(cr,target_x-8,target_y-8,15,15,lineProps)
        
        Utils.drawLine(cr,target_x,target_y+5,0,9,lineProps)
        Utils.drawLine(cr,target_x,target_y-5,0,-9,lineProps)
        Utils.drawLine(cr,target_x+5,target_y,9,0,lineProps)
        Utils.drawLine(cr,target_x-5,target_y,-9,0,lineProps)
        
        -- draw detail indicator at YOUR_HOME_X / YOUR_HOME_Y of the image
        local lineProps2 = Utils.getLineProps("#BB596930")
        Utils.drawBox(cr,target2_x-15,target2_y-15,29,29,lineProps2)
        
        Utils.drawLine(cr,target2_x,target2_y+10,0,60,lineProps2)
        Utils.drawLine(cr,target2_x,target2_y-10,0,-60,lineProps2)
        Utils.drawLine(cr,target2_x+10,target2_y,60,0,lineProps2)
        Utils.drawLine(cr,target2_x-10,target2_y,-60,0,lineProps2)
        
        --local weatherDate = last_json.current_condition[1].localObsDateTime
        Utils.drawText(cr, x, y + height + 20,"Last Update: " .. last_json_update .. "                                      Lat: " .. last_json.latitude .. ", Lon: " .. last_json.longitude)
        --Utils.drawText(cr, x, y + height + 32,"Last Querry:  " .. last_json_update)
    end
end

-- Update chart data from JSON file
function update()
    for _, chart in ipairs(my_charts) do
        if chart.destroy then chart:destroy() end  -- custom method if Chart supports it
    end
    my_charts = {}
    
    local json_text = Utils.read_file(os.getenv("HOME") .. "/.conky/weather-widget/weatherinfo.json")
    if not json_text or json_text == "" then
        print("Error: weatherinfo.json is empty or missing.")
        return
    end
    last_json_update = os.date("%Y-%m-%d %H:%M", tonumber(Utils.read_file(os.getenv("HOME") .. "/.conky/weather-widget/last_update.txt")))

    local ok, obj_or_err = pcall(json.decode, json_text)
    if not ok then
        print("Error decoding JSON:", obj_or_err)
        return
    end
    
    last_json = obj_or_err

    probs = {}
    for i=1,#last_json.minutely_15.time,1 do
        for j=1,#last_json.hourly.time,1 do
            if last_json.minutely_15.time[i]==last_json.hourly.time[j] then
                --print(last_json.hourly.time[j] .. ": " .. last_json.hourly.precipitation_probability[j])
                table.insert(probs,last_json.hourly.precipitation_probability[j])
                break
            end
        end
    end

    local temps=Utils.split_table(last_json.hourly.temperature_2m,24)
    local perticipprobs=Utils.split_table(last_json.hourly.precipitation_probability,24)
    local humidities=Utils.split_table(last_json.hourly.relative_humidity_2m,24)
    
    add_24_hours_forecast(last_json.minutely_15.temperature_2m,probs,last_json.minutely_15.relative_humidity_2m)
    add_7_days_forecast(temps.right,perticipprobs.right,humidities.right)
end

function conky_draw_weather_widget()
    if conky_window == nil then return end
    
    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    -- update data every 5mins
    local current_time = os.time()
    if current_time - last_update > 300 then
        last_update = current_time
        update()
    end

    if last_json == nil then
        Utils.drawText(cr, 10,50,"Unable to fetch WeatherInfo from wttr.in!",Utils.getFont("#993737",14))
    else
        for _,chart in ipairs(my_charts) do
            chart:draw_chart(cr) 
        end

        local current_condition = last_json.current
        local hour_now = tonumber(os.date("%H"))
        local hour_now_index = math.floor((hour_now)+1)

        local sunrise_ts = Utils.getDateFromDateTime(last_json.daily.sunrise[1],current_time)
        local sunset_ts = Utils.getDateFromDateTime(last_json.daily.sunrise[1],current_time)
        local is_day = sunrise_ts < current_time and current_time < sunset_ts
        local dayNightString = "d"
        if not is_day then
            dayNightString = "n"
        end
        
        Utils.draw_scaled_image_surface(cr,getImage(Utils.getWMOIconPath(current_condition.weather_code,dayNightString .. "_t@2x-blue")),-5,15,100,100)
        Utils.drawText(cr, 90,50,Utils.getDescriptionFromWMOIconCode(current_condition.weather_code),Utils.getFont("#3B5969FF",14))
        Utils.drawText(cr, 90,65,"Temp: " .. current_condition.temperature_2m .. "°C (" .. last_json.hourly.apparent_temperature[hour_now_index] .. "°C)")
        Utils.drawText(cr, 90,80,"Wolken: " .. current_condition.cloud_cover .. "%")
        local chanceOfPrecipitation = tonumber(last_json.hourly.precipitation_probability[hour_now_index])
        Utils.drawText(cr, 90,95,"Niederschlag: " .. chanceOfPrecipitation .. "%")

        Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/sun/sunrise_blue1.png"),232,32,26,26)
        Utils.drawText(cr, 268,50,Utils.splitString(last_json.daily.sunrise[1],"T")[2])
        Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/sun/sunset_blue1.png"),318,31,26,26)
        Utils.drawText(cr, 350,50,Utils.splitString(last_json.daily.sunset[1],"T")[2])
        Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/arrow/cardinal-points_clean_blue.png"),226,60,38,38)
        winddirDegreeMod=(current_condition.wind_direction_10m % 45)
        winddirDegreeMod=math.floor(current_condition.wind_direction_10m - winddirDegreeMod)
        Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/arrow/arrow_blue2-" .. winddirDegreeMod .. ".png"),227,61,38,38)

        Utils.drawText(cr, 268,75,"Wind: " .. current_condition.wind_direction_10m .. "°, " .. current_condition.wind_speed_10m .."km/h")
        Utils.drawText(cr, 268,90,"Luftf.: " .. current_condition.relative_humidity_2m .. "% Druck: " .. current_condition.surface_pressure .."hPa")
        

        local chart1Start = 110
        Utils.drawText(cr, 0,chart1Start + 10,string.format("%.0f°C",forecast1_minmax.max))
        Utils.drawText(cr, 380,chart1Start + 10,string.format("%.0f°C",forecast1_minmax.max))
        Utils.drawText(cr, 0,chart1Start + 50,string.format("%.0f°C",forecast1_minmax.min))
        Utils.drawText(cr, 380,chart1Start + 50,string.format("%.0f°C",forecast1_minmax.min))

        local step = 350/95
        local found_first = false
        local mod = 0
        for i=0,95,1 do
            local hourIndex = 0
            for j=1,#last_json.hourly.time+1,1 do
                if last_json.minutely_15.time[i+1]==last_json.hourly.time[j] then
                    hourIndex = j

                    Utils.drawLine(cr,25+i*step,chart1Start + 50,0,5)

                    if hourIndex%2 == 0 then
                        local hour_then = hourIndex % 24

                        is_day = last_json.minutely_15.is_day[i+1] == 1
                        dayNightString = "d"
                        if not is_day then
                            dayNightString = "n"
                        end

                        local imagePath = Utils.getWMOIconPath(last_json.minutely_15.weather_code[i+1],dayNightString .. "_t@1x-blue")
                        local image = getImage(imagePath)
                        Utils.draw_scaled_image_surface(cr,image,6+i*step,2+chart1Start + 60,38,38)

                        -- print(hour_then .. " " .. last_json.minutely_15.time[val+1] .. " " .. last_json.hourly.time[hour_then+1])

                        if hour_then > 10 then
                            Utils.drawText(cr, 15+i*step,chart1Start + 65,string.format("%dh",hour_then))
                        else
                            Utils.drawText(cr, 18+i*step,chart1Start + 65,string.format("%dh",hour_then))
                        end

                        local val = tonumber(last_json.minutely_15.temperature_2m[i+1])
                        local val2 = tonumber(last_json.hourly.apparent_temperature[hourIndex])
                        if val >= 10 then
                            Utils.drawText(cr, 13+i*step,chart1Start + 112,string.format("%1.f°C",val))
                        else
                            Utils.drawText(cr, 16+i*step,chart1Start + 112,string.format("%1.f°C",val))
                        end
                        if val2 >= 10 then
                            Utils.drawText(cr, 13+i*step,chart1Start + 125,string.format("(%1.f°C)",val2),Utils.getFont("#3B5969FF",8))
                        else
                            Utils.drawText(cr, 16+i*step,chart1Start + 125,string.format("(%1.f°C)",val2),Utils.getFont("#3B5969FF",8))
                        end
                    end
                    break
                end
            end

        end

        local chart2Start = 250
        Utils.drawText(cr, 0,chart2Start + 10,string.format("%.0f°C",forecast2_minmax.max))
        Utils.drawText(cr, 380,chart2Start + 10,string.format("%.0f°C",forecast2_minmax.max))
        Utils.drawText(cr, 0,chart2Start + 50,string.format("%.0f°C",forecast2_minmax.min))
        Utils.drawText(cr, 380,chart2Start + 50,string.format("%.0f°C",forecast2_minmax.min))


        step = 350/143
        for i=0,143,1 do
            if i%24==0 then
                Utils.drawLine(cr,25+i*step,chart2Start + 50,0,5)
            end
            if i%12==0 and not (i%24==0) then
                local dayOfWeekString = Utils.getDayOfWeekStringShort(os.date("%w",Utils.getDateFromDateTime(last_json.hourly.time[i+25])))
                Utils.drawText(cr, 20+i*step,chart2Start + 65,dayOfWeekString)
                --Utils.drawText(cr, 200,chart2Start + 65,"|")
                
                is_day = last_json.hourly.is_day[i+25] == 1
                dayNightString = "d"
                if not is_day then
                    dayNightString = "n"
                end

                local imagePath = Utils.getWMOIconPath(last_json.hourly.weather_code[i+25],dayNightString .. "_t@0.5x-blue")
                local image = getImage(imagePath)
                Utils.draw_scaled_image_surface(cr,image,14+i*step,chart2Start + 63,25,25)

                local val = tonumber(last_json.hourly.temperature_2m[i+25])
                local val2 = tonumber(last_json.hourly.apparent_temperature[i+25])
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

    draw_radar_image(cr,10,365,380,380)


    cairo_surface_destroy(cs)
    cairo_destroy(cr)
end

