require 'lfs'
require 'paths'
require 'image'

colormap = {}

-- initializes colormap options
function colormap:__init()
	-- available colormaps
	self.options = {'parula', 'jet', 'hsv', 'hot', 'cool', 'spring', 
					'summer', 'autumn', 'winter', 'gray', 'bone', 'copper', 
					'pink', 'lines', 'colorcube', 'prism', 'flag', 'white'}
	-- 3 channels for RGB image
	self.channels = 3
	-- .t7 files in ./library/ are 512x3 tensors
	self.maxSteps = 512
	self:reset()
end


-- reverts to default
-- style and step number  
function colormap:reset()
	self.style = 'jet'
	self.steps = self.maxSteps
	self:__update()
end

-- sets colormap style; 
-- must be in colormap.options	
function colormap:setStyle(style)
	assert( self:__isAvailable(style) , style..' is not an available style')
	self.style = style
	self:__update()
end

-- sets number of colors in map; 
-- must be <= 512
function colormap:setSteps(steps)
	assert(steps >= 1 and steps <= self.maxSteps, 'Number of steps should be in [1, 512]')
	self.steps = steps
	self:__update()
end


-- reloads style and scales it
-- to correct step number 
function colormap:__update()
	self.currentMap = torch.load( paths.thisfile(self.style..'.t7'), 'ascii' )
	self.currentMap = image.scale(self.currentMap, self.channels, self.steps)
end


-- returns true iff style 
-- is an available option 
function colormap:__isAvailable(style)
	for key, val in ipairs(self.options) do
		if val == style then return true end
	end
	return false
end

-- returns a colorbar of the current style 
-- with current number of steps
function colormap:colorbar(height, width)
	local height = height or self.steps
	local img = torch.range(self.steps, 1, -1)
	-- print('colorbar: ', torch.min(img), torch.max(img))
	local img = img:repeatTensor(width, 1):t()
	local bar = self:convert(img)
	bar = image.scale(bar, width, height, 'simple')
	return bar
end


-- converts a gresycale image 
-- to RGB based on current 
-- style and step number;
-- img should have 2 
-- non-singleton dimensions  
function colormap:convert(img)
	local img = img:squeeze()
	local m, n
	m, n = img:size()[1], img:size()[2]
	local c = self.channels
	
	local indices
	if torch.all(img:eq(img[1][1])) then
		indices = torch.Tensor(m,n):fill(math.floor(self.steps / 2))
	else
		img = img - torch.min(img)
		img = img / torch.max(img) * (self.steps-1) + 1
		indices = torch.ceil(img)
	end
	indices = indices:reshape(indices:numel())

	local cimg = self.currentMap:index(1, indices:long())
	cimg = cimg:reshape(m, n, c)
	cimg = cimg:transpose(3,2):transpose(1,2)
	return cimg
end

-- generates sample RGB images
-- and colorbars for greyscale 
-- photos of Michelangelo's
-- David and a butterfly;
-- saves outputs in a folder 
-- called 'examples/' in
-- working directory
function colormap:samples()
	local currentdir = lfs.currentdir()
	print('Currently in: ' .. currentdir)
	print('OK to save examples folder in current directory? (y/n)')

	if self:__response() then
		lfs.mkdir('examples/')

		-----------------------------------
		-------------- David --------------
		-----------------------------------

		local img = image.load( paths.thisfile('david.jpg') )
		colormap:setStyle('parula')
		colormap:setSteps(512)
		local rgbImg = colormap:convert(img)
		local bar = colormap:colorbar(400, 40)
		image.save('examples/davidRGB.jpg', rgbImg)
		image.save('examples/davidBar.jpg', bar)
		print('(1) Saved David at ./examples/davidRGB.jpg and colorbar at ./examples/davidBar.jpg')

		-----------------------------------
		---------- Butterfly Grid ---------
		-----------------------------------

		local steps = {3, 5, 10, 512}
		local styles = {'jet', 'parula', 'autumn', 'hsv'}
		local img = image.load( paths.thisfile('butterfly.jpg') )

		local examples = {}
		local bars = {}
		for _, style in pairs(styles) do
			colormap:setStyle(style)
			for _, step in pairs(steps) do
				colormap:setSteps(step)
				local rgbImg = colormap:convert(img)
				examples[#examples+1] = rgbImg
			end
		end

		imageGrid = image.toDisplayTensor{input=examples, nrow=#steps}
		image.save('examples/butterflyRGB.jpg', imageGrid)
		print('(2) Saved butterfly grid at ./examples/butterflyRGB.jpg')

		-----------------------------------
		------------ Colorbars  -----------
		-----------------------------------

		colormap:setStyle('jet')
		local styles = {'jet', 'parula', 'autumn', 'hsv', 'hot', 'cool', 'winter', 'spring'}
		local steps = {3, 5, 10, 20, 512}
		local width = 40
		local height = 400
		local bars = {}
		for _, style in pairs(styles) do
			colormap:setStyle(style)
			for _, step in pairs(steps) do
				colormap:setSteps(step)
				local bar = colormap:colorbar(height, width)
				bars[#bars+1] = bar
			end
		end

		colorbarGrid = image.toDisplayTensor{input=bars, padding=80, nrow=#steps*#styles/2}
		image.save('examples/colorbars.jpg', colorbarGrid)
		print('(3) Saved colorbar grid at ./examples/colorbars.jpg')
	end
end

function colormap:__response()
	local answer = io.read()
	if answer == 'y' or answer == 'yes' then
		return true
	elseif answer == 'n' or answer == 'no' then
		return false
	else
		print('Respond with (y/n)')
		return self:__response()
	end
end

colormap:__init()

