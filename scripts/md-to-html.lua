-- md-to-html.lua
function Link(el)
  if el.target:match("%.md$") then
    el.target = el.target:gsub("%.md$", ".html")
  end
  -- 也处理带锚点的：xxx.md#section
  if el.target:match("%.md#") then
    el.target = el.target:gsub("%.md#", ".html#")
  end
  return el
end