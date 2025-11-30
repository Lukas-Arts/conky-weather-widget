package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local Class = require("Class")
local Panel = require("Panel")
local Utils  = require("Utils")

-- Define the ProgressBar "class"
local ProgressBar = Class.new(Panel)  -- inherits Panel

-- Constructor
function ProgressBar:new(config)
    -- First call Panel constructor
    local self = ProgressBar.super.new(self, config) -- call Panel:new
    
    self.isFireMouseLeftEvent = true
    self.draw_border = config and config.draw_border or false -- be aware that booleans cant be set to false like this, so it's the default
    self.border_type = config and config.border_type or "plot-both"
    self.border_line_props = config and config.border_line_props or Utils.getLineProps("#3B5969FF")
    self.border_hovered_line_props = config and config.border_hovered_line_props or Utils.getLineProps("#6090B8FF")
    self.border_clicked_line_props = config and config.border_clicked_line_props or Utils.getLineProps("#75A5CDFF")
    self.border_selected_line_props = config and config.border_selected_line_props or Utils.getLineProps("#37668dff")
    
    self.name = config and config.name or 'ProgressBar'

    self.onProgressBarClicked = config and config.onProgressBarClicked or nil

    self.hovered = config and config.hovered or false
    self.clicked = config and config.clicked or false
    self.selected = config and config.selected or false

    self.current_progress = 1
    self.max_progress = 1

    return self
end

function ProgressBar:onMouseEvent(event)
    ProgressBar.super.onMouseEvent(self,event)
    if event.type == "mouse_enter" or event.type == "mouse_move" then
        self.hovered = true
    end
    if event.type == "mouse_leave" then
        self.hovered = false
        self.clicked = false
    end
    if event.type == "button_down" then
        -- print('ProgressBar down! clicked ' .. tostring(self.clicked))
        self.clicked = true
    end
    if event.type == "button_up" then
        -- print('ProgressBar up! clicked ' .. tostring(self.clicked))
        if self.clicked == true then
            self:handleClick(event.x,event.y)
        end
        self.clicked = false
    end
end

function ProgressBar:handleClick(x,y)
    -- print("handle progress bar")
    if self.onProgressBarClicked then
        self.onProgressBarClicked(self,x,y)
    end
end

-- Draw ProgressBar using cairo
function ProgressBar:draw_content(cr)
    ProgressBar.super.draw_content(self,cr)


    local lineProps = self.border_line_props
    if self.hovered then
        lineProps = self.border_hovered_line_props
    end
    if self.clicked then
        lineProps = self.border_clicked_line_props
    end

    if self.draw_border == true then
        if self.selected then
            Utils.drawBox(cr,self.x_offset + 2,self.y_offset + 2,self.x_size - 3,self.y_size - 3,self.border_selected_line_props)
        end

        Utils.drawBox(cr,self.x_offset + 1,self.y_offset + 1,self.x_size - 1,self.y_size - 1,lineProps)
    end
    
    Utils.drawLine(cr,self.x_offset + 1,self.y_offset + 1 + (self.y_size - 1)/2,self.x_size - 1,0,lineProps)

    local step = (self.x_size - 1)/(self.max_progress - 1)
    for i = 0, self.max_progress - 1, 1 do
        Utils.drawLine(cr,self.x_offset + 1 + step * i ,self.y_offset + 1 + (self.y_size - 1)/2 - 2,0,5,lineProps)
    end

    local radius = 3
    cairo_arc(cr,self.x_offset + 1 + step * (self.current_progress - 1), self.y_offset + 1 + (self.y_size - 1)/2, radius, 0, 2 * math.pi)
    cairo_fill(cr)
end

function ProgressBar:destroy()
    -- Clear other fields
    self.border_type = nil
    self.border_line_props = nil
    self.border_hovered_line_props = nil
    self.border_clicked_line_props = nil
    self.border_selected_line_props = nil
    self.name = nil
    self.onProgressBarClicked = nil

    Panel.destroy(self)
end

return ProgressBar