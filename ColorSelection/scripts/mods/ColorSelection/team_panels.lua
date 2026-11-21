local mod = get_mod("ColorSelection")
local Shared = mod._shared

local ICON_STYLE_KEYS = Shared.ICON_STYLE_KEYS
local _get_player_account_id = Shared._get_player_account_id
local _get_player_slot = Shared._get_player_slot
local get_color_for_account_id = Shared.get_color_for_account_id
local get_player_by_slot = Shared.get_player_by_slot
local is_in_non_mission_context = Shared.is_in_non_mission_context
local settings = Shared.settings
local should_color_names = Shared.should_color_names

local function apply_color_to_name_only(text, color)
	if not text or type(text) ~= "string" or not color then
		return text
	end

	local c = color
	local target_color_tag = string.format("{#color(%d,%d,%d)}", c[2], c[3], c[4])
	local stripped_text = text:gsub("^{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}$", "")

	return target_color_tag .. stripped_text .. "{#reset()}"
end

local function apply_widget_color(panel)
	if not panel or not panel._widgets_by_name then
		return
	end

	local player = panel._player
	if not player and panel._data then
		player = panel._data.player
	end

	local slot = nil
	local account_id = nil

	if player then
		local success, result = pcall(_get_player_slot, player)
		if success and result then
			slot = result
		end

		local id_success, id_result = pcall(_get_player_account_id, player)
		if id_success and id_result then
			account_id = id_result
		end

		if slot and not panel._player_slot then
			panel._player_slot = slot
		end
	else
		slot = panel._player_slot
		if slot then
			player = get_player_by_slot(slot)
			if player then
				local success, result = pcall(_get_player_account_id, player)
				if success then
					account_id = result
				end
			end
		end
	end

	if not slot then
		return
	end

	local color = get_color_for_account_id(account_id, slot)

	if account_id and color and not is_in_non_mission_context() then
		mod._mission_color_cache = mod._mission_color_cache or {}
		mod._mission_color_cache[account_id] = color
	end

	local class_icon = panel._widgets_by_name.class_icon or panel._widgets_by_name.character_portrait
	if class_icon and class_icon.style and color then
		for i = 1, #ICON_STYLE_KEYS do
			local style_pass = class_icon.style[ICON_STYLE_KEYS[i]]
			if style_pass then
				local c = style_pass.color or style_pass.text_color
				if
					c
					and type(c) == "table"
					and (c[1] ~= 255 or c[2] ~= color[2] or c[3] ~= color[3] or c[4] ~= color[4])
				then
					c[1], c[2], c[3], c[4] = 255, color[2], color[3], color[4]
					class_icon.dirty = true
				end
			end
		end
	end

	local widget = panel._widgets_by_name.player_name
	if not widget or not widget.style or not widget.style.text then
		return
	end

	local is_local = false
	if account_id and mod._local_player_account_id then
		is_local = (account_id == mod._local_player_account_id)
	elseif player and Managers.player then
		is_local = (player == Managers.player:local_player_safe(1))
	elseif slot == 1 and settings.force_local_slot_1 ~= false then
		is_local = true
	end

	local content = widget.content
	local text = content and content.text
	if type(text) ~= "string" then
		return
	end

	if not color or not should_color_names(is_local) then
		panel._cs_name_text = nil
		if string.find(text, "{#", 1, true) then
			local stripped = text:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
			if text ~= stripped then
				content.text = stripped
				widget.dirty = true
				content.dirty = true
			end
		end
		return
	end

	if
		text == panel._cs_name_text
		and panel._cs_r == color[2]
		and panel._cs_g == color[3]
		and panel._cs_b == color[4]
	then
		return
	end

	local new_text = apply_color_to_name_only(text, color)
	panel._cs_name_text = new_text
	panel._cs_r, panel._cs_g, panel._cs_b = color[2], color[3], color[4]
	if new_text ~= text then
		content.text = new_text
		widget.dirty = true
	end
end

local function alias_ability_bar_widget(panel)
	local w = panel and panel._widgets_by_name
	if not w then
		return
	end
	if w.ability_bar then
		w.ability_bar_widget = w.ability_bar
	elseif not w.ability_bar_widget then
		w.ability_bar_widget = {
			visible = false,
			dirty = false,
			style = { texture = { color = { 255, 255, 255, 255 }, size = { 0, 0 } } },
		}
	end
end

mod:hook_safe("HudElementPersonalPlayerPanel", "init", function(self)
	alias_ability_bar_widget(self)
end)
mod:hook_safe("HudElementTeamPlayerPanel", "init", function(self)
	alias_ability_bar_widget(self)
end)

mod:hook_safe("HudElementPlayerPanelBase", "destroy", function(self)
	alias_ability_bar_widget(self)
end)

mod:hook_safe("HudElementPersonalPlayerPanelHub", "update", function(self)
	if mod:is_enabled() then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementPersonalPlayerPanelHub", "_set_player_name", function(self)
	if mod:is_enabled() then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementPersonalPlayerPanel", "update", function(self)
	if mod:is_enabled() then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementTeamPlayerPanel", "update", function(self)
	if mod:is_enabled() then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementTeamPlayerPanelHub", "update", function(self)
	if mod:is_enabled() then
		local player = self._player
		if not player and self._data then
			player = self._data.player
		end

		if player then
			local account_id = nil
			local id_success, id_result = pcall(_get_player_account_id, player)
			if id_success and id_result then
				account_id = id_result
			end

			local color = get_color_for_account_id(account_id)

			local class_icon = self._widgets_by_name
				and (self._widgets_by_name.class_icon or self._widgets_by_name.character_portrait)
			if class_icon and class_icon.style and color then
				for i = 1, #ICON_STYLE_KEYS do
					local style_pass = class_icon.style[ICON_STYLE_KEYS[i]]
					if style_pass then
						local c = style_pass.color or style_pass.text_color
						if
							c
							and type(c) == "table"
							and (c[1] ~= 255 or c[2] ~= color[2] or c[3] ~= color[3] or c[4] ~= color[4])
						then
							c[1], c[2], c[3], c[4] = 255, color[2], color[3], color[4]
							class_icon.dirty = true
						end
					end
				end
			end

			local widget = self._widgets_by_name and self._widgets_by_name.player_name

			local is_local = false
			if account_id and mod._local_player_account_id then
				is_local = (account_id == mod._local_player_account_id)
			elseif player and Managers.player then
				is_local = (player == Managers.player:local_player_safe(1))
			end

			local content = widget and widget.content
			local text = content and content.text
			if type(text) ~= "string" then
				return
			end

			if not color or not should_color_names(is_local) then
				self._cs_name_text = nil
				if string.find(text, "{#", 1, true) then
					local stripped = text:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
					if text ~= stripped then
						content.text = stripped
						widget.dirty = true
					end
				end
				return
			end

			if
				not self.tl_modified
				and not self.wru_modified
				and not (
					text == self._cs_name_text
					and self._cs_r == color[2]
					and self._cs_g == color[3]
					and self._cs_b == color[4]
				)
			then
				local new_text = apply_color_to_name_only(text, color)
				self._cs_name_text = new_text
				self._cs_r, self._cs_g, self._cs_b = color[2], color[3], color[4]
				if new_text ~= text then
					content.text = new_text
					widget.dirty = true
				end
			end
		end
	end
end)

local function colourise_team_panels(handler)
	if not mod:is_enabled() then
		return
	end
	local panels = handler and handler._player_panels_array
	if not panels then
		return
	end
	for i = 1, #panels do
		local p = panels[i] and panels[i].panel
		if p then
			apply_widget_color(p)
		end
	end
end

mod:hook_safe("HudElementTeamPanelHandler", "update", function(self)
	colourise_team_panels(self)
end)

local function install_player_panel_hooks(base)
	if not base then
		return
	end

	mod:hook_safe(base, "update", function(self, dt, t, ui_renderer)
		if mod:is_enabled() and self._widgets_by_name and self._widgets_by_name.player_name then
			apply_widget_color(self)
		end
	end)

	mod:hook_safe(base, "_update_player_name_prefix", function(self)
		if not mod:is_enabled() then
			return
		end
		if self._colors_revision ~= mod._colors_revision then
			self._colors_revision = mod._colors_revision
			self._player_slot = nil

			apply_widget_color(self)
		end
	end)

	mod:hook_safe(base, "_set_player_name", function(self)
		if not mod:is_enabled() then
			return
		end
		apply_widget_color(self)
	end)

	mod:hook_safe(base, "_update_player_features", function(self, dt, t, player, ui_renderer)
		if player then
			self._player = player

			local success, slot = pcall(_get_player_slot, player)
			if success and slot then
				self._player_slot = slot
			end
		end
		apply_widget_color(self)
	end)

	mod:hook_safe(base, "init", function(self, parent, draw_layer, scale, data)
		if data and data.player then
			local player = data.player
			if player then
				local success, slot = pcall(_get_player_slot, player)
				if success and slot then
					self._player_slot = slot
				end
			end
		end

		apply_widget_color(self)
	end)
end

mod:hook_require("scripts/ui/hud/elements/player_panel_base/hud_element_player_panel_base", function(B)
	install_player_panel_hooks(B)
end)

Shared.apply_widget_color = apply_widget_color
Shared.colourise_team_panels = colourise_team_panels
