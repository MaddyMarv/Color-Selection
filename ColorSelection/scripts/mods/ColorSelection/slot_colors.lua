local mod = get_mod("ColorSelection")
local Shared = mod._shared

local UISettings = require("scripts/settings/ui/ui_settings")

local CONSTANTS = Shared.CONSTANTS
local ColorUtils = Shared.ColorUtils
local _get_player_account_id = Shared._get_player_account_id
local _player_cache = Shared._player_cache
local apply_nameplate_color = Shared.apply_nameplate_color
local apply_widget_color = Shared.apply_widget_color
local colourise_team_panels = Shared.colourise_team_panels
local get_color_for_account_id = Shared.get_color_for_account_id
local get_player_by_account_id = Shared.get_player_by_account_id
local get_player_by_slot = Shared.get_player_by_slot
local is_in_non_mission_context = Shared.is_in_non_mission_context
local refresh_settings = Shared.refresh_settings
local should_color_names = Shared.should_color_names

local apply_slot_colors
local flush_pending_apply
mod._colors_revision = 0

local slot_table
mod._slot_colors_replaced = false

local slot_color_metatable = {
	__index = function(_, k)
		if type(k) ~= "number" or k < 1 then
			return nil
		end
		if is_in_non_mission_context() then
			return nil
		end

		local account_id = nil
		local player = get_player_by_slot(k)
		if player then
			local success, result = pcall(_get_player_account_id, player)
			if success then
				account_id = result
			end
		end
		return get_color_for_account_id(account_id, k)
	end,
}

local function restore_previous()
	if not mod._slot_colors_replaced then
		return
	end
	setmetatable(slot_table, nil)
	table.clear(slot_table)
	slot_table[1] = Color.player_slot_1(255, true)
	slot_table[2] = Color.player_slot_2(255, true)
	slot_table[3] = Color.player_slot_3(255, true)
	slot_table[4] = Color.player_slot_4(255, true)
	mod._slot_colors_replaced = false
	mod._colors_revision = mod._colors_revision + 1
end

local function update_world_markers()
	local ui_manager = Managers and Managers.ui
	if not ui_manager then
		return false
	end

	local hud = ui_manager:get_hud()
	if not hud then
		return false
	end

	local world_markers = hud:element("HudElementWorldMarkers")
	if not world_markers or not world_markers._markers_by_id then
		return false
	end

	for marker_id, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type

		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			marker.wru_modified = false
			marker.tl_modified = false
			marker._cs_last_header = nil
			marker._cs_colored_header = nil
			marker._cs_r = nil
			apply_nameplate_color(marker)
		end
	end

	local rh_mod = get_mod("RingHud")
	if rh_mod and rh_mod:is_enabled() then
		if rh_mod.floating_manager and type(rh_mod.floating_manager.bump_names) == "function" then
			rh_mod.floating_manager.bump_names()
		end
		local hewm = rawget(rh_mod, "_hewm_world_markers")
		local list = hewm and hewm._markers_by_type and hewm._markers_by_type.ringhud_teammate_tile
		if list then
			local function each(tbl, fn)
				if #tbl > 0 then
					for i = 1, #tbl do
						fn(tbl[i])
					end
				else
					for _, v in pairs(tbl) do
						fn(v)
					end
				end
			end
			each(list, function(marker)
				if marker then
					marker._state_accum = 1
					marker._last_state_hash = -1
				end
			end)
		end
	end

	return true
end

local function update_player_panel_colors()
	local ui_manager = Managers and Managers.ui
	if not ui_manager or not ui_manager._hud then
		return false
	end

	local hud = ui_manager._hud
	local elements_array = hud._elements_array
	if not elements_array then
		return false
	end

	for i = 1, #elements_array do
		local element = elements_array[i]
		if element then
			local class_name = element.__class_name
			if class_name == "HudElementPersonalPlayerPanel" or class_name == "HudElementPersonalPlayerPanelHub" then
				element.wru_modified = false
				element.tl_modified = false
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPlayerPanel" or class_name == "HudElementTeamPlayerPanelHub" then
				element.wru_modified = false
				element.tl_modified = false
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPanelHandler" then
				if element._player_panels_array then
					for _, data in ipairs(element._player_panels_array) do
						if data.panel then
							data.panel.wru_modified = false
							data.panel.tl_modified = false
						end
					end
				end
				colourise_team_panels(element)
			end
		end
	end

	update_world_markers()

	return true
end

local apply_slot_colors_internal
local _last_apply_time = 0
local _pending_apply = false
local is_applying_colors = false

apply_slot_colors = function(force)
	refresh_settings()
	if not mod:is_enabled() then
		return
	end
	local now = os.clock()
	if is_applying_colors then
		_pending_apply = true
		return
	end

	if not force and (now - _last_apply_time < 0.05) then
		_pending_apply = true
		return
	end

	_last_apply_time = now
	_pending_apply = false
	is_applying_colors = true
	apply_slot_colors_internal()
	is_applying_colors = false
end

flush_pending_apply = function()
	if _pending_apply and (os.clock() - _last_apply_time >= 0.05) then
		apply_slot_colors(true)
	end
end

apply_slot_colors_internal = function()
	if not UISettings then
		return
	end

	_player_cache.last_update = 0

	if not mod._slot_colors_replaced then
		slot_table = UISettings.player_slot_colors or {}
		UISettings.player_slot_colors = slot_table
		mod._slot_colors_replaced = true
	end

	local current_table = slot_table
	table.clear(current_table)

	for i = 1, 5 do
		if is_in_non_mission_context() then
			break
		end

		local account_id = nil
		local player = get_player_by_slot(i)
		if player then
			local success, result = pcall(_get_player_account_id, player)
			if success then
				account_id = result
			end
		end

		local color = get_color_for_account_id(account_id, i)
		if color then
			current_table[i] = color
		end
	end

	setmetatable(current_table, slot_color_metatable)

	mod._colors_revision = mod._colors_revision + 1
	UISettings._colors_revision = (UISettings._colors_revision or 0) + 1
	update_player_panel_colors()

	local debug_enabled = mod:get("debug_mode")
	if debug_enabled then
		mod:info("[ColorSelection] Slot colors applied successfully")
	end
end

mod.apply_slot_colors = apply_slot_colors
mod.update_player_panel_colors = update_player_panel_colors
mod.ColorUtils = ColorUtils
mod.CONSTANTS = CONSTANTS
mod.get_player_by_account_id = get_player_by_account_id
mod.get_player_by_slot = get_player_by_slot
mod.get_color_for_account_id = get_color_for_account_id
mod.should_color_names = should_color_names

Shared.apply_slot_colors = apply_slot_colors
Shared.flush_pending_apply = flush_pending_apply
Shared.restore_previous = restore_previous
Shared.update_player_panel_colors = update_player_panel_colors
