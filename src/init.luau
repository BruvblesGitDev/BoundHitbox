local RunService = game:GetService("RunService")

local Packages = script.Parent.Parent
local Types = require(script.Types)
local Signal = require(Packages.Signal)

local _cache = setmetatable({}, { __mode = "k" }) :: Cache
local MAX_HIT_PER_SEC = 15

local BoundHitBox = {}
BoundHitBox.__index = BoundHitBox

type Cache = typeof(setmetatable({} :: { [any]: BoundHitBox }, { __mode = "k" }))

export type BoundHitBox = typeof(setmetatable(
	{} :: {
		-- variables
		key: any?,
		params: Types.Params?,
		trueParams: OverlapParams,
		hoph: boolean?,
		visual: boolean?,
		conection: RBXScriptConnection?,
		thread: thread?,
		signal: any,
	},
	BoundHitBox
))

function BoundHitBox.new(options: Types.Options): BoundHitBox
	local self = {
		key = options.key,
		params = options.params,
		trueParams = nil,
		signal = Signal.new(),
	}
	setmetatable(self, BoundHitBox)
	self:_register()
	return self
end

function BoundHitBox.hit(self: BoundHitBox, cframe: CFrame, size: Vector3, hopc: boolean?)
	local params = self.trueParams
	local bound = workspace:GetPartBoundsInBox(cframe, size, params)
	params:AddToFilter(bound)
	self.signal:Fire(bound)

	if hopc then
		self:clearFilter()
	end

	if self.visual then
		task.spawn(function()
			self:_createPart(cframe, size)
		end)
	end
end

function BoundHitBox.start(self: BoundHitBox, hitPerSec: number, hitbox: BasePart, hopc: boolean?): ()
	if self.conection then
		warn(`hitbox is already running`)
		return
	end

	hitPerSec = hitPerSec and math.clamp(hitPerSec, 1, MAX_HIT_PER_SEC)
	local interval = 1 / hitPerSec
	local elapsed = 0

	self.conection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed -= interval
			self:hit(hitbox.CFrame, hitbox.Size, hopc)
		end
	end)
end

function BoundHitBox.run(self: BoundHitBox, hitPerSec: number, time: number, hitbox: BasePart, hopc: boolean?): ()
	if not hitbox or not hitbox.Parent then
		warn(`hitbox doesnt exist`)
		return
	end

	if self.conection then
		warn(`hitbox is already running`)
		return
	end

	hitPerSec = hitPerSec and math.clamp(hitPerSec, 1, MAX_HIT_PER_SEC)
	local interval = 1 / hitPerSec
	local elapsed = 0

	self.conection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed -= interval
			self:hit(hitbox.CFrame, hitbox.Size, hopc)
		end
	end)

	self.thread = task.delay(time, function()
		self.thread = nil
		self:stop()
	end)
end

function BoundHitBox.clearFilter(self: BoundHitBox): ()
	local params = self.params
	local defaultFilter = params and params.filterDescendants
	self.trueParams.FilterDescendantsInstances = defaultFilter and defaultFilter or {}
end

function BoundHitBox.stop(self: BoundHitBox): ()
	if self.conection then
		self.conection:Disconnect()
		self.conection = nil
	end

	if self.thread then
		task.cancel(self.thread)
		self.thread = nil
	end

	self:clearFilter()
end

function BoundHitBox.destroy(self: BoundHitBox): ()
	if self.key then
		_cache[self.key] = nil
	end

	if self.conection then
		self.conection:Disconnect()
	end

	if self.thread then
		task.cancel(self.thread)
	end

	self.signal:Destroy()
end

function BoundHitBox.visual(self: BoundHitBox, state: boolean): ()
	self.visual = state
end

function BoundHitBox.getHitSignal(self: BoundHitBox): any
	return self.signal
end

function BoundHitBox.get(key: string): BoundHitBox?
	return _cache[key]
end

function BoundHitBox._createPart(_self: BoundHitBox, cframe: CFrame, size: Vector3)
	local part = Instance.new("Part")
	part.CanCollide = false
	part.Color = Color3.fromRGB(238, 0, 0)
	part.Transparency = 0.5
	part.Anchored = true
	part.CFrame = cframe
	part.Size = size
	part.Parent = workspace
	part.CanQuery = false
	part.CanTouch = false
	task.delay(0.1, function()
		part:Destroy()
	end)
end

function BoundHitBox._newParams(self: BoundHitBox)
	self.trueParams = OverlapParams.new()
	local p = self.params
	local trueParams = self.trueParams

	if p then
		local filterType = p.filterType and Enum.RaycastFilterType[p.filterType] or Enum.RaycastFilterType.Exclude
		trueParams.CollisionGroup = p.collisionGroup and p.collisionGroup or "Default"
		trueParams.BruteForceAllSlow = p.bruteForceAllSlow
		trueParams.FilterDescendantsInstances = p.filterDescendants or {}
		trueParams.FilterType = filterType
		trueParams.MaxParts = p.maxParts
		trueParams.RespectCanCollide = p.respectCanCollide
		self.hoph = (p.hitOncePerHit == nil) and true or p.hitOncePerHit
	end
end

function BoundHitBox._register(self: BoundHitBox)
	self:_newParams()
	if self.key then
		_cache[self.key] = self
	end
end

return BoundHitBox
