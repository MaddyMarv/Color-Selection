local mod = get_mod("ColorSelection")
local Shared = mod._shared

local CONSTANTS = Shared.CONSTANTS
local _get_is_bot = Shared._get_is_bot
local _get_player_account_id = Shared._get_player_account_id
local apply_nameplate_color = Shared.apply_nameplate_color
local apply_slot_colors = Shared.apply_slot_colors
local flush_pending_apply = Shared.flush_pending_apply
local get_player_by_slot = Shared.get_player_by_slot
local is_in_non_mission_context = Shared.is_in_non_mission_context

mod._last_roster_check_t = 0
local function check_roster_changes(t)
	if
		not mod._in_gameplay_state
		and Managers.state
		and Managers.state.game_mode
		and not is_in_non_mission_context()
	then
		mod._in_gameplay_state = true
	end
	if not mod._in_gameplay_state or is_in_non_mission_context() then
		return
	end
	local now = t or os.clock()
	if now - mod._last_roster_check_t < CONSTANTS.PLAYER_CHECK_INTERVAL then
		return
	end
	mod._last_roster_check_t = now

	local pm = Managers and Managers.player
	if not pm then
		return
	end

	local changed = false
	if not mod._known_slot_account_ids then
		mod._known_slot_account_ids = {}
	end

	for slot = 1, 4 do
		local player = get_player_by_slot(slot)
		local account_id = nil
		if player then
			local success, id = pcall(_get_player_account_id, player)
			if success and id and id ~= "" then
				account_id = id
			end
		end

		local is_bot = player and _get_is_bot(player)
		local norm = account_id
			or (is_bot and ("bot_" .. tostring(slot)))
			or (player and ("player_" .. tostring(slot)))
			or "empty"
		if mod._known_slot_account_ids[slot] ~= norm then
			mod._known_slot_account_ids[slot] = norm
			changed = true
		end
	end

	if changed and apply_slot_colors then
		apply_slot_colors()
	end
end

local nameplate_marker_types = {}

local function is_nameplate_marker_type(marker_type)
	local known = nameplate_marker_types[marker_type]
	if known == nil then
		known = type(marker_type) == "string"
				and (string.find(marker_type, "nameplate", 1, true) or string.find(marker_type, "companion", 1, true))
				and true
			or false
		nameplate_marker_types[marker_type] = known
	end
	return known
end

mod:hook_safe("HudElementNameplates", "update", function(self, dt, t, ui_renderer)
	if not mod:is_enabled() then
		return
	end

	check_roster_changes(t)

	if flush_pending_apply then
		flush_pending_apply()
	end

	if not Managers or not Managers.ui then
		return
	end

	local ui_manager = Managers.ui
	local hud = ui_manager._hud
	if not hud then
		return
	end

	local world_markers = hud.element and hud:element("HudElementWorldMarkers")
	if not world_markers or not world_markers._markers_by_type then
		return
	end

	for marker_type, bucket in pairs(world_markers._markers_by_type) do
		if is_nameplate_marker_type(marker_type) then
			for _, marker in pairs(bucket) do
				apply_nameplate_color(marker)
			end
		end
	end
end)

Shared.check_roster_changes = check_roster_changes
