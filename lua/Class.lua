package.path = package.path .. string.format(';%s/.conky/weather-widget/lua/?.lua',os.getenv("HOME"))
-- Class.lua - lightweight Lua OOP helper
-- Init base classes like normal with
--
-- local BaseClass = {}
-- BaseClass.__index = BaseClass
-- function BaseClass:new(config)
--    local self = setmetatable({}, self)
--    return self
-- end
--
-- Then for the sub-class:

-- local SubClass = Class.new(BaseClass)
-- function SubClass:new(config)
--    local self = SubClass.super.new(self, config)
-- end


local Class = {}

function Class.new(base)
    local cls = {}
    cls.__index = cls
    cls.super = base

    -- inherit from base class
    if base then
        setmetatable(cls, { __index = base })
    end

    -- default constructor
    function cls:new(o)
        o = o or {}
        return setmetatable(o, cls)
    end

    return cls
end

return Class