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

local shapes = {
  { 
    name = "square",
    values = {{0,0},{0.5,0},{0.51,1},{.99,1}}
  },
  { 
    name = "ramp",
    values = {{0,0},{0.99,1}}
  },
  { 
    name = "tri",
    values = {{0,0},{0.5,1},{0.99,0}}
  },
  { 
    name = "vee",
    values = {{0,1},{0.5,0},{0.99,1}}
  }
}
local shape_names = {}
for k, _ in pairs(shapes) do table.insert(shape_names,shapes[k].name) end
local selected_shape = 1
local button_size = #shapes*40

local function show_dialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  vb = renoise.ViewBuilder()
  local content = vb:column {
    margin = 10,
    vb:switch {
      width = button_size,
      id = "switch",
      items = shape_names,
      notifier = function(new_index)
        selected_shape = new_index
      end
    },
    vb:button {
      width = button_size,
      id = "insert",
      text = "insert",
      notifier = function()
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

        for i in ipairs(shapes[selected_shape].values) do
          local point = shapes[selected_shape].values[i]
          automation:add_point_at(current_line+step*point[1],point[2]);
        end
        rs.selected_line_index = (current_line+step)%rs.selected_pattern.number_of_lines
      end
    }
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
