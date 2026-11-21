local mod = get_mod("ColorSelection")
local Shared = mod._shared

local _get_cached_saved_colors = Shared._get_cached_saved_colors
local _get_player_account_id = Shared._get_player_account_id
local _get_player_name = Shared._get_player_name
local _get_player_slot = Shared._get_player_slot
local get_color_for_account_id = Shared.get_color_for_account_id
local is_in_non_mission_context = Shared.is_in_non_mission_context
local pcall_safe = Shared.pcall_safe
local should_color_names = Shared.should_color_names

local function apply_nameplate_color(marker)
	if not marker or not marker.widget or not mod:is_enabled() then
		return
	end

	local player = marker.data
	if not player then
		return
	end

	local slot = pcall_safe(_get_player_slot, player)
	local account_id = pcall_safe(_get_player_account_id, player)

	local is_saved_friend = false
	local saved_colors = _get_cached_saved_colors()
	if account_id and saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
		is_saved_friend = true
	end

	local is_local_player = account_id and account_id ~= "" and mod._local_player_account_id == account_id

	if is_in_non_mission_context() and not is_saved_friend and not is_local_player then
		return
	end

	local marker_type = marker.type
	if not is_saved_friend and not is_local_player and marker_type and string.find(marker_type, "hub", 1, true) then
		local widget = marker.widget
		local content = widget and widget.content
		if content then
			local changed = false
			if content.header_text and string.find(content.header_text, "{#color", 1, true) then
				local name_part, title_part = content.header_text:match("^([^\n]*)\n?(.*)$")
				if not name_part then
					name_part = content.header_text
					title_part = ""
				end

				local stripped_name = name_part:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")

				local new_header = stripped_name
				if title_part and title_part ~= "" then
					new_header = new_header .. "\n" .. title_part
				end

				if content.header_text ~= new_header then
					content.header_text = new_header
					changed = true
				end
			end
			if content.icon_text and string.find(content.icon_text, "{#color", 1, true) then
				local stripped_icon = content.icon_text:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
				if content.icon_text ~= stripped_icon then
					content.icon_text = stripped_icon
					changed = true
				end
			end

			if changed then
				widget.dirty = true
				content.dirty = true
			end
			marker._cs_is_reset = true
			marker._cs_colored_header = nil
			marker._cs_r = nil
		end
		return
	end

	local color = get_color_for_account_id(account_id, slot)

	local widget = marker.widget
	local content = widget and widget.content

	if not color then
		if is_local_player and is_in_non_mission_context() then
			return
		end
		if content then
			local changed = false
			if content.header_text and string.find(content.header_text, "{#color", 1, true) then
				local name_part, title_part = content.header_text:match("^([^\n]*)\n?(.*)$")
				if not name_part then
					name_part = content.header_text
					title_part = ""
				end

				local stripped_name = name_part:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")

				local new_header = stripped_name
				if title_part and title_part ~= "" then
					new_header = new_header .. "\n" .. title_part
				end

				if content.header_text ~= new_header then
					content.header_text = new_header
					changed = true
				end
			end
			if content.icon_text and string.find(content.icon_text, "{#color", 1, true) then
				local stripped_icon = content.icon_text:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
				if content.icon_text ~= stripped_icon then
					content.icon_text = stripped_icon
					changed = true
				end
			end

			if changed then
				widget.dirty = true
				content.dirty = true
			end
			marker._cs_is_reset = true
			marker._cs_colored_header = nil
			marker._cs_r = nil
		end
		return
	end

	local is_companion = marker.type and string.find(marker.type, "companion", 1, true)

	if not content or (not content.header_text and not content.icon_text) then
		return
	end

	local color_names = should_color_names(is_local_player)

	if
		marker._cs_r == color[2]
		and marker._cs_g == color[3]
		and marker._cs_b == color[4]
		and marker._cs_colored_header == (content.header_text or "")
		and marker._cs_icon_text == content.icon_text
		and marker._cs_color_names == color_names
	then
		local skip = true
		if widget and widget.style then
			local icon_style = widget.style.icon or widget.style.class_icon
			if icon_style and icon_style.color then
				local c = icon_style.color
				if c[2] ~= color[2] or c[3] ~= color[3] or c[4] ~= color[4] then
					skip = false
				end
			end
		end
		if skip then
			return
		end
	end

	local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
	local changed = false

	if widget and widget.style then
		local icon_style = widget.style.icon or widget.style.class_icon
		if icon_style and icon_style.color then
			local c = icon_style.color
			if c[2] ~= color[2] or c[3] ~= color[3] or c[4] ~= color[4] then
				c[1], c[2], c[3], c[4] = 255, color[2], color[3], color[4]
				changed = true
			end
		end
	end

	if content.header_text and type(content.header_text) == "string" then
		if not color_names then
			local stripped_header = content.header_text:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
			if content.header_text ~= stripped_header then
				content.header_text = stripped_header
				marker._cs_last_header = nil
				marker._cs_colored_header = stripped_header
				changed = true
			end
		else
			local header = content.header_text

			if is_companion then
				local companion_glyph = ""
				local stripped_header = header:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
				local companion_name = stripped_header:match(companion_glyph .. "%s*(.-)$")
					or stripped_header:match("%s*(.-)$")
					or stripped_header

				local new_header = color_tag .. companion_glyph .. "{#reset()} " .. companion_name
				if content.header_text ~= new_header then
					content.header_text = new_header
					marker._cs_last_header = nil
					marker._cs_colored_header = new_header
					changed = true
				end
			else
				local player_name = pcall_safe(_get_player_name, player)
				if not player_name or player_name == "" then
					local name_part = header:match("^([^\n]*)")
					player_name = name_part and name_part:match("%w+") or header:match("%w+") or header
				end

				player_name = player_name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")

				local name_part, title_part = header:match("^([^\n]*)\n?(.*)$")
				if not name_part then
					name_part = header
					title_part = ""
				end

				local clean_name_part = name_part:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
				local name_start, name_end = nil, nil
				if player_name ~= "" then
					name_start, name_end = clean_name_part:find(player_name, 1, true)
				end

				local new_name_part = nil
				if name_start then
					local before_name = clean_name_part:sub(1, name_start - 1)
					local after_name = clean_name_part:sub(name_end + 1)
					new_name_part = color_tag .. before_name .. player_name .. "{#reset()}" .. after_name
				elseif clean_name_part ~= "" then
					new_name_part = color_tag .. clean_name_part .. "{#reset()}"
				end

				if new_name_part then
					local new_header = new_name_part
					if title_part and title_part ~= "" then
						new_header = new_header .. "\n" .. title_part
					end

					if content.header_text ~= new_header then
						content.header_text = new_header
						marker._cs_last_header = nil
						marker._cs_colored_header = new_header
						changed = true
					end
				end
			end
		end
	end

	if content.icon_text then
		local stripped_icon = content.icon_text:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
		if stripped_icon ~= "" then
			local new_icon = color_tag .. stripped_icon .. "{#reset()}"
			if content.icon_text ~= new_icon then
				content.icon_text = new_icon
				changed = true
			end
		end
	end

	marker._cs_r, marker._cs_g, marker._cs_b = color[2], color[3], color[4]
	marker._cs_colored_header = content.header_text or ""
	marker._cs_icon_text = content.icon_text
	marker._cs_color_names = color_names

	if changed then
		marker._cs_is_reset = false

		if widget then
			widget.dirty = true
			if widget.content then
				widget.content.dirty = true
			end
		end
	end
end

local nameplate_template_path = "scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate"
mod:hook_require(nameplate_template_path, function(template)
	if not template then
		return
	end

	if template.on_enter then
		template.__cs_original_on_enter = template.__cs_original_on_enter or template.on_enter
		local original_on_enter = template.__cs_original_on_enter
		template.on_enter = function(widget, marker)
			original_on_enter(widget, marker)

			if mod:is_enabled() and marker and marker.data then
				if marker.widget and marker.widget.content and marker.widget.content.header_text then
					apply_nameplate_color(marker)
				end
			end
		end
	end
end)

local companion_templates = {
	"scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate_companion",
	"scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate_companion_hub",
}

for _, template_path in ipairs(companion_templates) do
	mod:hook_require(template_path, function(template)
		if not template or not template.on_enter then
			return
		end

		template.__cs_original_on_enter = template.__cs_original_on_enter or template.on_enter
		local original_on_enter = template.__cs_original_on_enter
		template.on_enter = function(widget, marker)
			original_on_enter(widget, marker)

			if not mod:is_enabled() or not marker or not marker.data then
				return
			end

			local data = marker.data
			local content = widget.content
			if not content then
				return
			end

			local player_slot = pcall_safe(_get_player_slot, data)
			local account_id = pcall_safe(_get_player_account_id, data)

			local current_header = content.header_text or ""
			if current_header == "" then
				return
			end

			local color = get_color_for_account_id(account_id, player_slot)
			if color then
				local color_string = "{#color(" .. color[2] .. "," .. color[3] .. "," .. color[4] .. ")}"
				local companion_glyph = ""

				if content.icon_text then
					content.icon_text = color_string .. companion_glyph .. "{#reset()}"
				end

				if should_color_names(false) and content.header_text and content.header_text ~= "" then
					local header = content.header_text
					local companion_name = header:match(companion_glyph .. "%s*(.-)$") or header:match("%s*(.-)$")
					if companion_name then
						content.header_text = color_string .. companion_glyph .. "{#reset()} " .. companion_name
					end
				end

				widget.dirty = true
				if content then
					content.dirty = true
				end
			end
		end
	end)
end

mod:hook_safe("HudElementWorldMarkers", "event_add_world_marker_unit", function(self, marker_type, unit, callback, data)
	if not mod:is_enabled() then
		return
	end

	if
		marker_type
		and (string.find(marker_type, "nameplate", 1, true) or string.find(marker_type, "companion", 1, true))
	then
		local by_type = self._markers_by_type
		if by_type then
			for type_key, bucket in pairs(by_type) do
				if
					type(type_key) == "string"
					and (string.find(type_key, "nameplate", 1, true) or string.find(type_key, "companion", 1, true))
				then
					for _, marker in pairs(bucket) do
						if marker.unit == unit and marker.widget and marker.widget.content then
							apply_nameplate_color(marker)
							break
						end
					end
				end
			end
		end
	end
end)

Shared.apply_nameplate_color = apply_nameplate_color
