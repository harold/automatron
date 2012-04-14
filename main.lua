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

local attenuation = 1.0

local sin_values = {}
local sin_res = 16
for i = 0, (sin_res-1) do
  table.insert( sin_values, {i/sin_res,math.sin(i/sin_res*3.141)} )
end
table.insert( sin_values, {0.99,0} )
rprint( sin_values )

local shapes = {
  rampUp = {
    values = {{0,0},{0.99,1}}
  },
  rampDown = {
    values = {{0,1},{0.99,0}}
  },
  sqUp = {
    values = {{0,0},{0.5,0},{0.51,1},{.99,1}}
  },
  sqDown = {
    values = {{0,1},{0.5,1},{0.51,0},{.99,0}}
  },
  tri = {
    values = {{0,0},{0.5,1},{0.99,0}}
  },
  vee = {
    values = {{0,1},{0.5,0},{0.99,1}}
  },
  on = {
    values = {{0,1},{0.99,1}}
  },
  sin = {
    values = sin_values
  },
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

  for i in ipairs(shapes[shape].values) do
    local point = shapes[shape].values[i]
    automation:add_point_at(current_line+step*point[1],point[2]*attenuation);
  end
  rs.selected_line_index = (current_line+step)%rs.selected_pattern.number_of_lines
end

local function show_dialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  vb = renoise.ViewBuilder()
  local content = vb:column {
    margin = 10,
    spacing = 2,
    vb:row {
      spacing = 10,
      vb:column {
        spacing = 2,
        vb:row {
          spacing = 2,
          vb:bitmap {
            bitmap = "images/ramp-up.png",
            notifier = function() insert("rampUp") end
          },

          vb:bitmap {
            bitmap = "images/ramp-down.png",
            notifier = function() insert("rampDown") end
          },

          vb:bitmap {
            bitmap = "images/sq-up.png",
            notifier = function() insert("sqUp") end
          },

          vb:bitmap {
            bitmap = "images/sq-down.png",
            notifier = function() insert("sqDown") end
          },
        },

        vb:row {
          spacing = 2,
          vb:bitmap {
            bitmap = "images/tri.png",
            notifier = function() insert("tri") end
          },

          vb:bitmap {
            bitmap = "images/vee.png",
            notifier = function() insert("vee") end
          },

          vb:bitmap {
            bitmap = "images/on.png",
            notifier = function() insert("on") end
          },

          vb:bitmap {
            bitmap = "images/sin-up.png",
            notifier = function() insert("sin") end
          },
        },
      },
      vb:slider {
        min = 0.0,
        max = 1.0,
        value = 1.0,
        width = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT,
        height = 96,
        notifier = function(value) attenuation = value end
      },
    },
  } 

  dialog = renoise.app():show_custom_dialog(tool_name, content)  
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:"..tool_name.."...",
  invoke = show_dialog  
}

renoise.tool():add_keybinding {
  name = "Global:Tools:" .. tool_name.."...",
  invoke = show_dialog
}

_AUTO_RELOAD_DEBUG = function()
  show_dialog()
end
