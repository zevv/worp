
-- 
-- Generic list class with handy operators
--


local list_meta = {

	__index = {

		-- Add item to end of list

		append = function(list, e)
			list[#list+1] = e
			return list
		end,
		
		-- Add item to end of list

		push = function(list, e)
			list[#list+1] = e
			return list
		end,

		-- Insert item at front of list

		prepend = function(list, e)
			table.insert(list, 1, e)
			return list
		end,
		
		unshift = function(list, e)
			table.insert(list, 1, e)
			return list
		end,
		
		-- Return copy of list
		
		copy = function(list)
			local list2 = List()
			for e in list:each() do
				list2:append(e)
			end
			return list2
		end,

		-- Return first element

		head = function(list)
			return list[1]
		end,

		-- Return copy of list omitting first element

		tail = function(list)
			return list:splice(2)
		end,

		-- transpose list-of-list

		zip = function(list)
			local list2 = List()
			for i, row in ipairs(list) do
				for j, col in ipairs(row) do
					list2[j] = list2[j] or List()
					list2[j][i] = col
				end
			end
			return list2
		end,

		-- fold function

		fold = function(list, fn)
			local r 
			for a in list:each() do
				r = r and fn(r, a) or a
			end
			return r
		end,
		
		-- Remove and return last element

		pop = function(list)
			local e = list[1]
			table.remove(list)
			return e
		end,

		-- Remove and return first element

		shift = function(list)
			local e = list[1]
			table.remove(list, 1)
			return e
		end,

		-- Take first n elements

		take = function(list, n)
			return list:splice(1, n)
		end,

		-- Return splice of list in given range

		splice = function(list, a, b)
			local o = List()
			for i = (a or 1), (b or #list) do
				o:append(list[i])
			end
			return o
		end,

		-- Return a new list with the elements in reverse order

		reverse = function(list)
			local list2 = List()
			local n = #list
			for i = 1, n do
				list2[i] = list[n-i+1]
			end
			return list2
		end,

		-- Iterate over each element in the list

		each = function(list)
			local n = 0
			return function()
				n = n + 1
				if list[n] then return list[n] end
			end
		end,

		-- functional map

		map = function(list, fn)
			if type(fn) == "string" then fn = lambda(fn) end
			local l2 = List()
			for e in list:each() do
				l2:append(fn(e))
			end
			return l2
		end,
		
		-- functional map on 2 tables

		map2 = function(list, list2, fn)
			local out = List()
			for i = 1, #list do
				out:append(fn(list[i], list2[i]))
			end
			return out
		end,

		-- Sort

		sort = function(list, fn)
			table.sort(list, fn)
			return list
		end,

		-- Concatenate all elements into a string

		concat = function(list, sep)
			return table.concat(list, sep)
		end,

		-- Unpack to argument list
	
		unpack = function(list)
			return unpack(list)
		end,
		
		-- Return number of elements on the list

		size = function(list)
			return #list
		end,

		-- Return true if empty

		is_empty = function(list)
			return #list == 0
		end,

		-- Return true if the given item is present in the list

		contains = function(list, e)
			for n = 1, #list do
				if list[n] == e then return true
				end
			end
		end,

		remove = function(list, e)
			for n = 1, #list do
				if list[n] == e then
					table.remove(list, n)
				end
			end
			
		end

	}
}


function List(t)
	local list = t or {}
	setmetatable(list, list_meta)
	return list
end



-- vi: ft=lua ts=3 sw=3

