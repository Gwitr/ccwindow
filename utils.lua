local function pairsToTable(inp)
  local tab = {}
  for key, value in pairs(inp) do tab[key] = value end
  return tab
end

local function call_base(self, ...)
  local instance = self:allocate(...)
  instance:initialize(...)
  return instance
end

local function map(tab, func)
  local newtab = {}
  for i, v in ipairs(tab) do table.insert(newtab, func(v, i)) end
  return newtab
end

local function minf(tab, key)
  local minv, minobj, mini = math.huge, nil, 0
  for i, v in ipairs(tab) do
    if key(v) < minv then
      minv = key(v, i)
      minobj = v
      mini = i
    end
  end
  return minobj, mini
end

local function minf(tab, key)
  local minv, minobj, mini = math.huge, nil, 0
  for i, v in ipairs(tab) do
    if key(v) < minv then
      minv = key(v, i)
      minobj = v
      mini = i
    end
  end
  return minobj, mini
end

local Class = {__call=call_base}
Class.__index = Class
setmetatable(Class, {__call=call_base})

function Class:allocate(base)
  local instance = {class=base or self, abstract_methods={}, __call=call_base}
  instance.__index = instance
  setmetatable(instance, instance.class)
  function instance:allocate()
    local instance = {class=self}
    for name, default in pairs(self.abstract_methods) do
      if self[name] == default then
        error("cannot instantiate class with abstract method " .. name)
      end
    end
    setmetatable(instance, self)
    return instance
  end
  return instance
end

function Class:initialize(base)
end

function Class:abstractMethod(name)
  self[name] = function()
    error("call of abstract method " .. name)
  end
  self.abstract_methods[name] = self[name]
end

return {Class=Class, map=map, minf=minf, pairsToTable=pairsToTable}
