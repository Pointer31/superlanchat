local json = require 'libs/json'
local socket = require "socket"
local utf8 = require("utf8")
local sock

local globaltime = 0
local input_text
local input_image
local input_image_SCALE = 16
local IMAGE_MAX_WIDTH = 24
local IMAGE_MAX_HEIGHT = 16
local TIMEOUT = 12
local messages
local messages_offset
local messages_height
local send_ip_setting = "255.255.255.255"
local send_ip = "255.255.255.255"
local use_send_ip_setting = false
local send_keep_alive = false
local send_keep_alive_last = 0
local keep_alives = {}
local function keep_alives_count()
	local count = 0
	for i, con in pairs(keep_alives) do
		if globaltime < con.last + TIMEOUT then 
			count = count + 1
		end
	end
	return count
end
local function keep_alives_add(author)
	for i, con in pairs(keep_alives) do
		if con.author == author then 
			con.last = globaltime
			return true
		end
	end
	table.insert(keep_alives, {author=author, last=globaltime})
end
local on_receive_notify = false
local PORT = 55544
local VERSION = "0.6"
local myName
local myRandomNumber
local state
local settings_selected_field = "myName"
local themes = {}
themes["original"] = {
	color_text = {255,255,255,255},
	color_ui = {100,100,100,255},
	color_box_bg = {0,0,0,0},
	color_background = {0,0,0,255},
	color_text_author = {0,200,0,255},
	color_text_warning = {255,200,0,255},
}
themes["green"] = {
	color_text = {200,255,200,255},
	color_ui = {0,255,0,255},
	color_box_bg = {0,0,0,0},
	color_background = {0,0,0,255},
	color_text_author = {0,255,0,255},
	color_text_warning = {255,200,0,255},
}
themes["sleek"] = {
	color_text = {255,255,255,255},
	color_ui = {100,100,100,255},
	color_box_bg = {50,50,50,255},
	color_background = {10,10,10,255},
	color_text_author = {0,200,0,255},
	color_text_warning = {255,200,0,255},
}
themes["sleekblue"] = {
	color_text = {255,255,255,255},
	color_ui = {98,100,102,255},
	color_box_bg = {49,50,51,255},
	color_background = {9,10,11,255},
	color_text_author = {0,200,0,255},
	color_text_warning = {255,200,0,255},
}
themes["scroll"] = {
	color_text = {0,0,2,255},
	color_ui = {255,200,0,255},
	color_box_bg = {255,235,100,255},
	color_background = {100,60,0,255},
	color_text_author = {100,180,255,255},
	color_text_warning = {255,150,150,255},
}
local theme = themes["original"]
local activeTheme = "original"
for i, theme in pairs(themes) do
	if (theme.color_background[1] > 1) then theme.color_background[1] = theme.color_background[1]/255 end
	if (theme.color_background[2] > 1) then theme.color_background[2] = theme.color_background[2]/255 end
	if (theme.color_background[3] > 1) then theme.color_background[3] = theme.color_background[3]/255 end
end

local settings = {
	{
		text = function() return "theme: " .. activeTheme end,
		activate = function()
			if (activeTheme == "original") then activeTheme = "green"
			elseif (activeTheme == "green") then activeTheme = "sleek"
			elseif (activeTheme == "sleek") then activeTheme = "sleekblue"
			elseif (activeTheme == "sleekblue") then activeTheme = "scroll"
			elseif (activeTheme == "scroll") then activeTheme = "original"
			end
			theme = themes[activeTheme]
		end,
	},
	{
		text = function() return "IP: " .. send_ip_setting end,
		activate = function()
			settings_selected_field = "send_ip"
		end,
	},
	{
		text = function() 
			if (use_send_ip_setting) then
				return "use IP? Yes" 
			else
				return "use IP? No" 
			end
		end,
		activate = function()
			use_send_ip_setting = not use_send_ip_setting
		end,
	},
	{
		text = function() 
			if (send_keep_alive) then
				return "send KeepAlive? Yes" 
			else
				return "send KeepAlive? No" 
			end
		end,
		activate = function()
			send_keep_alive = not send_keep_alive
		end,
	},
	{
		text = function() 
			if (os_name == "Windows" or os_name == "OS X") then
				if (on_receive_notify) then
					return "receive notify? Yes" 
				else
					return "receive notify? No" 
				end
			else
				return ""
			end
		end,
		activate = function()
			if (os_name == "Windows" or os_name == "OS X") then
				on_receive_notify = not on_receive_notify
			else
				on_receive_notify = false
			end
		end,
	},
	{
		text = function() return "save settings" end,
		activate = function()
			love.filesystem.write("settings.json", json.encode({
				myName = myName,
				activeTheme = activeTheme,
				send_ip_setting = send_ip_setting,
			}))
			print("saved!")
		end,
	},
}
--sock:sendto(msg, address, port)


images = {
    image = love.graphics.newImage("assets/image.png"),
    cog = love.graphics.newImage("assets/cog.png"),
}

require 'gEngine'

local bitser = require 'libs/bitser'

function love.load()
	sock = socket.udp()
	sock:settimeout(0)
	sock:setsockname("0.0.0.0", PORT)
	sock:setoption("broadcast", true)

	math.randomseed(os.time())
	love.window.setDisplaySleepEnabled(true)

	input_text = ""
	input_image = {}
	input_cursor = 1
    messages = {}
    messages_offset = 0
    messages_height = 100
    state = "input-text"

    myRandomNumber = math.random(1, 100)
    myName = tostring(myRandomNumber)

	font = love.graphics.setNewFont(30, "normal")

	os_name = love.system.getOS()
	if (os_name == "Android") then
		love.window.setMode(1, 2)
	end

	screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()

    local exists
    local major, minor, revision, codename = love.getVersion()
    if (major == 11) then
    	exists = love.filesystem.getInfo("settings.json")
    else
    	exists = love.filesystem.exists("settings.json")
    end
    if (exists) then
        contents, size = love.filesystem.read("settings.json")
    	local settings = json.decode(contents)
    	if settings.myName then myName = settings.myName end
    	if settings.activeTheme then activeTheme = settings.activeTheme; theme = themes[activeTheme] or themes["original"] end
    	if settings.send_ip_setting then send_ip_setting = settings.send_ip_setting end
    end
end

local function addMessage(msg, author, type)
	msg = msg or "unknown"
	author = author or "unknown"
	messages[#messages + 1] = {content=msg, author=author, type=type}
	if (type == "text/plain") then
		print(author .. ": " ..msg)
	else
		print(author .. " - " ..type)
	end
	-- if (on_receive_notify and not love.window.hasFocus()) then
		love.window.requestAttention()
	-- end
end

local function trySendImage()
	local isImageEmpty = true
	for x=1, IMAGE_MAX_WIDTH do
		if (input_image[x]) then isImageEmpty = false; break end
	end
	if not isImageEmpty then
		-- addMessage(input_text)
		if (myName == "") then myName = tostring(myRandomNumber) end
		if (use_send_ip_setting) then send_ip = send_ip_setting end
		if (send_ip == "") then send_ip = "255.255.255.255" end
		if (send_ip == "255.255.255.255") then sock:setoption("broadcast", true) else sock:setoption("broadcast", false) end
		if (send_ip ~= "255.255.255.255") then addMessage(input_image, myName, "image/bw") end
        sock:sendto("superlanchat;author="..myName..";type=image/bw;content="..bitser.dumps(input_image), send_ip, PORT)
		input_image = {}
	end
end

function love.update(dt)
	globaltime = globaltime + dt
	local msg, address, port = sock:receivefrom()
    if (msg ~= nil) then
    	if (string.sub(msg, 1, 13) == "superlanchat;") then
    		local content = nil
    		local author = nil
    		local type = nil
    		local _, endIndex = string.find(msg, "content=")
    		if (endIndex) then
    			-- print (string.sub(msg, endIndex+1))
    			content = string.sub(msg, endIndex+1)
    		end
    		local _, endIndex = string.find(msg, "author=")
    		if (endIndex) then
    			local msg_cut = string.sub(msg, endIndex+1)
	    		local startIndex, _ = string.find(msg_cut, ";")
    			if (startIndex) then
    				author = string.sub(msg_cut, 1, startIndex-1)
    			end
    		end
    		local _, endIndex = string.find(msg, "type=")
    		if (endIndex) then
    			local msg_cut = string.sub(msg, endIndex+1)
	    		local startIndex, _ = string.find(msg_cut, ";")
    			if (startIndex) then
    				type = string.sub(msg_cut, 1, startIndex-1)
    			end
    		end
    		-- local startIndex, endIndex = string.find(msg, "author=")
    		-- if (endIndex) then
    		-- 	-- print (string.sub(msg, endIndex+1))
    		-- 	content = string.sub(msg, endIndex+1)
    		-- end
    		if (author) then
    			keep_alives_add(author)
    		end
    		if (type == "image/bw" and content) then
				addMessage(bitser.loads(content), author, type)
    		elseif (type == "text/plain" and content) then
    			if (utf8.len(content) ~= nil) then
					addMessage(content, author, "text/plain")
				else
					addMessage("invalid utf8 text", author, "unknown")
				end
    		elseif (content) then
				addMessage("unknown type", author, "unknown")
			end
    	end
    end
    if (globaltime > send_keep_alive_last + 5 and send_keep_alive) then
    	send_keep_alive_last = globaltime
    	if (myName == "") then myName = tostring(myRandomNumber) end
		if (use_send_ip_setting) then send_ip = send_ip_setting end
		if (send_ip == "") then send_ip = "255.255.255.255" end
		if (send_ip == "255.255.255.255") then sock:setoption("broadcast", true) else sock:setoption("broadcast", false) end
        sock:sendto("superlanchat;author="..myName..";type=keepalive", send_ip, PORT)
    end
end

function love.mousemoved( x, y, dx, dy, istouch )
	if (state == "input-image" and (love.mouse.isDown(1) or love.mouse.isDown(2))) then
		local scale = math.min(input_image_SCALE, (screenWidth - 65)/IMAGE_MAX_WIDTH)
		local x = math.floor((x - 10 + scale)/scale)
		local y = math.floor((y - 10 + scale)/scale)
		if (x <= IMAGE_MAX_WIDTH and y <= IMAGE_MAX_HEIGHT) then 
			if (not input_image[x]) then input_image[x] = {} end
			if (love.mouse.isDown(2)) then
				input_image[x][y] = 0
			else
				input_image[x][y] = 1
			end
		end
	end
	if (state ~= "settings" and love.mouse.isDown(1) and y > messages_height) then
		messages_offset = messages_offset - dy*0.014
		if (messages_offset > #messages-1+0.9) then messages_offset = #messages-1 end
		if (messages_offset < 0) then messages_offset = 0 end
	end
end

function love.wheelmoved( x, y )
	messages_offset = messages_offset - y
	if (messages_offset > #messages-1) then messages_offset = #messages-1 end
	if (messages_offset < 0) then messages_offset = 0 end
end

function love.mousepressed(x, y)
	if (x > screenWidth - 50 and y < 50) then
		if (state == "input-text") then
			input_text = ""
		elseif (state == "settings") then
			if (settings_selected_field == "myName") then
				myName = ""
			else
				send_ip_setting = ""
			end
		elseif (state == "input-image") then
			input_image = {}
		end
	elseif (x > screenWidth - 50 and y < 90) then
		if (state == "input-text") then
			state = "input-image"
			love.keyboard.setTextInput(false)
		elseif (state == "input-image") then
			state = "input-text"
			love.keyboard.setTextInput(true)
		end
	elseif (x > screenWidth - 50 and y < 140) then
		if (state == "input-text" or state == "input-image") then
			state = "settings"
			settings_selected_field = "myName"
			love.keyboard.setTextInput(true)
		elseif (state == "settings") then
			state = "input-text"
			love.keyboard.setTextInput(true)
		end
	elseif (x > screenWidth - 50 and y > 20+math.min(input_image_SCALE, (screenWidth - 65)/IMAGE_MAX_WIDTH)*IMAGE_MAX_HEIGHT-50 and y < 20+math.min(input_image_SCALE, (screenWidth - 65)/IMAGE_MAX_WIDTH)*IMAGE_MAX_HEIGHT) then
		trySendImage()
		-- if (love.system.getOS() == "Android") then
		-- 	love.keyboard.setTextInput(false)
		-- end
	elseif (state == "input-text" and y < messages_height) then
		love.keyboard.setTextInput(true)
	elseif (state == "settings") then
		if (x < screenWidth - 50 and y > 105+lineHeight and y < 105+lineHeight*2) then
			settings[1].activate()
		elseif (x < screenWidth - 50 and y > 110+lineHeight*2 and y < 110+lineHeight*3) then
			settings[2].activate()
		elseif (x < screenWidth - 50 and y > 115+lineHeight*3 and y < 115+lineHeight*4) then
			settings[3].activate()
		elseif (x < screenWidth - 50 and y > 120+lineHeight*4 and y < 120+lineHeight*5) then
			settings[4].activate()
		elseif (x < screenWidth - 50 and y > 125+lineHeight*5 and y < 125+lineHeight*6) then
			settings[5].activate()
		elseif (x < screenWidth - 50 and y > 130+lineHeight*6 and y < 130+lineHeight*7) then
			settings[6].activate()
		end
	end
end

local function textInput(text)
	if (state == "input-text") then
		input_text = input_text .. text
	elseif (state == "settings") then
		if (settings_selected_field == "myName") then
			myName = myName .. text
		else
			send_ip_setting = send_ip_setting .. text
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	if (state == "input-text") then
		if key == "backspace" then
			input_text = input_text:sub(1, -2)
		end
		if key == "return" then
			if input_text ~= "" then
				-- addMessage(input_text)
				if (myName == "") then myName = tostring(myRandomNumber) end
				if (use_send_ip_setting) then send_ip = send_ip_setting end
				if (send_ip == "") then send_ip = "255.255.255.255" end
				if (send_ip == "255.255.255.255") then sock:setoption("broadcast", true) else sock:setoption("broadcast", false) end
	            if (send_ip ~= "255.255.255.255") then addMessage(input_text, myName, "text/plain") end
	            sock:sendto("superlanchat;author="..myName..";type=text/plain;content="..input_text, send_ip, PORT)
				input_text = ""
			end
		end
	elseif (state == "settings") then
		if key == "backspace" then
			if (settings_selected_field == "myName") then
				myName = myName:sub(1, -2)
			else
				send_ip_setting = send_ip_setting:sub(1, -2)
			end
		end
		if key == "return" then
		end
	elseif (state == "input-image") then
		if key == "return" then
			trySendImage()
		end
	end

	local osString = love.system.getOS()
	local control
	if osString == "OS X" then
		control = love.keyboard.isDown("lgui","rgui")
	elseif osString == "Windows" or osString == "Linux" then
		control = love.keyboard.isDown("lctrl","rctrl")
	end
	if control then
		-- if key == "c" then
		-- 	if buffer then love.system.setClipboardText(buffer) end
		-- end
		if key == "v" then
			textInput(love.system.getClipboardText())
		end
	end

	-- if (key == "r" and love.keyboard.isDown("lshift")) then
    --     love.event.quit("restart")
    -- end
	-- input_text = key .. ' ' .. scancode 
end

function love.keyreleased( key, scancode )

	-- input_text = input_text .. ' ' .. key .. ' ' .. scancode
end

function love.textinput(text)
	textInput(text)
end

function love.resize(w, h)
	screenWidth = w
	screenHeight = h
    -- screenWidth = love.graphics.getWidth()
    -- screenHeight = love.graphics.getHeight()
end

local function drawCanvas(image_array, x, y, scale)
	for dx = 1, IMAGE_MAX_WIDTH do
		for dy = 1, IMAGE_MAX_HEIGHT do
			if (image_array[dx] and image_array[dx][dy] == 1) then
				love.graphics.rectangle("fill", x + (dx-1)*scale, y + (dy-1)*scale, scale, scale)
			end
		end
	end
end

function love.draw()
	love.graphics.setBackgroundColor(theme.color_background)

	local height = 5
	lineHeight = 40

	local function getLines(text, width)
		width, wrappedtext = font:getWrap(text, width)
		return wrappedtext
	end

	local function drawText(wrappedtext, x, y)
		for i, line in pairs(wrappedtext) do
			love.graphics.print(line, x, y + (i-1)*lineHeight)
		end
	end

	local function drawBox(x, y, width, height)
		setColor(theme.color_box_bg)
		love.graphics.rectangle("fill", x, y, width, height)
		setColor(theme.color_ui)
		love.graphics.rectangle("line", x, y, width, height)
	end

	local lines = 0
	if (state == "input-text") then
		-- lines = drawText(input_text, 10, 10, screenWidth - 60)
		lines_text = getLines(input_text, screenWidth - 60)
		lines = #lines_text
		if (lines < 2) then lines = 2 end
		-- if (height < 100) then height = 100 end

		setColor(theme.color_ui)
		drawBox(5, height, screenWidth - 55, lines*lineHeight)
		setColor(theme.color_text)
		drawText(lines_text, 10, 10)

		height = height + lines*lineHeight + 15
	elseif (state == "input-image") then
		local scale = math.min(input_image_SCALE, (screenWidth - 65)/IMAGE_MAX_WIDTH)
		setColor(theme.color_ui)
		drawBox(5, height, scale*IMAGE_MAX_WIDTH + 10, scale*IMAGE_MAX_HEIGHT + 10)
		love.graphics.line(screenWidth - 45, height+15+scale*IMAGE_MAX_HEIGHT, 
			screenWidth - 5, height+15+scale*IMAGE_MAX_HEIGHT - 25,
			screenWidth - 45, height+15+scale*IMAGE_MAX_HEIGHT - 50)
		setColor(theme.color_text)
		drawCanvas(input_image, 10, 10, scale)

		height = height + scale*IMAGE_MAX_HEIGHT + 25
	end
	setColor(theme.color_ui)
	love.graphics.line( screenWidth - 45, 5, screenWidth - 5, 45)
	love.graphics.line( screenWidth - 45, 45, screenWidth - 5, 5)
	if state ~= "settings" then love.graphics.draw(images.image, screenWidth - 45, 50, 0, 40/images.image:getWidth()) end
	love.graphics.draw(images.cog, screenWidth - 45, 95, 0, 40/images.cog:getWidth())

	if (height < 120) then height = 120 end
	messages_height = height
	-- love.graphics.printf(input_text, 10, 10, screenWidth - 50, 'left', 0, 1)


	if (state ~= "settings") then
		-- draw messages
		local previousAuthor = ""
		if (math.floor(messages_offset) > 0) then
			setColor(theme.color_text_author)
			love.graphics.print("looking at past messages", screenWidth - 50 - font:getWidth("looking at past messages")/2, height, 0, 0.5)
		end
		if (send_ip_setting ~= "255.255.255.255" and send_ip_setting ~= "" and use_send_ip_setting) then
			setColor(theme.color_text_warning)
			local offset = 0
			if (math.floor(messages_offset) > 0) then offset = -15 end
			love.graphics.print("DM sending mode", screenWidth - 50 - font:getWidth("DM sending mode")/2, height + offset, 0, 0.5)
		end
		if (keep_alives_count() > 0) then
			setColor(theme.color_ui)
			love.graphics.print("#people " .. tostring(keep_alives_count()), 10, height - 15, 0, 0.5)
		end
		for i = 1, 12 do
			local j = #messages - i + 1 - math.floor(messages_offset)
			if (not messages[j]) then
				break
			end
			if (messages[j].author ~= previousAuthor) then
				setColor(theme.color_text_author)
				love.graphics.print(messages[j].author, 10, height, 0, 0.5)
				height = height + 20
			end
			previousAuthor = messages[j].author
			setColor(theme.color_text)
			local extraHeight = lineHeight
			local lines_text = {""}
			if (messages[j].type == "text/plain") then
				lines_text = getLines(messages[j].content, screenWidth - 20)
				extraHeight = #lines_text*lineHeight
			elseif (messages[j].type == "image/bw") then
				extraHeight = 6*IMAGE_MAX_HEIGHT + 10
			elseif (messages[j].type == "unknown") then
				setColor(theme.color_ui)
				lines_text = getLines(messages[j].content, screenWidth - 60)
				extraHeight = #lines_text*lineHeight
			end
			if extraHeight == 0 then extraHeight = 0.2*lineHeight end
			setColor(theme.color_ui)
			drawBox(5, height, screenWidth - 10, extraHeight)
			setColor(theme.color_text)
			if (messages[j].type == "unknown") then setColor(theme.color_ui) end
			if (messages[j].type == "image/bw") then drawCanvas(messages[j].content or {}, 10, height + 5, 6) end
			drawText(lines_text, 10, height)
			height = height + extraHeight + 5
			-- love.graphics.printf(messages[j] or "error", 10, 10 + offset, screenWidth - 20, 'left', 0, 1)
		end
	else -- settings
		love.graphics.print("settings", 10, 10)
		setColor(theme.color_text)

		height = 100

		local lines_text = getLines(myName, screenWidth - 60 - font:getWidth("name: "))
		local lines = #lines_text
		if lines == 0 then lines = 1 end
		setColor(theme.color_ui)
		drawBox(5, height, screenWidth - 55, lines*lineHeight)
		setColor(theme.color_text)
		love.graphics.print("name:", 10, height)
		drawText(lines_text, 10 + font:getWidth("name: "), height)

		height = height + lines*lineHeight + 5

		for i, setting in pairs(settings) do
			local lines_text = getLines(setting.text(), screenWidth - 60)
			local lines = #lines_text
			if lines == 0 then lines = 1 end

			drawBox(5, height, screenWidth - 55, lines*lineHeight)
			setColor(theme.color_text)
			drawText(lines_text, 10, height)

			height = height + lines*lineHeight + 5
		end
		-- love.graphics.print("theme?", 10, 90)
		-- setColor(0,0,0, 150)
		-- love.graphics.rectangle("fill", screenWidth - 5 - font:getWidth(VERSION), screenHeight - 40, font:getWidth(VERSION)+5, 40)
		setColor(theme.color_ui)
		love.graphics.print("v" .. VERSION, screenWidth - 5 - font:getWidth("v" .. VERSION), screenHeight - 40, 0, 1)
	end
	setColor(255,255,255,255)
end