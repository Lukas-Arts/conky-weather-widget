
package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local json  = require("json")
local cairo = require 'cairo'
local Chart = require 'Chart'
local Button = require('Button')
local ProgressBar = require('ProgressBar')
local DailyWeatherChartPanel = require('DailyWeatherChartPanel')
local WeeklyWeatherChartPanel = require('WeeklyWeatherChartPanel')
local Utils  = require("Utils")


frame_dir = os.getenv("HOME") .. "/.conky/weather-widget/gif_frames/"
current_frame_index = 1
frames = {}
last_update = 0
last_json_update = 0
last_json = {}
dailyWeatherChartPanel = nil
weeklyWeatherChartPanel = nil
buttonDaily = nil
buttonWeekly = nil
buttonPausePlay = nil
buttonStop = nil
buttonSpeed = nil
progressBarRadar = nil
imageCache = {}
currentRadarImage = 1

showDaily = true
showWeekly = false
playRadar = true
stopRadar = false
radarSpeed = 0.5

radar_y = 265

lastMouseEvent = nil
init_done = false

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


function draw_radar_image(cr,x,y,width,height)
    -- paint radar image if available
    if frames and #frames > 0 then
        if buttonPausePlay and buttonPausePlay.selected == false then
            current_frame_index = (current_frame_index + 1) % (((#frames+1) / radarSpeed))
            if current_frame_index == 0 then
                current_frame_index = 1
            end
            currentRadarImage = math.max(1,math.floor(current_frame_index * radarSpeed))
        end
        -- print("current frame: ",current_frame_index,#frames)
        
        progressBarRadar.current_progress = currentRadarImage
        local current_frame = frames[currentRadarImage]
        
        
        -- print("current: ",current_file)
        Utils.draw_scaled_image_surface(cr,current_frame,x,y,width,height)
        
        -- draw image border
        Utils.drawBox(cr,x,y,width,height)
        
        --draw detailview border
        local r, g, b, a = Utils.hex2rgb("#3B596988")
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
        Utils.drawText(cr, x, y + height + 20,"Last Update: " .. last_json_update .. "                                     Lat: " .. last_json.latitude .. ", Lon: " .. last_json.longitude)
        --Utils.drawText(cr, x, y + height + 32,"Last Querry:  " .. last_json_update)
    end
end

function getPadding(includeWeekly)
    local padding = 0
    if showDaily then
        padding = padding + 5
    end
    if includeWeekly and showWeekly then
        padding = padding + 5
    end
    return padding
end

function toggleChart(button)
    -- print(button.text)
    button.selected = not button.selected

    -- padding is weird
    if button.name == "ButtonDaily" then
        if button.selected then
            button.text = 'Hide Daily'
            showDaily = true

            weeklyWeatherChartPanel.y_offset = weeklyWeatherChartPanel.y_offset + dailyWeatherChartPanel.y_size + getPadding(false) + 5
            radar_y = radar_y + dailyWeatherChartPanel.y_size + getPadding(true)
            weeklyWeatherChartPanel:update(last_json)
        else
            button.text = 'Show Daily'
            showDaily = false

            weeklyWeatherChartPanel.y_offset = weeklyWeatherChartPanel.y_offset - dailyWeatherChartPanel.y_size - getPadding(false) - 10
            radar_y = radar_y - dailyWeatherChartPanel.y_size - getPadding(true) - 5
            weeklyWeatherChartPanel:update(last_json)
        end
    end
    if button.name == "ButtonWeekly" then
        if button.selected then
            button.text = 'Hide Weekly'
            showWeekly = true
            radar_y = radar_y + weeklyWeatherChartPanel.y_size + getPadding(true)
            weeklyWeatherChartPanel:update(last_json)
        else
            button.text = 'Show Weekly' 
            showWeekly = false
            radar_y = radar_y - weeklyWeatherChartPanel.y_size - getPadding(true) - 5
            weeklyWeatherChartPanel:update(last_json)

        end
    end
end
function toggleRadarPlay(button)
    -- print(button.text)
    button.selected = not button.selected

    if button.name == "ButtonPausePlay" then
        if button.selected then
            button.text = '▶'
            button.text_x_offset = 3
            playRadar = false

        else
            button.text = '▮▮'
            button.text_x_offset = 0
            playRadar = true

            if buttonStop.selected then
                toggleRadarStop(buttonStop)
            end
        end
    end
end
function toggleRadarStop(button)
    -- print(button.text)
    button.selected = not button.selected

    if button.name == "ButtonStop" then
        if button.selected then
            -- print("Set stopRadar to true")
            button.text = '■'
            stopRadar = true
            if not buttonPausePlay.selected then
                toggleRadarPlay(buttonPausePlay)
            end
        else
            button.text = '■'
            stopRadar = false
        end
    end
end
function toggleRadarSpeed(button)
    -- print(button.text)

    if button.name == "ButtonSpeed" then
        if button.text == "x0,25" then
            button.text = 'x1,0'
            radarSpeed = 1.0
        elseif button.text == "x0,5" then
            button.text = 'x0,25'
            radarSpeed = 0.25
        elseif button.text == "x1,0" then
            button.text = 'x0,5'
            radarSpeed = 0.5
            -- print(button.text)
        end
    end
end
function setRadarProgress(button,x,y)
    -- print(button.name)

    if button.name == "ProgressBarRadar" then
        local step = (button.x_size - 1)/(button.max_progress - 1)
        local nextIndex = math.floor(((x + (step/2) - button.x_offset))/step) + 1
        currentRadarImage = nextIndex
        progressBarRadar.current_progress = currentRadarImage
        -- print(tostring(nextIndex))
        if buttonPausePlay.selected == false then
            toggleRadarPlay(buttonPausePlay)
        end

    end
end

function init()
    print("init widget")
    dailyWeatherChartPanel = DailyWeatherChartPanel:new({
        x_offset = 0,
        y_offset = 132,
        x_size = 400,
        y_size = 121,
        -- background = '#FF0000FF'
    })
    weeklyWeatherChartPanel = WeeklyWeatherChartPanel:new({
        x_offset = 0,
        y_offset = 265,
        x_size = 400,
        y_size = 106,
        -- background = '#FFFF00FF'
    })
    buttonDaily = Button:new({
        x_offset = 10,
        y_offset = 102,
        x_size = 90,
        y_size = 20,
        draw_border = true,
        name = 'ButtonDaily',
        text = 'Show Daily',
        selected = true,
        onButtonClicked = toggleChart
    })
    buttonWeekly = Button:new({
        x_offset = 105,
        y_offset = 102,
        x_size = 90,
        y_size = 20,
        draw_border = true,
        name = 'ButtonWeekly',
        text = 'Show Weekly',
        onButtonClicked = toggleChart
    })
    buttonStop = Button:new({
        x_offset = 200,
        y_offset = 102,
        x_size = 10,
        y_size = 20,
        name = 'ButtonStop',
        text = '■',
        text_y_offset = -1,
        useSelectedAsTextColor = true,
        onButtonClicked = toggleRadarStop
    })
    buttonPausePlay = Button:new({
        x_offset = 215,
        y_offset = 102,
        x_size = 10,
        y_size = 20,
        name = 'ButtonPausePlay',
        text = '▮▮',
        text_y_offset = -1,
        useSelectedAsTextColor = true,
        onButtonClicked = toggleRadarPlay
    })
    progressBarRadar = ProgressBar:new({
        x_offset = 232,
        y_offset = 102,
        x_size = 130,
        y_size = 20,
        name = 'ProgressBarRadar',
        onProgressBarClicked = setRadarProgress
    })
    buttonSpeed = Button:new({
        x_offset = 370,
        y_offset = 102,
        x_size = 20,
        y_size = 20,
        name = 'ButtonSpeed',
        text = string.format("x%s",radarSpeed),
        onButtonClicked = toggleRadarSpeed
    })
    init_done = true
end

function update_radar_frames()
    print("Update Radar Frames")
    -- destroy old frame surfaces
    for i, frame in ipairs(frames) do
        cairo_surface_destroy(frame)
        frames[i] = nil
    end
    frames = {}  -- clear whole table


    -- load new frame surfaces
    local frame_files = Utils.scandir(frame_dir)
    for i, frame_path in ipairs(frame_files) do
        -- print(frame_path)
        local image = cairo_image_surface_create_from_png(frame_dir .. frame_path)
        table.insert(frames, image)
    end

    progressBarRadar.max_progress = #frames
end
-- Update chart data from JSON file
function update()
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

    dailyWeatherChartPanel:update(last_json)
    weeklyWeatherChartPanel:update(last_json)
end

function conky_weather_widget_mouse_hook(event)
    -- print(" type " .. event.type)
    lastMouseEvent = event

    if init_done == true then
        local evCopy = Utils.copy(lastMouseEvent,nil)
        dailyWeatherChartPanel:updateMouseEvent(evCopy) 
        local evCopy2 = Utils.copy(lastMouseEvent,nil)
        weeklyWeatherChartPanel:updateMouseEvent(evCopy2) 
        local evCopy3 = Utils.copy(lastMouseEvent,nil)
        buttonDaily:updateMouseEvent(evCopy3) 
        local evCopy4 = Utils.copy(lastMouseEvent,nil)
        buttonWeekly:updateMouseEvent(evCopy4)
        local evCopy5 = Utils.copy(lastMouseEvent,nil)
        buttonPausePlay:updateMouseEvent(evCopy5)
        local evCopy6 = Utils.copy(lastMouseEvent,nil)
        buttonStop:updateMouseEvent(evCopy6)
        local evCopy7 = Utils.copy(lastMouseEvent,nil)
        progressBarRadar:updateMouseEvent(evCopy7)
        local evCopy8 = Utils.copy(lastMouseEvent,nil)
        buttonSpeed:updateMouseEvent(evCopy8)
    end
    return false
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

    if init_done == false then
        init()
    end

    -- update data every 5mins
    local current_time = os.time()
    if current_time - last_update > 300 then
        last_update = current_time
        update()
        update_radar_frames()
    end

    if last_json == nil then
        Utils.drawText(cr, 10,50,"Unable to fetch WeatherInfo from wttr.in!",Utils.getFont("#993737",14))
    else
        buttonDaily:draw(cr)
        buttonWeekly:draw(cr)
        buttonPausePlay:draw(cr)
        buttonStop:draw(cr)
        buttonSpeed:draw(cr)
        if showDaily then
            dailyWeatherChartPanel:draw(cr)
        end
        if showWeekly then
            weeklyWeatherChartPanel:draw(cr)
        end

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
        local winddirDegreeMod=(current_condition.wind_direction_10m % 45)
        winddirDegreeMod=math.floor(current_condition.wind_direction_10m - winddirDegreeMod)
        Utils.draw_scaled_image_surface(cr,getImage(os.getenv("HOME") .. "/.conky/weather-widget/icons/arrow/arrow_blue2-" .. winddirDegreeMod .. ".png"),227,61,38,38)

        Utils.drawText(cr, 268,75,"Wind: " .. current_condition.wind_direction_10m .. "°, " .. current_condition.wind_speed_10m .."km/h")
        Utils.drawText(cr, 268,90,"Luftf.: " .. current_condition.relative_humidity_2m .. "% Druck: " .. current_condition.surface_pressure .."hPa")
    end

    if stopRadar == false then
        draw_radar_image(cr,10,radar_y,380,380)
    end
    progressBarRadar:draw(cr)

    cairo_surface_destroy(cs)
    cairo_destroy(cr)
end

