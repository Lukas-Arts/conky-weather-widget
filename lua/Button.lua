package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
local Class = require("Class")
local Panel = require("Panel")
local Utils  = require("Utils")

-- Define the Button "class"
local Button = Class.new(Panel)  -- inherits Panel

-- Constructor
function Button:new(config)
    -- First call Panel constructor
    local self = Button.super.new(self, config) -- call Panel:new
    
    self.draw_border = config and config.draw_border or false -- be aware that booleans cant be set to false like this, so it's the default
    self.border_type = config and config.border_type or "plot-both"
    self.border_line_props = config and config.border_line_props or Utils.getLineProps("#3B5969FF")
    self.border_hovered_line_props = config and config.border_line_props or Utils.getLineProps("#6090B8FF")
    self.border_clicked_line_props = config and config.border_line_props or Utils.getLineProps("#75A5CDFF")
    self.border_selected_line_props = config and config.border_selected_line_props or Utils.getLineProps("#37668dff")
    
    self.name = config and config.name or 'Button'
    self.font = config and config.font or Utils.getFont()

    self.onButtonClicked = config and config.onButtonClicked or nil
    self.text_extents = nil

    self.text = config and config.text or 'Text'

    self.useSelectedAsTextColor = config and config.useSelectedAsTextColor or false

    self.hovered = config and config.hovered or false
    self.clicked = config and config.clicked or false
    self.selected = config and config.selected or false
    self.text_y_offset = config and config.text_y_offset or 0
    self.text_x_offset = config and config.text_x_offset or 0

    return self
end

function Button:set_text(text)
    self.text = text
    self.text_extents = nil
end

function Button:set_text_extents(cr)
    cairo_select_font_face(cr, self.font.name, self.font.slant, self.font.weight)
    cairo_set_font_size(cr, self.font.size)           -- font size
    local extents = cairo_text_extents_t:create()
    cairo_text_extents(cr, self.text, extents)

    self.text_extents = extents
end

function Button:onMouseEvent(event)
    if event.type == "mouse_enter" or event.type == "mouse_move" then
        self.hovered = true
    end
    if event.type == "mouse_leave" then
        self.hovered = false
        self.clicked = false
    end
    if event.type == "button_down" then
        -- print('button down! clicked ' .. tostring(self.clicked))
        self.clicked = true
    end
    if event.type == "button_up" then
        -- print('button up! clicked ' .. tostring(self.clicked))
        if self.clicked == true then
            self:handleClick(event.x,event.y)
        end
        self.clicked = false
    end
end

function Button:handleClick(x,y)
    if self.onButtonClicked then
        self.onButtonClicked(self,x,y)
    end
end

-- Draw Button using cairo
function Button:draw_content(cr)
    Button.super.draw_content(self,cr)

    if self.text_extents == nil then
        self:set_text_extents(cr)
    end

    local lineProps = self.border_line_props
    if self.hovered then
        lineProps = self.border_hovered_line_props
    end
    if self.clicked then
        lineProps = self.border_clicked_line_props
    end

    self.font.colorHex = lineProps.colorHex

    if self.draw_border == true then
        if self.selected then
            Utils.drawBox(cr,self.x_offset + 2,self.y_offset + 2,self.x_size - 3,self.y_size - 3,self.border_selected_line_props)
        end

        Utils.drawBox(cr,self.x_offset + 1,self.y_offset + 1,self.x_size - 1,self.y_size - 1,lineProps)
    end
    if self.useSelectedAsTextColor and self.selected then
        self.font.colorHex = self.border_selected_line_props.colorHex
    end
    
    Utils.drawText(cr,self.x_offset + self.x_size/2 - self.text_extents.width/2 + self.text_x_offset,self.y_offset + self.y_size/2 + self.text_extents.height/2 + self.text_y_offset,self.text,self.font)
end

function Button:destroy()
    -- Clear other fields
    self.border_type = nil
    self.border_line_props = nil
    self.border_hovered_line_props = nil
    self.border_clicked_line_props = nil
    self.name = nil
    self.onButtonClicked = nil

    Panel.destroy(self)
end

return Button