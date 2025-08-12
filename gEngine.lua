function math.sign(n) return n>0 and 1 or n<0 and -1 or 0 end

function DeepCopy( Table, Cache ) -- Makes a deep copy of a table. 
    if type( Table ) ~= 'table' then
        return Table
    end

    Cache = Cache or {}
    if Cache[Table] then
        return Cache[Table]
    end

    local New = {}
    Cache[Table] = New
    for Key, Value in pairs( Table ) do
        New[DeepCopy( Key, Cache)] = DeepCopy( Value, Cache )
    end

    return New
end

function round(x)
    return math.floor(x+0.5)
end

function setColor(r, g, b, a)
    if (type(r)=="table") then
        a = r[4]
        b = r[3]
        g = r[2]
        r = r[1]
    end
    if (r == nil) then
        r = 0
    end
    if (g == nil) then
        g = 0
    end
    if (b == nil) then
        b = 0
    end
    if (a == nil) then
        a = 255
    end
    local major, minor, revision, codename = love.getVersion()
    love.graphics.setColor(r, g, b, a)
    if (major > 10) then
        love.graphics.setColor(r/255, g/255, b/255, a/255)
    end
end
