local Iterators = {}

Iterators.shuffle = function(t)
  local keyList = {}
  
  for i in pairs(t) do
    table.insert(keyList, i)
  end
  
  return function(t)
    if #keyList == 0 then
      return nil
    end
    
    local randomValue = table.remove(keyList, math.random(#keyList))
    
    return randomValue, t[randomValue]
  end, t, 0
end

return Iterators
