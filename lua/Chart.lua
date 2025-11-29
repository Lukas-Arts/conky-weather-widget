package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local Class = require("Class")
local Panel = require("Panel")
local Utils  = require("Utils")

-- Define the Chart "class"
local Chart = Class.new(Panel)  -- inherits Panel

-- Constructor
function Chart:new(config)
    -- First call Panel constructor
    local self = Chart.super.new(self, config) -- call Panel:new
    
    self.show_time_indicator = config and config.show_time_indicator or false
    self.border_type = config and config.border_type or "plot-both"
    
    self.lines = {}
    self.name = config and config.name or 'Chart'

    self.buffered_chart_image = nil

    return self
end

-- Get a property table for a line or polygon
function Chart:get_properties(color, thick, antialiasing, series_type, fill, fill_color)
    return {
        color = color or "#FF0000FF",
        thickness = thick or 1,
        antialiasing = antialiasing or false,
        series_type = series_type or "line",
        fill = fill or false,
        fill_color = fill_color or color or "#FF000055",
        idicate_input = false,
        scale_props = { x_scale_factor = 1, y_scale_factor = 1, min = 0, max = 99999 }
    }
end

-- Create a new line in chart
function Chart:new_line(props)
    local line = { props = props or self:get_properties(), points = {} }
    table.insert(self.lines, line)
end

-- Add point to a specific line
function Chart:add_point(line_index, new_x, new_y)
    local line = self.lines[line_index]
    if not line then
        print("Warning: no line at index " .. tostring(line_index))
        return
    end
    local point = { x = new_x, y = new_y }
    table.insert(line.points, point)
end

-- Compute min and max of a numeric series
function Chart:get_min_max(series)
    local min, max = math.huge, -math.huge
    for _, v in ipairs(series) do
        if v < min then min = v end
        if v > max then max = v end
    end
    return { min = min, max = max }
end

-- Compute scaling factors for x/y
function Chart:get_scaling(minmax, x_length, min_y_diff)
    local diff = minmax.max - minmax.min
    local x_scale = (self.x_size / (x_length - 1))
    local y_scale = (self.y_size / math.max(min_y_diff, diff))
    if min_y_diff > diff then
        minmax.min = minmax.min - (min_y_diff - diff) / 2
    end
    return {
        x_scale_factor = x_scale,
        y_scale_factor = y_scale,
        min = minmax.min,
        max = minmax.max
    }
end

-- Add a scaled series
function Chart:add_scaled_series(series, props)
    props = props or self:get_properties()

    self:new_line(props)
    for i, v in ipairs(series) do
        self:add_point(#self.lines, (i - 1) * props.scale_props.x_scale_factor,
            (v - props.scale_props.min) * props.scale_props.y_scale_factor)
    end
end

-- Add scaled series with error shading
function Chart:add_scaled_series_with_error(series, props, error_settings)
    props = props or self:get_properties()
    error_settings = error_settings or {
        initial_error = 0, absolute_error = 0, per_cent_error = 0, props = self:get_properties()
    }

    -- create point for upper and lower error
    local upper, lower = {}, {}
    for i, y in ipairs(series) do
        table.insert(upper, y + error_settings.initial_error +
            (y * ((i - 1) * error_settings.per_cent_error)) +
            ((i - 1) * error_settings.absolute_error))
    end
    for i = #series, 1, -1 do
        local y = series[i]
        table.insert(lower, y - error_settings.initial_error -
            (y * ((i - 1) * error_settings.per_cent_error)) -
            ((i - 1) * error_settings.absolute_error))
    end

    -- get minmax and scaling based on upper and lower error
    local minmax = self:get_min_max(upper)
    local minmax2 = self:get_min_max(lower)
    local minmax3 = self:get_min_max(series)
    minmax3.min = math.min(minmax3.min, minmax2.min, minmax.min)
    minmax3.max = math.max(minmax3.max, minmax2.max, minmax.max)
    local scaling = self:get_scaling(minmax3, #series, 10)

    -- add baseline series
    props.idicate_input = true
    props.scale_props = scaling
    self:add_scaled_series(series, props)

    -- add error polygon
    local line = self.lines[#self.lines]
    local poly = { props = error_settings.props, points = {} }

    for j, p in ipairs(line.points) do
        local p2 = { x = p.x, y = (upper[j] - scaling.min) * scaling.y_scale_factor }
        table.insert(poly.points, p2)
    end
    for j = #line.points, 1, -1 do
        local p = line.points[j]
        local p2 = { x = p.x, y = (lower[#line.points - (j - 1)] - scaling.min) * scaling.y_scale_factor }
        table.insert(poly.points, p2)
    end
    table.insert(self.lines, poly)

    -- return calculated minmax error bounds
    return minmax3
end

function Chart:add_borders(border_props)

    if self.border_type == 'full' then
        self:new_line(border_props)
        self:add_point(#self.lines,1,0)
        self:add_point(#self.lines,self.x_size,0)
        self:add_point(#self.lines, self.x_size, self.y_size)
        self:add_point(#self.lines, 1, self.y_size)
        self:add_point(#self.lines, 1, 0)
    elseif self.border_type == 'top' then
        self:new_line(border_props)
        self:add_point(#self.lines,1,self.y_size)
        self:add_point(#self.lines,self.x_size,self.y_size)
    elseif self.border_type == 'bottom' then
        self:new_line(border_props)
        self:add_point(#self.lines,1,0)
        self:add_point(#self.lines,self.x_size,0)
    elseif self.border_type == 'plot' then
        self:new_line(border_props)
        self:add_point(#self.lines,1,self.y_size)
        self:add_point(#self.lines,1,0)
        self:add_point(#self.lines, self.x_size, 0)
    elseif self.border_type == 'plot-right' then
        self:new_line(border_props)
        self:add_point(#self.lines,1,0)
        self:add_point(#self.lines, self.x_size, 0)
        self:add_point(#self.lines,self.x_size,self.y_size)
    elseif self.border_type == 'plot-both' then
        self:new_line(border_props)
        self:add_point(#self.lines,1,self.y_size)
        self:add_point(#self.lines,1,0)
        self:add_point(#self.lines, self.x_size, 0)
        self:add_point(#self.lines,self.x_size,self.y_size)
    end
end

function Chart:draw_to_buffer()
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

    for _, line in ipairs(self.lines) do
        if #line.points > 0 then
            -- Set setting for next stroke
            if not line.props.antialiasing then
                cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
            else 
                cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
            end
            cairo_set_line_width(cr, line.props.thickness)
            local r, g, b, a = Utils.hex2rgb(line.props.color)
            cairo_set_source_rgba(cr, r, g, b, a)

            -- move to first point and draw line from there
            cairo_move_to(cr, line.points[1].x, self.y_size - line.points[1].y)
            for j = 2, #line.points do
                local p = line.points[j]
                cairo_line_to(cr, p.x, self.y_size - p.y)
            end
            if line.props.series_type == 'polygon' or line.props.series_type == 'line-bottom-fill' or line.props.series_type == 'line-top-fill' then
                if line.props.series_type == 'line-bottom-fill' then
                    cairo_line_to(cr,self.x_size, self.y_size)
                    cairo_line_to(cr,self.x_offset,self.y_size)
                elseif line.props.series_type == 'line-top-fill' then
                    cairo_line_to(cr,self.x_size, self.y_offset)
                    cairo_line_to(cr,self.x_offset,self.y_offset)
                end
                cairo_close_path(cr)
                cairo_stroke(cr)
                if line.props.fill then
                    r, g, b, a = Utils.hex2rgb(line.props.fill_color)
                    cairo_set_source_rgba(cr,r,g,b,a)
                    
                    cairo_move_to(cr,line.points[1].x, self.y_size - line.points[1].y)
                    for j = 2, #line.points do
                        local p = line.points[j]
                        cairo_line_to(cr,p.x, self.y_size - p.y)
                    end
                    if line.props.series_type == 'line-bottom-fill' then
                        
                        cairo_line_to(cr,self.x_size, self.y_size)
                        cairo_line_to(cr,self.x_offset,self.y_size)
                    elseif line.props.series_type == 'line-top-fill' then
                        cairo_line_to(cr,self.x_size, self.y_offset)
                        cairo_line_to(cr,self.x_offset,self.y_offset)
                    end
                    cairo_close_path(cr)
                    cairo_fill(cr)
                end
            end

            if line.props.series_type == "polygon" and line.props.fill then
                cairo_close_path(cr)
                local fr, fg, fb, fa = Utils.hex2rgb(line.props.fill_color)
                cairo_set_source_rgba(cr, fr, fg, fb, fa)
                cairo_fill(cr)
            end
            cairo_stroke(cr)
        end
    end
    cairo_destroy(cr)
end

function Chart:onMouseEvent(event)
    if self and event and event.type and event.type == "mouse_leave" then
        self.lastMouseEvent = nil
    end
end

-- Draw chart using cairo
function Chart:draw_content(cr)
    Chart.super.draw_content(self,cr)

    if self.buffered_chart_image == nil then
        self:draw_to_buffer()
    end
    if self.buffered_chart_image then
        cairo_set_source_surface(cr, self.buffered_chart_image, self.x_offset, self.y_offset)
        cairo_paint(cr)
    end

    if self.show_time_indicator then
        -- Set setting for next stroke
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_line_width(cr, 1)
        local r, g, b, a = Utils.hex2rgb("#CC0000CC")
        cairo_set_source_rgba(cr, r, g, b, a)
        
        local current_time = os.date("*t")
        local minutes = current_time.hour * 60 + current_time.min
        local minute_x = (self.x_size/1440)*minutes
        -- print("current minutes: ",minutes,minute_x)
        
        -- move to first point and draw line from there
        cairo_move_to(cr, minute_x + self.x_offset, self.y_size + self.y_offset)
        cairo_line_to(cr,minute_x + self.x_offset, self.y_offset)
        
        
        cairo_stroke(cr)
    end
    if self.lastMouseEvent then
        local y_mouse_override = 0
        local mouse_value = 0

        for _, line in ipairs(self.lines) do
            if #line.points > 0 then
                if line.props.idicate_input and self.lastMouseEvent then
                    -- print("Getting val for mouse Event")
                    local pindex = math.floor(((#line.points - 1) / self.x_size) * (self.lastMouseEvent.x - self.x_offset)) + 1
                    -- print(tostring(pindex))
                    local p = line.points[pindex]
                    y_mouse_override = self.y_size - p.y + self.y_offset
                    mouse_value = p.y / line.props.scale_props.y_scale_factor + line.props.scale_props.min
                end
            end
        end

        
        -- Set setting for next stroke
        
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_line_width(cr, 1.5)
        local r, g, b, a = Utils.hex2rgb("#75A5CDFF")
        cairo_set_source_rgba(cr, r, g, b, a)
        
        Utils.drawText(cr, self.lastMouseEvent.x - 10,y_mouse_override - 10, mouse_value .. "°C")
        
        local radius = 4
        -- Define the path for the circle
        cairo_arc(cr,self.lastMouseEvent.x, y_mouse_override, radius, 0, 2 * math.pi)

        -- Fill the circle with the current source pattern
        cairo_fill(cr)
        
        -- move to first point and draw line from there
        --cairo_move_to(cr, self.lastMouseEvent.x, self.y_size + self.y_offset)
        --cairo_line_to(cr,self.lastMouseEvent.x, self.y_offset)
        
        
        cairo_stroke(cr)
    end
end

function Chart:destroy()
    -- Clear all points and properties in each line
    if self.lines then
        for i, line in ipairs(self.lines) do
            if line.points then
                for j = 1, #line.points do
                    line.points[j] = nil
                end
            end
            line.points = nil
            line.props = nil
            self.lines[i] = nil
        end
    end
    self.lines = nil

    -- Clear other fields
    self.border_type = nil
    self.show_time_indicator = nil

    Panel.destroy(self)
end

return Chart

