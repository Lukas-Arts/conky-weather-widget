package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local Utils  = require("Utils")

-- Define the Panel "class"
local Panel = {}
Panel.__index = Panel

-- Constructor
function Panel:new(config)
    local self = setmetatable({}, self)
    
    self.x_offset = config and config.x_offset or 0
    self.y_offset = config and config.y_offset or 0
    self.x_size   = config and config.x_size or 100
    self.y_size   = config and config.y_size or 100
    self.lastMouseEvent = nil

    self.background = config and config.background or nil
    self.name = config and config.name or 'Panel'
    self.isFireMouseLeftEvent = config and config.isFireMouseLeftEvent or false
    self.hasMouseLeft = true
    
    self.panels = {}
    
    return self
end

-- Helper: set offset
function Panel:set_offset(x_off, y_off)
    self.x_offset = tonumber(x_off)
    self.y_offset = tonumber(y_off)
end

-- Helper: set size
function Panel:set_size(x_s, y_s)
    self.x_size = tonumber(x_s)
    self.y_size = tonumber(y_s)
end

-- Add a new panel
function Panel:add_panel(panel)
    table.insert(self.panels, panel)
end

-- Removes a panel, but does not destroy it
function Panel:remove_panel(panel)
    if panel == nil then
        print("Can't remove nil Panel!")
        return
    end
    local index = Utils.indexOf(self.panels,panel)
    if index then
        table.remove(self.panels, index)
    else
        print("Item not found!")
    end
end

function Panel:fireMouseLeftEvent(event)
    self.hasMouseLeft = true
    local ev = event
    for _, panel in ipairs(self.panels) do
        panel:updateMouseEvent(ev)
    end

    if event == nil then
        ev = { x = -1, y = -1, type = "mouse_leave" }
    else
        ev = { x = event.x, y = event.y, type = "mouse_enter" }
    end
    self:onMouseEvent(ev)
end

-- Update Mouse-Events 
function Panel:updateMouseEvent(event)
    if event then
        if event.x >= self.x_offset and event.y >= self.y_offset and event.x <= self.x_offset + self.x_size and event.y <= self.y_offset + self.y_size then
            self.hasMouseLeft = false
            
            local ev = event
            -- print('Mouse in ' .. self.name .. " type " .. event.type)
            if self.lastMouseEvent == nil or self.lastMouseEvent.type == "mouse_leave" and event.type == "mouse_move" then
                ev = { x = event.x, y = event.y, type = "mouse_enter" }
            end
            self.lastMouseEvent = ev
            for _, panel in ipairs(self.panels) do
                panel:updateMouseEvent(ev)
            end
            self:onMouseEvent(event)
        elseif self.isFireMouseLeftEvent and self.hasMouseLeft == false then
            self:fireMouseLeftEvent(event)
        end
    elseif self.isFireMouseLeftEvent and self.hasMouseLeft == false then
        self:fireMouseLeftEvent(event)
    end
end
 
function Panel:onMouseEvent(event)
    --Utils.printTableKeyValues(event)
    -- if event and event.type then
    --     print(self.name .. ' - ' .. event.type)
    -- end
end

-- Draw Panel Content using cairo
-- Use this method to actually draw. 
-- Call .draw(cr) for Children, to correctly handle Mouse-Events
function Panel:draw_content(cr)
    if self.background then
        local r, g, b, a = Utils.hex2rgb(self.background)
        cairo_set_source_rgba(cr, r, g, b, a)
        cairo_rectangle(cr, self.x_offset, self.y_offset, self.x_size, self.y_size)
        
        cairo_fill(cr)
        cairo_stroke(cr)
    end

    for _, panel in ipairs(self.panels) do
        panel:draw(cr)
    end
end

-- Draw Panel using cairo
-- Don't use this method to actually draw. 
-- Call .draw(cr) for Children, to correctly handle Mouse-Events
function Panel:draw(cr)
    self:draw_content(cr)
end

-- destroy Panel
function Panel:destroy()
    -- Clear all points and properties in each line
    if self.panels then
        for i, panel in ipairs(self.panels) do
            panel:destroy()
            self.panels[i] = nil
        end
    end
    self.panels = nil

    -- Clear other fields
    self.x_offset = nil
    self.y_offset = nil
    self.x_size   = nil
    self.y_size   = nil
    self.lastMouseEvent = nil

    -- Drop metatable so the GC can fully release it
    setmetatable(self, nil)
end

return Panel

