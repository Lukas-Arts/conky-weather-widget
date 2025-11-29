
package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local json  = require("json")
local cairo = require 'cairo'
local Chart = require 'Chart'
local Button = require('Button')
local ProgressBar = require('ProgressBar')
local DailyWeatherChartPanel = require('DailyWeatherChartPanel')
local WeeklyWeatherChartPanel = require('WeeklyWeatherChartPanel')
local CurrentWeatherInfoPanel = require('CurrentWeatherInfoPanel')
local Utils  = require("Utils")


frame_dir = os.getenv("HOME") .. "/.conky/weather-widget/gif_frames/"
current_frame_index = 1
frames = {}
last_update = 0
last_json_update = 0
last_json = {}
currentWeatherInfoPanel = nil
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

    currentWeatherInfoPanel = CurrentWeatherInfoPanel:new({
        x_offset = 0,
        y_offset = 28,
        x_size = 400,
        y_size = 100,
    })
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

    -- sync update rate with json/radar update rate
    local waitSecAfterJSONUpdate = 10
    last_update = tonumber(Utils.read_file(os.getenv("HOME") .. "/.conky/weather-widget/last_update.txt")) + waitSecAfterJSONUpdate
    update()
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

    local ok, obj_or_err = pcall(json.decode, json_text)
    if not ok then
        print("Error decoding JSON:", obj_or_err)
        return
    end
    
    last_json = obj_or_err

    last_json_update = os.date("%Y-%m-%d %H:%M", last_update)
    dailyWeatherChartPanel:update(last_json)
    weeklyWeatherChartPanel:update(last_json)
    update_radar_frames()
    currentWeatherInfoPanel:update(last_json,last_update)
end

function conky_weather_widget_mouse_hook(event)
    -- print(" type " .. event.type)
    lastMouseEvent = event

    if init_done == true then
        if showDaily then
            local evCopy = Utils.copy(lastMouseEvent,nil)
            dailyWeatherChartPanel:updateMouseEvent(evCopy) 
        end
        if showWeekly then
            local evCopy2 = Utils.copy(lastMouseEvent,nil)
            weeklyWeatherChartPanel:updateMouseEvent(evCopy2) 
        end
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
    end

    if last_json == nil then
        Utils.drawText(cr, 10,50,"Unable to fetch WeatherInfo from wttr.in!",Utils.getFont("#993737",14))
    else
        currentWeatherInfoPanel:draw(cr)
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
    end

    if stopRadar == false then
        draw_radar_image(cr,10,radar_y,380,380)
    end
    progressBarRadar:draw(cr)

    cairo_surface_destroy(cs)
    cairo_destroy(cr)
end

