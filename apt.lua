#!/usr/bin/env luajit

--[[
  apt.lua - library for manipulating APT source listings
  Copyright (C) 2014 Jens Oliver John <dev@2ion.de>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

  This project is being maintained at <https://github.com/2ion/apt-source>.
--]]

local APT = {}
local APTSourceEntry = {}
local APTSource = {}
local Inspect = require 'inspect.inspect'

function APTSourceEntry:new(s_type, t_options,
  s_uri, s_suite, t_components)
  local o = {}
  setmetatable(o, { __index = self })
  o.type = s_type
  o.options = t_options
  o.uri = s_uri
  o.suite = s_suite
  o.components = t_components
  o.active = true
  return o
end

function APTSourceEntry:apply(f)
  f(self)
  return self
end

function APTSourceEntry:enable()
  self.active = true
  return self.active
end

function APTSourceEntry:disable()
  self.active = false
  return self.active
end

function APTSourceEntry:toggle_active()
  self.active = self.active and false or true
  return self.active
end

function APTSourceEntry:tostring()
  local type = self.type
  local options = self:tostring_options()
  local uri = self.uri
  local suite = self.suite
  local components = self:tostring_components()
  return string.format("%s%s%s%s%s",
    type and (self.active and type or "#"..type) or "",
    options and string.format(" [ %s ] ", options) or " ",
    uri and uri .. " " or " ",
    suite and suite .. " " or " ",
    components or "")
end

function APTSourceEntry:tostring_options()
  if not self.options then return nil end
  local s = ""
  for oname,ovalues in pairs(self.options) do
    s = string.format("%s%s=", s, oname)
    if type(ovalues)=="string" then
      s = s .. ovalues
    else
      for i=1,#ovalues do
        if i==#ovalues then
          s = s .. ovalues[i]
        else
          s = string.format("%s%s,", s, ovalues[i])
        end
      end
    end
  end
  return s
end

function APTSourceEntry:tostring_components()
  if not self.components then return nil end
  return table.concat(self.components, " ")
end

function APTSourceEntry:change(ct)
  for k,v in pairs(ct) do self[k] = ct[k] end
end

function APTSource:init(path)
  local o = {}
  setmetatable(o, { __index = self })
  o.path = path
  if o.path then
    o:parse()
  end
  return o
end

function APTSource:log(...)
  print(string.format("%s: %s",
    self.path or "<nopath>",
    string.format(...)))
end

function APTSource:parse(path)
  local fd
  self.entries = {}
  if path then self.path = path end
  fd = io.open(self.path, "r")
  if not fd then return nil end
  for line in fd:lines() do
    local e = self:parse_line(line)
    if e then
      table.insert(self.entries, e)
    end
  end
  io.close(fd)
  self.ready = true
  return self
end

function APTSource:is_ready()
  return self.ready
end

function APTSource:parse_line(line)
  if line:match("^[%s]+#") then return nil end
  local e = APTSourceEntry:new()
  local nextIs = "type"
  local elemlist = {}
  for elem in line:gmatch("%S+") do 
    local elem = elem
    if elem:match("^#deb") then
      elem = elem:sub(2, -1)
      e.active = false
    end
    if nextIs=="type" then
      self:parse_line_type(e, elem)
      nextIs = "options"
    elseif nextIs=="options" then
      if elem=="[" then
        nextIs = "options-list"
      else
        nextIs = "suite"
        self:parse_line_uri(e, elem)
      end
    elseif nextIs=="options-list" then
      if elem=="]" then
        self:parse_line_options(e, elemlist)
        nextIs = "uri"
      else
        table.insert(elemlist, elem)
      end
    elseif nextIs=="uri" then
      self:parse_line_uri(e, elem)
      nextIs="suite"
    elseif nextIs=="suite" then
      self:parse_line_suite(e, elem)
      nextIs = "component"
    elseif nextIs=="component" then
      self:parse_line_component(e, elem)
    end
  end 
  if not e.type then return nil end
  return e
end

function APTSource:parse_line_component(e, elem)
  if not e.components then e.components = {} end
  table.insert(e.components, elem)
  return true
end

function APTSource:parse_line_uri(e, elem)
  e.uri = elem
  return true
end

function APTSource:parse_line_options(e, elemlist)
  local t = {}
  for i,o in ipairs(elemlist) do
    local k, vl = o:match("^([%w]+)=(%S+)$")
    if k then t[k] = {} end
    if vl then
      for value in vl:gmatch("[%S^,]+") do
        table.insert(t[k], value)
      end
    end
    if #vl == 1 then
      local z = vl[1]
      t[k] = z
    end
  end
  e.options = t
  return true
end

function APTSource:parse_line_suite(e, elem)
  e.suite = elem
  return true
end

function APTSource:parse_line_type(e, elem)
  if elem ~= "deb-src" and elem ~= "deb" then
    return
  end
  e.type = elem
  return true
end

function APTSource:enum()
  if not self.entries then return self end
  for i,e in ipairs(self.entries) do
    print(e:tostring())
  end
  return self
end

function APTSource:path()
  return self.path
end

function APTSource:select(qt)
  local s = {}
  for _,e in ipairs(self.entries) do
    local matches = false
    for qk,qv in pairs(qt) do
      if not e[qk] then break end
      if type(qv) == "table" then
        local ormatch = false
        for _,qvv in ipairs(qv) do
          if e[qk] == qvv then
            ormatch = true
          end
        end
        if ormatch then
          matches = true
        end
      else
        if e[qk] == qv then
          matches = true
        end
      end
    end
    if matches then
      table.insert(s, e)
    end
  end
  return s
end

function APTSource:forsome_change(qt, ct, f)
  local sel = self:select(qt)
  for _,e in ipairs(sel) do
    e:change(ct)
    if f then e:apply(f) end
  end
  return self
end

function APTSource:forsome_do(qt, f)
  local sel = self:select(qt)
  for d,e in ipairs(sel) do e:apply(f) end
  return self
end

function APTSource:foreach_do(f)
  for _,e in ipairs(self.entries) do e:apply(f) end
  return self
end

function APTSource:foreach_change(ct)
  for _,e in ipairs(self.entries) do e:change(ct) end
  return self
end

function APTSource:append(o)
  for _,e in ipairs(o.entries) do
    table.insert(self.entries, e)
  end
end

return {
  Source = APTSource,
  Entry = APTSourceEntry
}
