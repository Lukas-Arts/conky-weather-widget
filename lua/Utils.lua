-- ~/.conky/weather-widget/lua/Utils.lua
local Utils = {}
Utils.__index = Utils

-- time as a timestamp in the format %h:%M %p format, and now in unix seconds
function Utils.getDateFromTime(time,baseTimeString)
    local baseDate = os.date('*t',baseTimeString)
    local timeDate = Utils.copyTable(baseDate)
    
    local hours, minutes, amPm = time:match("^(%d%d):(%d%d) ([AP]M)$")
    if not hours then
        error('could not parse time "' .. time .. '"')
    end
    if amPm == 'PM' then
        hours = string.format('%2d', tonumber(hours) + 12)
    end
    timeDate.hour = hours
    timeDate.min = minutes
    
    local convertedTimestamp = os.time(timeDate)
    return convertedTimestamp
end

-- time as a timestamp in the format %Y-%m-%dT%h:%M format, and now in unix seconds
function Utils.getDateFromDateTime(time,baseTimeString)
    local baseDate = os.date('*t',baseTimeString)
    local timeDate = Utils.copyTable(baseDate)
    
    local years, months, days, hours, minutes = time:match("^(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d)$")
    if not hours then
        error('could not parse time "' .. time .. '"')
    end
    timeDate.year = years
    timeDate.month = months
    timeDate.day = days
    timeDate.yday = nil
    timeDate.wday = nil
    timeDate.hour = hours
    timeDate.min = minutes
    
    local convertedTimestamp = os.time(timeDate)
    return convertedTimestamp
end

function Utils.getDayOfWeekString(dayOfWeek)
    local dayOfWeekStrings = {
        [1] = "Sonntag",
        [2] = "Montag",
        [3] = "Dienstag",
        [4] = "Mittwoch",
        [5] = "Donnerstag",
        [6] = "Freitag",
        [7] = "Samstag",
    }
    return dayOfWeekStrings[dayOfWeek+1]
end

function Utils.getDayOfWeekStringShort(dayOfWeek)
    local dayOfWeekStrings = {
        [1] = "So",
        [2] = "Mo",
        [3] = "Di",
        [4] = "Mi",
        [5] = "Do",
        [6] = "Fr",
        [7] = "Sa",
    }
    return dayOfWeekStrings[dayOfWeek+1]
end

-- Convert #AARRGGBB to rgba
function Utils.hex2rgb(hex)
    hex = hex:gsub("#","")
    local r = tonumber("0x"..hex:sub(1,2)) / 255
    local g = tonumber("0x"..hex:sub(3,4)) / 255
    local b = tonumber("0x"..hex:sub(5,6)) / 255
    local a = tonumber("0x"..(hex:sub(7,8) or "FF")) / 255
    return r, g, b, a
end

function Utils.getFont(colorHex,size,fontName,weight,slant)
    local font = { colorHex = colorHex or "#3B5969FF", size = size or 10, name = fontName or "Droid Sans", weight = weight or CAIRO_FONT_WEIGHT_NORMAL, slant = slant or CAIRO_FONT_SLANT_NORMAL }
    return font
end

-- x, y are the bottom left coordinates of the text
function Utils.drawText(cr,x,y,text,font)
    local font = font or Utils.getFont()
    r, g, b, a = Utils.hex2rgb(font.colorHex)
    cairo_set_source_rgba(cr, r, g, b, a)
    cairo_select_font_face(cr, font.name, font.slant, font.weight)
    cairo_set_font_size(cr, font.size)           -- font size
    cairo_move_to(cr, x, y)             -- x, y position
    cairo_show_text(cr, text)             -- draw it
    cairo_stroke(cr)
end

function Utils.getLineProps(colorHex,thickness,antialiasing)
    local lineProps = { colorHex = colorHex or "#3B5969FF", thickness = thickness or 1, antialiasing = antialiasing or false }
    return lineProps
end

function Utils.drawLine(cr,x,y,width,height,lineProps)
    local lineProps = lineProps or Utils.getLineProps()
    local r, g, b, a = Utils.hex2rgb(lineProps.colorHex)
    cairo_set_antialias(cr, lineProps.antialiasing)
    cairo_set_line_width(cr, lineProps.thickness)
    cairo_set_source_rgba(cr, r, g, b, a)
    cairo_move_to(cr, x,y)
    cairo_line_to(cr, x+width,y+height)
    cairo_stroke(cr)
end

function Utils.drawBox(cr,x,y,width,height,lineProps)
    local lineProps = lineProps or Utils.getLineProps()
    local r, g, b, a = Utils.hex2rgb(lineProps.colorHex)
    cairo_set_source_rgba(cr, r, g, b, a)
    cairo_set_antialias(cr, lineProps.antialiasing)
    cairo_set_line_width(cr, lineProps.thickness)
    cairo_move_to(cr, x,y)
    cairo_line_to(cr, x+width+1,y)
    cairo_line_to(cr, x+width+1,y+height+1)
    cairo_line_to(cr, x,y+height+1)
    cairo_close_path(cr)
    cairo_stroke(cr)
end

function Utils.draw_scaled_image_surface(cr, image_surface, x, y, w, h)

    local img_w = cairo_image_surface_get_width(image_surface)
    local img_h = cairo_image_surface_get_height(image_surface)

    local pattern = cairo_pattern_create_for_surface(image_surface)
    local matrix = cairo_matrix_t:create()
    cairo_matrix_init_scale(matrix, img_w / w, img_h / h)
    cairo_matrix_translate(matrix, -x, -y)
    cairo_pattern_set_matrix(pattern, matrix)
    cairo_set_source(cr, pattern)
    cairo_rectangle(cr, x, y, w, h)
    cairo_fill(cr)
    cairo_pattern_destroy(pattern)
end

function Utils.draw_scaled_image(cr, image_file_path, x, y, w, h)

    local image = cairo_image_surface_create_from_png(image_file_path)
    Utils.draw_scaled_image_surface(cr,image,x,y,w,h)
    cairo_surface_destroy(image)
end

-- Lua implementation of PHP scandir function
function Utils.scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls -a "'..directory..'"')
    for filename in pfile:lines() do
        if not (filename=='.' or filename=='..') then
            i = i + 1
            t[i] = filename
        end
    end
    pfile:close()
    return t
end

-- function to preload all icons
-- iconList is a table of {iconCode = "path/to/icon.png"}
function Utils.loadIcons(iconList,iconCache)
    for iconCode, filePath in pairs(iconList) do
        -- load the PNG into a cairo image surface
        local surface = cairo_image_surface_create_from_png(filePath)
        -- store it in the cache
        iconCache[iconCode] = surface
    end
end

function Utils.getWeatherIconPath(iconCode,icon_suffix)
    local fileName = Utils.getOpenWeatherMapIconCodeFromWorldWeatherOnlineIconCode(iconCode) .. icon_suffix .. ".png"
    return os.getenv("HOME") .. "/.conky/weather-widget/icons/owm-icons-blue/" .. fileName
end

function Utils.getWMOIconPath(iconCode,icon_suffix)
    local fileName = Utils.getOpenWeatherMapIconCodeFromWMOIconCode(iconCode) .. icon_suffix .. ".png"
    return os.getenv("HOME") .. "/.conky/weather-widget/icons/owm-icons-blue/" .. fileName
end

function Utils.getOpenWeatherMapIconCodeFromWMOIconCode(iconCode)
    local weatherIcons = {
        [0] = "01",
        [1] = "02",
        [2] = "03",
        [3] = "04",
        [45] = "50",
        [48] = "50",
        [51] = "10",
        [53] = "10",
        [55] = "10",
        [56] = "10",
        [57] = "10",
        [61] = "09",
        [63] = "09",
        [65] = "09",
        [66] = "09",
        [67] = "09",
        [71] = "10",
        [73] = "09",
        [75] = "09",
        [77] = "09",
        [80] = "09",
        [81] = "09",
        [82] = "09",
        [85] = "10",
        [86] = "09",
        [95] = "11",
        [96] = "11",
        [99] = "11"
    }
    return weatherIcons[iconCode]
end

function Utils.getOpenWeatherMapIconCodeFromWorldWeatherOnlineIconCode(iconCode)
    local weatherIcons = {
        ["113"] = "01",
        ["116"] = "02",
        ["119"] = "03",
        ["122"] = "04",
        ["143"] = "50",
        ["176"] = "10",
        ["179"] = "10",
        ["182"] = "10",
        ["185"] = "10",
        ["200"] = "11",
        ["227"] = "09",
        ["230"] = "09",
        ["248"] = "50",
        ["260"] = "50",
        ["263"] = "09",
        ["266"] = "09",
        ["281"] = "09",
        ["284"] = "09",
        ["293"] = "10",
        ["296"] = "10",
        ["299"] = "10",
        ["302"] = "09",
        ["305"] = "09",
        ["308"] = "09",
        ["311"] = "09",
        ["314"] = "09",
        ["317"] = "10",
        ["320"] = "09",
        ["323"] = "10",
        ["326"] = "10",
        ["329"] = "10",
        ["332"] = "09",
        ["335"] = "09",
        ["338"] = "09",
        ["350"] = "09",
        ["353"] = "10",
        ["356"] = "10",
        ["359"] = "10",
        ["362"] = "10",
        ["365"] = "09",
        ["368"] = "10",
        ["371"] = "09",
        ["374"] = "09",
        ["377"] = "10",
        ["386"] = "11",
        ["389"] = "11",
        ["392"] = "11",
        ["395"] = "09"
    }
    return weatherIcons[iconCode]
end

function Utils.getDescriptionFromWMOIconCode(iconCode)
    local weatherIcons = {
        [0] = "Klar",
        [1] = "Leicht Bewölkt",
        [2] = "Bewölkt",
        [3] = "Stark Bewölkt",
        [45] = "Nebelig",
        [48] = "Reifnebel",
        [51] = "Leichter Nieselregen",
        [53] = "Nieselregen",
        [55] = "Starker Nieselregen",
        [56] = "Gefrierender Nieselregen",
        [57] = "Frierender Nieselregen",
        [61] = "Leichter Regen",
        [63] = "Regen",
        [65] = "Starker Regen",
        [66] = "Gefrierender Regen",
        [67] = "Frierender Regen",
        [71] = "Leichter Schnee",
        [73] = "Schnee",
        [75] = "Starker Schnee",
        [77] = "Schneehagel",
        [80] = "Leichter Regenschauer",
        [81] = "Regenschauer",
        [82] = "Starker Regenschauer",
        [85] = "Leichter Schneeschauer",
        [86] = "Schneeschauer",
        [95] = "Gewitter",
        [96] = "Leichtes Hagelgewitter",
        [99] = "Hagelgewitter"
    }
    return weatherIcons[iconCode]
end

function Utils.printTableKeys(t)
    for k,v in pairs(t) do
        print(k)
    end
end

function Utils.printTableKeyValues(t)
    for k,v in pairs(t) do
        print(k .. ": " .. tostring(v))
    end
end

function Utils.copyTable(t)
    local t2 = {}
    for k,v in pairs(t) do
        t2[k] = v
    end
    return t2
end

function Utils.split_table(t, index)
    local left = { table.unpack(t, 1, index) }
    local right = { select(index + 1, table.unpack(t)) }
    return { left = left, right = right }
end

-- Read a file fully
function Utils.read_file(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

-- define a function to spring a string with give separator
function Utils.splitString(inputstr, sep)
   -- if sep is null, set it as space
   if sep == nil then
      sep = '%s'
   end
   -- define an array
   local t={}
   -- split string based on sep   
   for str in string.gmatch(inputstr, '([^'..sep..']+)') 
   do
      -- insert the substring in table
      table.insert(t, str)
   end
   -- return the array
   return t
end

return Utils