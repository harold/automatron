-- I love you. Don't judge.
local dialog = nil
local vb = nil

-- Read from the manifest.xml file.
class "RenoiseScriptingTool" (renoise.Document.DocumentNode)
function RenoiseScriptingTool:__init()    
  renoise.Document.DocumentNode.__init(self) 
  self:add_property("Name", "Untitled Tool")
  self:add_property("Id", "Unknown Id")
end

local manifest  = RenoiseScriptingTool()
local ok,err    = manifest:load_from("manifest.xml")
local tool_name = manifest:property("Name").value
local tool_id   = manifest:property("Id").value

local offset = 0.0
local attenuation = 1.0
local time_mult = 1
local input_divisor = 1

-- calculated shapes
local res = 16
local sin_values = {}
local circBr_values = {}
local circTr_values = {}
local circTl_values = {}
local circBl_values = {}
local cosUp_values = {}
local cosDown_values = {}
for i = 0, (res-1) do
  local x = i/res
  table.insert( sin_values, {x,math.sin(x*3.141)} )
  table.insert( circBr_values, {x,1-math.sqrt(1-x*x)} )
  table.insert( circTr_values, {x,math.sqrt(1-x*x)} )
  table.insert( circTl_values, {x,math.sqrt(2*x-x*x)} )
  table.insert( circBl_values, {x,1-math.sqrt(2*x-x*x)} )
  table.insert( cosUp_values, {x,1-(0.5*math.cos(x*3.14)+0.5)} )
  table.insert( cosDown_values, {x,0.5*math.cos(x*3.14)+0.5} )
end
table.insert( sin_values, {0.99,0} )
table.insert( circBr_values, {0.99,1} )
table.insert( circTr_values, {0.99,0} )
table.insert( circTl_values, {0.99,1} )
table.insert( circBl_values, {0.99,0} )
table.insert( cosUp_values, {0.99,1} )
table.insert( cosDown_values, {0.99,0} )

local shapes = {
  rampUp    = { values = {{0,0},{0.99,1}} },
  rampDown  = { values = {{0,1},{0.99,0}} },
  sqUp      = { values = {{0,0},{0.5,0},{0.51,1},{.99,1}} },
  sqDown    = { values = {{0,1},{0.5,1},{0.51,0},{.99,0}} },
  tri       = { values = {{0,0},{0.5,1},{0.99,0}} },
  vee       = { values = {{0,1},{0.5,0},{0.99,1}} },
  on        = { values = {{0,1},{0.99,1}} },
  sin       = { values = sin_values },
  circBr    = { values = circBr_values },
  circTr    = { values = circTr_values },
  circTl    = { values = circTl_values },
  circBl    = { values = circBl_values },
  stairUp   = { values = {{0,0},{0.25,0},{0.26,0.25},
                         {0.5,0.25},{0.51,0.5},{0.75,0.5},{0.76,0.75},{0.98,0.75},{0.99,1}} },
  stairDown = { values = {{0,1},{0.25,1},{0.26,0.75},
                         {0.5,0.75},{0.51,0.5},{0.75,0.5},{0.76,0.25},{0.98,0.25},{0.99,0}} },
  cosUp     = { values = cosUp_values },
  cosDown   = { values = cosDown_values },
}

local shape_names = {}
for k, _ in pairs(shapes) do table.insert(shape_names,shapes[k].name) end
local selected_shape = 1
local button_size = #shapes*40

local function insert( shape )
  renoise.app().window.active_lower_frame=renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
  local rs = renoise.song()
  local track = rs.selected_pattern_track
  local automation = track:find_automation(rs.selected_parameter)
  local current_line = rs.selected_line_index
  if (automation == nil) then
    automation = track:create_automation(rs.selected_parameter)
  end

  local step = rs.transport.edit_step
  step = math.floor( step * time_mult )
  local old_points = automation.points
  local new_points = {}
  for _, v in pairs(old_points) do
    if v.time >= current_line and v.time < current_line+step then
      -- nop (don't copy)
    else
      table.insert( new_points, v )
    end
  end
  automation.points = new_points

  for slice = 0, (input_divisor-1) do
    local start = slice/input_divisor*step
    for i in ipairs(shapes[shape].values) do
      local point = shapes[shape].values[i]
      local time = current_line + start + step*point[1]*(1/input_divisor)
      local val = offset + ((1-offset)*point[2])*attenuation
      automation:add_point_at(time,val);
    end
  end
  local new_line = current_line+step
  while new_line > rs.selected_pattern.number_of_lines do
    new_line = new_line - rs.selected_pattern.number_of_lines
  end
  rs.selected_line_index = new_line
end

local key_map = {}
local function make_button( builder, img, shape, key )
  key_map[key] = shape
  return builder:bitmap{ bitmap=img, notifier=function() insert(shape) end }
end

local function show_dialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  vb = renoise.ViewBuilder()
  local content = vb:column {
    margin = 10,
    spacing = 4,
    vb:row { vb:text { text="Shapes and attenuation:" } },
    vb:row {
      spacing = 4,
      vb:column {
        spacing = 4,
        vb:row {
          spacing = 4,
          make_button( vb, "images/ramp-up.png",   "rampUp",   "q" ),
          make_button( vb, "images/ramp-down.png", "rampDown", "w" ),
          make_button( vb, "images/circ-tl.png",   "circTl",   "e" ),
          make_button( vb, "images/circ-tr.png",   "circTr",   "r" ),
          make_button( vb, "images/sq-up.png",     "sqUp",     "t" ),
          make_button( vb, "images/sq-down.png",   "sqDown",   "y" ),
        },

        vb:row {
          spacing = 4,
          make_button( vb, "images/tri.png", "tri",        "a" ),
          make_button( vb, "images/vee.png", "vee",        "s" ),
          make_button( vb, "images/circ-bl.png", "circBl", "d" ),
          make_button( vb, "images/circ-br.png", "circBr", "f" ),
          make_button( vb, "images/sin-up.png", "sin",     "g" ),
        },

        vb:row {
          spacing = 4,
          make_button( vb, "images/stair-up.png", "stairUp",     "z" ),
          make_button( vb, "images/stair-down.png", "stairDown", "x" ),
          make_button( vb, "images/cos-up.png", "cosUp",         "c" ),
          make_button( vb, "images/cos-down.png", "cosDown",     "v" ),
          make_button( vb, "images/on.png", "on",                "b" ),
        },
      },
      vb:minislider {
        min = 0.0,
        max = 1.0,
        value = 0.0,
        width = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT,
        height = 152,
        notifier = function(value) offset = value end
      },
      vb:minislider {
        min = 0.0,
        max = 1.0,
        value = 1.0,
        width = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT,
        height = 152,
        notifier = function(value) attenuation = value end
      },
    },
    vb:row { vb:text { text="Time dilation:" } },
    vb:row {
      vb:switch {
        width = 308,
        value = 3,
        items = {"/4", "/2", "edit step", "*2", "*4"},
        notifier = function(new_index)
          if new_index == 1 then time_mult = 0.25 end
          if new_index == 2 then time_mult = 0.50 end
          if new_index == 3 then time_mult = 1 end
          if new_index == 4 then time_mult = 2 end
          if new_index == 5 then time_mult = 4 end
        end
      }
    },
    vb:row { vb:text { text="Input divisor:" } },
    vb:row {
      vb:switch {
        width = 308,
        value = 1,
        items = {"1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x"},
        notifier = function( val ) input_divisor = val end
      }
    },
  }

  dialog = renoise.app():show_custom_dialog(tool_name, content, my_key_handler)
end

function my_key_handler( dialog, key )
  local rs = renoise.song()
  local current_line = rs.selected_line_index
  local step = math.floor(rs.transport.edit_step * time_mult)
  local num_lines = rs.selected_pattern.number_of_lines

  if key.name == "left" or key.name == "up" then
    if key.modifiers == "control" then step = 1 end
    local new_line = rs.selected_line_index - step
    while new_line < 1 do new_line = new_line + num_lines end
    rs.selected_line_index = new_line
  end

  if key.name == "right" or key.name == "down" then
    if key.modifiers == "control" then step = 1 end
    local new_line = rs.selected_line_index + step
    while new_line > num_lines do new_line = new_line - num_lines  end
    rs.selected_line_index = new_line
  end

  if key.name == "f9" then rs.selected_line_index = 1 end
  if key.name == "f10" then rs.selected_line_index = math.ceil(num_lines*0.25)+1 end
  if key.name == "f11" then rs.selected_line_index = math.ceil(num_lines*0.50)+1 end
  if key.name == "f12" then rs.selected_line_index = math.ceil(num_lines*0.75)+1 end

  if key_map[key.name] then insert(key_map[key.name]) end

  return key
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:"..tool_name.."...",
  invoke = show_dialog  
}

renoise.tool():add_menu_entry {
 name = "Track Automation:"..tool_name.."...",
 invoke = show_dialog
}

renoise.tool():add_keybinding {
  name = "Global:Tools:" .. tool_name.."...",
  invoke = show_dialog
}

_AUTO_RELOAD_DEBUG = function()
  show_dialog()
end
