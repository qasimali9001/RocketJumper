-- Shared constructor helper. Every gameplay class uses this and a metatable.

local Class = {}

function Class.instance(classTable)
	return setmetatable({}, classTable)
end

return Class
