
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
eu_frame_dir = os.getenv("HOME") .. "/.conky/weather-widget/eu_gif_frames/"
current_frame_index = 1
frames = {}
current_eu_frame_index = 1
eu_frames = {}
last_update = 0
last_json_update = 0
last_json = {}
currentWeatherInfoPanel = nil
dailyWeatherChartPanel = nil
weeklyWeatherChartPanel = nil
buttonDaily = nil
buttonWeekly = nil
buttonImageToggle = nil
buttonPausePlay = nil
buttonStop = nil
buttonSpeed = nil
progressBarImage = nil
imageCache = {}
currentRadarImage = 1
currentSatelliteImage = 1
cs = nil

showDaily = true
showWeekly = false
showRadarSatellite = false
playImage = true
stopImage = false
imageSpeed = 0.5

image_y = 265

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

function draw_satellite_image(cr,x,y,width,height)
    -- paint radar image if available
    if eu_frames and #eu_frames > 0 then
        if buttonPausePlay and buttonPausePlay.selected == false then
            current_eu_frame_index = (current_eu_frame_index + 1) % (((#eu_frames+1) / imageSpeed))
            if current_eu_frame_index == 0 then
                current_eu_frame_index = 1
            end
            currentSatelliteImage = math.max(1,math.floor(current_eu_frame_index * imageSpeed))
        end
        print("current frame: ",current_eu_frame_index,currentSatelliteImage,#eu_frames,eu_frames[currentSatelliteImage])
        
        progressBarImage.current_progress = currentSatelliteImage
        local current_frame = eu_frames[currentSatelliteImage]
        
        -- draw image border
        Utils.drawBox(cr,x-1,y-1,width+1,height+1)
        
        -- print("current: ",current_file)
        Utils.draw_scaled_image_surface(cr,current_frame,x,y,width,height)
        
        
        --local weatherDate = last_json.current_condition[1].localObsDateTime
        Utils.drawText(cr, x, y + height + 20,"Last Update: " .. last_json_update .. "                                     Lat: " .. last_json.latitude .. ", Lon: " .. last_json.longitude)
    end
end

function draw_radar_image(cr,x,y,width,height)
    -- paint radar image if available
    if frames and #frames > 0 then
        if buttonPausePlay and buttonPausePlay.selected == false then
            current_frame_index = (current_frame_index + 1) % (((#frames+1) / imageSpeed))
            if current_frame_index == 0 then
                current_frame_index = 1
            end
            currentRadarImage = math.max(1,math.floor(current_frame_index * imageSpeed))
        end
        -- print("current frame: ",current_frame_index,#frames)
        
        progressBarImage.current_progress = currentRadarImage
        local current_frame = frames[currentRadarImage]
        
        
        -- print("current: ",current_file)
        Utils.draw_scaled_image_surface(cr,current_frame,x,y,width,height)
        
        -- draw image border
        Utils.drawBox(cr,x-1,y-1,width+1,height+1)
        
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
            image_y = image_y + dailyWeatherChartPanel.y_size + getPadding(true)
            weeklyWeatherChartPanel:update(last_json)
        else
            button.text = 'Show Daily'
            showDaily = false

            weeklyWeatherChartPanel.y_offset = weeklyWeatherChartPanel.y_offset - dailyWeatherChartPanel.y_size - getPadding(false) - 10
            image_y = image_y - dailyWeatherChartPanel.y_size - getPadding(true) - 5
            weeklyWeatherChartPanel:update(last_json)
        end
    end
    if button.name == "ButtonWeekly" then
        if button.selected then
            button.text = 'Hide Weekly'
            showWeekly = true
            image_y = image_y + weeklyWeatherChartPanel.y_size + getPadding(true)
            weeklyWeatherChartPanel:update(last_json)
        else
            button.text = 'Show Weekly' 
            showWeekly = false
            image_y = image_y - weeklyWeatherChartPanel.y_size - getPadding(true) - 5
            weeklyWeatherChartPanel:update(last_json)

        end
    end
end
function toggleRadarSat(button)
    -- print(button.text)
    --button.selected = not button.selected

    if button.name == "ButtonImageToggle" then
        showRadarSatellite = not showRadarSatellite
        if button.text == "Show Satellite" then
            button:set_text('Show Radar')
        else
            button:set_text('Show Satellite')
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
            playImage = false

        else
            button.text = '▮▮'
            button.text_x_offset = 0
            playImage = true

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
            -- print("Set stopImage to true")
            button.text = '■'
            stopImage = true
            if not buttonPausePlay.selected then
                toggleRadarPlay(buttonPausePlay)
            end
        else
            button.text = '■'
            stopImage = false
        end
    end
end

function toggleimageSpeed(button)
    -- print(button.text)

    if button.name == "ButtonSpeed" then
        if button.text == "x0,25" then
            button.text = 'x1,0'
            imageSpeed = 1.0
        elseif button.text == "x0,5" then
            button.text = 'x0,25'
            imageSpeed = 0.25
        elseif button.text == "x1,0" then
            button.text = 'x0,5'
            imageSpeed = 0.5
            -- print(button.text)
        end
    end
end

function setRadarProgress(button,x,y)
    -- print(button.name)

    if button.name == "progressBarImage" then
        local step = (button.x_size - 1)/(button.max_progress - 1)
        local nextIndex = math.floor(((x + (step/2) - button.x_offset))/step) + 1
        currentRadarImage = nextIndex
        progressBarImage.current_progress = currentRadarImage
        -- print(tostring(nextIndex))
        if buttonPausePlay.selected == false then
            toggleRadarPlay(buttonPausePlay)
        end

    end
end

function conky_startup_hook()
    print("init widget")
    -- wait a few seconds, till the first weatherinfo and sat/radar images are loaded by the script
    Utils.sleep(10.0)
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
        x_size = 70,
        y_size = 20,
        draw_border = true,
        name = 'ButtonDaily',
        text = 'Hide Daily',
        selected = true,
        onButtonClicked = toggleChart
    })
    buttonWeekly = Button:new({
        x_offset = 85,
        y_offset = 102,
        x_size = 85,
        y_size = 20,
        draw_border = true,
        name = 'ButtonWeekly',
        text = 'Show Weekly',
        onButtonClicked = toggleChart
    })
    buttonImageToggle = Button:new({
        x_offset = 175,
        y_offset = 102,
        x_size = 80,
        y_size = 20,
        draw_border = true,
        name = 'ButtonImageToggle',
        text = 'Show Satellite',
        onButtonClicked = toggleRadarSat
    })
    buttonStop = Button:new({
        x_offset = 260,
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
        x_offset = 275,
        y_offset = 102,
        x_size = 10,
        y_size = 20,
        name = 'ButtonPausePlay',
        text = '▮▮',
        text_y_offset = -1,
        useSelectedAsTextColor = true,
        onButtonClicked = toggleRadarPlay
    })
    progressBarImage = ProgressBar:new({
        x_offset = 290,
        y_offset = 102,
        x_size = 75,
        y_size = 20,
        name = 'progressBarImage',
        onProgressBarClicked = setRadarProgress
    })
    buttonSpeed = Button:new({
        x_offset = 370,
        y_offset = 102,
        x_size = 20,
        y_size = 20,
        name = 'ButtonSpeed',
        text = string.format("x%s",imageSpeed),
        onButtonClicked = toggleimageSpeed
    })
    init_done = true

    -- sync update rate with json/radar update rate
    local waitSecAfterJSONUpdate = 25
    last_update = tonumber(Utils.read_file(os.getenv("HOME") .. "/.conky/weather-widget/last_update.txt")) + waitSecAfterJSONUpdate
    update()
end

function conky_shutdown_hook()
    print("shutdown")
end

function update_radar_frames()
    print("Update Radar Frames")
    -- Get all radar frame files sorted by timestamp
    local frame_files = Utils.scandir(frame_dir)
    table.sort(frame_files)  -- ensure chronological order
    
    -- First-time load: populate frames table completely
    if #frames == 0 then
        for i, frame_path in ipairs(frame_files) do
            local image = cairo_image_surface_create_from_png(frame_dir .. frame_path)
            image.file_name = frame_path
            table.insert(frames, image)
        end
    else
        -- Subsequent updates: check if new frame(s) exist
        local last_frame_file = frames[#frames].file_name
        local new_files_start_index = nil
        
        for i, frame_path in ipairs(frame_files) do
            if frame_path == last_frame_file then
                new_files_start_index = i + 1
                break
            end
        end
        
        -- Load only new frames
        if new_files_start_index then
            for i = new_files_start_index, #frame_files do
                local frame_path = frame_files[i]
                local image = cairo_image_surface_create_from_png(frame_dir .. frame_path)
                image.file_name = frame_path
                table.insert(frames, image)
            end
        end

        -- Remove old frames if we exceed the intended max count
        while #frames > #frame_files do
            local old_frame = frames[1]
            cairo_surface_destroy(old_frame)
            table.remove(frames, 1)
        end
    end

    progressBarImage.max_progress = #frames
end

function update_satellite_frames()
    print("Update Satellite Frames")
    -- Get all satellite frame files sorted by timestamp
    local frame_files = Utils.scandir(eu_frame_dir)
    table.sort(frame_files)  -- ensure chronological order
    
    -- First-time load: populate eu_frames table completely
    if #eu_frames == 0 then
        for i, frame_path in ipairs(frame_files) do
            print("adding frame ",eu_frame_dir .. frame_path)
            local image = cairo_image_surface_create_from_png(eu_frame_dir .. frame_path)
            image.file_name = frame_path
            table.insert(eu_frames, image)
        end
    else
        -- Subsequent updates: check if new frame(s) exist
        local last_frame_file = eu_frames[#eu_frames].file_name
        local new_files_start_index = 1
        
        for i, frame_path in ipairs(frame_files) do
            if frame_path == last_frame_file then
                new_files_start_index = i + 1
                break
            end
        end
        
        -- Load only new eu_frames
        if new_files_start_index then
            for i = new_files_start_index, #frame_files do
                local frame_path = frame_files[i]
                print("adding frame2 ",eu_frame_dir .. frame_path)
                local image = cairo_image_surface_create_from_png(eu_frame_dir .. frame_path)
                image.file_name = frame_path
                table.insert(eu_frames, image)
            end
        end

        -- Remove old eu_frames if we exceed the intended max count
        while #eu_frames > #frame_files do
            local old_frame = eu_frames[1]
            cairo_surface_destroy(old_frame)
            table.remove(eu_frames, 1)
        end
    end

    progressBarImage.max_progress = #eu_frames
end

-- Update chart data from JSON file
function update()
    print("Update")

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
    update_satellite_frames()
    currentWeatherInfoPanel:update(last_json,last_update)
end

function conky_weather_widget_mouse_hook(event)
    -- print(" type " .. event.type)
    lastMouseEvent = event

    if init_done == true then
        if showDaily then
            dailyWeatherChartPanel:updateMouseEvent(lastMouseEvent) 
        end
        if showWeekly then
            weeklyWeatherChartPanel:updateMouseEvent(lastMouseEvent) 
        end
        buttonDaily:updateMouseEvent(lastMouseEvent) 
        buttonWeekly:updateMouseEvent(lastMouseEvent)
        buttonImageToggle:updateMouseEvent(lastMouseEvent)
        buttonPausePlay:updateMouseEvent(lastMouseEvent)
        buttonStop:updateMouseEvent(lastMouseEvent)
        progressBarImage:updateMouseEvent(lastMouseEvent)
        buttonSpeed:updateMouseEvent(lastMouseEvent)
    end
    return false
end

function conky_draw_weather_widget()

    if init_done then
        if conky_window == nil then return end
        
        cs = cairo_xlib_surface_create(
            conky_window.display,
            conky_window.drawable,
            conky_window.visual,
            conky_window.width,
            conky_window.height
        )

        local cr = cairo_create(cs)


        -- update data every 5mins
        local current_time = os.time()
        if current_time - last_update > 310 then
            last_update = last_update + 300
            update()
        end

        if last_json == nil then
            Utils.drawText(cr, 10,50,"Unable to fetch WeatherInfo from wttr.in!",Utils.getFont("#993737",14))
        else
            currentWeatherInfoPanel:draw(cr)
            buttonDaily:draw(cr)
            buttonWeekly:draw(cr)
            buttonImageToggle:draw(cr)
            buttonPausePlay:draw(cr)
            buttonStop:draw(cr)
            buttonSpeed:draw(cr)
            if showDaily then
                dailyWeatherChartPanel:draw(cr)
            end
            if showWeekly then
                weeklyWeatherChartPanel:draw(cr)
            end

            if stopImage == false then
                if showRadarSatellite == false then
                    progressBarImage.max_progress = #frames
                    draw_radar_image(cr,10,image_y,380,380)
                else
                    progressBarImage.max_progress = #eu_frames
                    draw_satellite_image(cr,10,image_y,380,380)
                end
            end
            progressBarImage:draw(cr)
        end

        cairo_destroy(cr)
        cairo_surface_destroy(cs)
    end
    
    -- collectgarbage("collect")
    -- print("Lua memory (KB):", collectgarbage("count"))
end