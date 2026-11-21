local mod = get_mod("ColorSelection")
local Shared = mod._shared

local _get_mechanism_name = Shared._get_mechanism_name
local _get_mission_name = Shared._get_mission_name
local _get_player_account_id = Shared._get_player_account_id
local _get_player_profile = Shared._get_player_profile
local _get_player_slot = Shared._get_player_slot
local _is_player_valid = Shared._is_player_valid
local pcall_safe = Shared.pcall_safe
local update_local_player_id = Shared.update_local_player_id

mod._cached_saved_colors = nil
mod._cached_saved_colors_loaded = false

local function _get_cached_saved_colors()
	if not mod._cached_saved_colors_loaded then
		mod._cached_saved_colors = mod:get("saved_player_colors")
		mod._cached_saved_colors_loaded = true
	end
	return mod._cached_saved_colors
end

local FLAG_SETTINGS = {
	"force_local_slot_1",
	"color_bots",
	"color_by_class",
	"color_names",
	"color_local_inside_mission",
	"color_local_outside_mission",
	"color_custom_outside_mission",
	"color_outlines",
	"color_dog_outlines",
	"chat_local_name_style",
}
local settings = {}
local color_cache = {}

local frame_colors = {}
local frame_bot_colors = {}
local frame_context = nil

local function reset_frame_cache()
	table.clear(frame_colors)
	table.clear(frame_bot_colors)
	frame_context = nil
end

local function refresh_settings()
	for i = 1, #FLAG_SETTINGS do
		local id = FLAG_SETTINGS[i]
		settings[id] = mod:get(id)
	end
	table.clear(color_cache)
	reset_frame_cache()
end

refresh_settings()

local ICON_STYLE_KEYS = { "texture", "icon", "class_icon", "text" }

local get_color_for_account_id

local function get_color(prefix)
	local cached = color_cache[prefix]
	if cached then
		return cached
	end

	local color
	local color_array = mod:get(prefix)
	if color_array and type(color_array) == "table" and #color_array >= 3 then
		color = {
			color_array[1] or 255,
			color_array[2] or mod.get_default_color_value(prefix, "r"),
			color_array[3] or mod.get_default_color_value(prefix, "g"),
			color_array[4] or mod.get_default_color_value(prefix, "b"),
		}
	else
		color = {
			255,
			mod.get_default_color_value(prefix, "r"),
			mod.get_default_color_value(prefix, "g"),
			mod.get_default_color_value(prefix, "b"),
		}
	end
	color_cache[prefix] = color
	return color
end

local function get_local_player_slot()
	local pm = Managers and Managers.player
	if pm then
		local local_player = pm:local_player_safe(1)
		if local_player then
			local success, slot = pcall(_get_player_slot, local_player)
			if success and slot then
				return slot
			end
		end
	end
	return 1
end

local function get_slot_color(slot, is_local_player, is_bot)
	local force_slot_1 = settings.force_local_slot_1 ~= false

	if is_local_player and force_slot_1 then
		return get_color("slot1")
	end

	if is_bot then
		if settings.color_bots ~= false then
			return get_color("bot")
		end
	end

	if slot and slot >= 1 and slot <= 4 then
		local lp_slot = get_local_player_slot()
		if force_slot_1 and lp_slot ~= 1 and slot == 1 then
			return get_color("slot" .. lp_slot)
		end
		return get_color("slot" .. slot)
	end

	return nil
end

local function compute_non_mission_context()
	local mechanism_name = nil
	if Managers.mechanism then
		local success, result = pcall(_get_mechanism_name, Managers.mechanism)
		if success then
			mechanism_name = result
		end
	end

	local mission_name = nil
	if Managers.state and Managers.state.mission then
		local success, result = pcall(_get_mission_name, Managers.state.mission)
		if success then
			mission_name = result
		end
	end

	local ui = Managers.ui
	if ui and (ui:view_active("end_view") or ui:view_active("end_player_view")) then
		return false
	end

	if mechanism_name == "left_session" or mechanism_name == "hub" then
		return true
	end

	if mechanism_name == "adventure" then
		return false
	end

	if not mission_name then
		return true
	end

	if mission_name == "hub_ship" then
		return true
	end

	if mechanism_name == "onboarding" and mission_name ~= "tg_shooting_range" then
		return true
	end

	return false
end

local function is_in_non_mission_context()
	if frame_context == nil then
		frame_context = compute_non_mission_context()
	end
	return frame_context
end

local function should_color_names(is_local_player)
	if is_in_non_mission_context() then
		if is_local_player then
			return settings.color_local_outside_mission == true
		else
			return settings.color_custom_outside_mission == true
		end
	else
		if is_local_player then
			return settings.color_local_inside_mission ~= false
		else
			return settings.color_names ~= false
		end
	end
end

local function get_class_color(player)
	if not player then
		return nil
	end
	local profile = pcall_safe(_get_player_profile, player)
	if profile and profile.archetype and profile.archetype.name then
		local archetype = profile.archetype.name
		if
			archetype == "veteran"
			or archetype == "zealot"
			or archetype == "psyker"
			or archetype == "ogryn"
			or archetype == "broker"
			or archetype == "adamant"
			or archetype == "cryptic"
		then
			return get_color(archetype)
		end
	end
	return nil
end

local get_player_by_account_id
local get_player_by_slot
mod._in_gameplay_state = false

local function compute_color_for_account_id(account_id, slot)
	if not mod._local_player_account_id then
		update_local_player_id()
	end

	local saved_colors = _get_cached_saved_colors()
	if saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
		local c = saved_colors[account_id]
		if c and type(c) == "table" then
			if not is_in_non_mission_context() or settings.color_custom_outside_mission then
				return { 255, c.r or 255, c.g or 255, c.b or 255 }
			end
		end
	end

	local is_local = account_id and account_id ~= "" and mod._local_player_account_id == account_id

	if is_in_non_mission_context() and not is_local then
		return nil
	end

	if not account_id or account_id == "" then
		if settings.color_bots ~= false then
			return get_color("bot")
		end
	end

	local player = nil
	if account_id and account_id ~= "" then
		player = get_player_by_account_id(account_id)
	elseif slot then
		local pm = Managers and Managers.player
		if pm then
			local bot_players = pm:bot_players()
			if bot_players then
				for _, p in pairs(bot_players) do
					local success, s = pcall(_get_player_slot, p)
					if success and s == slot then
						player = p
						break
					end
				end
			end
		end
	end

	if not slot then
		local player_slot = nil
		if player then
			local success, s = pcall(_get_player_slot, player)
			if success and s then
				player_slot = s
			end
		end

		if not player_slot then
			if is_local and settings.force_local_slot_1 ~= false then
				slot = 1
			end
		else
			slot = player_slot
		end
	end

	if is_local then
		if not is_in_non_mission_context() or settings.color_local_outside_mission then
			if settings.color_by_class and player and settings.force_local_slot_1 == false then
				local class_color = get_class_color(player)
				if class_color then
					return class_color
				end
			end
			return get_slot_color(slot, true, false)
		end
		return nil
	end

	if settings.color_by_class and player then
		local class_color = get_class_color(player)
		if class_color then
			return class_color
		end
	end

	if not slot then
		return nil
	end

	return get_slot_color(slot, is_local, false)
end

get_color_for_account_id = function(account_id, slot)
	local cache, key
	if account_id and account_id ~= "" then
		cache, key = frame_colors, account_id
	elseif slot then
		cache, key = frame_bot_colors, slot
	else
		return compute_color_for_account_id(account_id, slot)
	end

	local color = cache[key]
	if color == nil then
		color = compute_color_for_account_id(account_id, slot) or false
		cache[key] = color
	end
	return color or nil
end

local _player_cache = {
	by_slot = {},
	by_account_id = {},
	last_update = 0,
}

local function _on_player_removed(player)
	if _player_cache then
		_player_cache.last_update = 0
	end
	if not _is_player_valid(player) then
		return
	end

	local success, account_id = pcall(_get_player_account_id, player)
	if success and account_id and mod._player_custom_colors then
		mod._player_custom_colors[account_id] = nil
	end
end

local function update_player_cache()
	local pm = Managers and Managers.player
	if not pm then
		return
	end

	table.clear(_player_cache.by_slot)
	table.clear(_player_cache.by_account_id)

	local players = pm:players()
	if players then
		for unique_id, player in pairs(players) do
			if _is_player_valid(player) then
				local slot_success, slot = pcall(_get_player_slot, player)
				if slot_success and slot then
					_player_cache.by_slot[slot] = player
				end

				local id_success, account_id = pcall(_get_player_account_id, player)
				if id_success and account_id and account_id ~= "" then
					_player_cache.by_account_id[account_id] = player
				end
			end
		end
	end
	_player_cache.last_update = os.clock()
end

get_player_by_slot = function(slot)
	if not slot then
		return nil
	end

	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end

	local player = _player_cache.by_slot[slot]
	if player and not _is_player_valid(player) then
		update_player_cache()
		player = _player_cache.by_slot[slot]
	end

	return _is_player_valid(player) and player or nil
end

get_player_by_account_id = function(account_id)
	if not account_id then
		return nil
	end

	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end

	local player = _player_cache.by_account_id[account_id]
	if player and not _is_player_valid(player) then
		update_player_cache()
		player = _player_cache.by_account_id[account_id]
	end

	return _is_player_valid(player) and player or nil
end

Shared.ICON_STYLE_KEYS = ICON_STYLE_KEYS
Shared._get_cached_saved_colors = _get_cached_saved_colors
Shared._on_player_removed = _on_player_removed
Shared._player_cache = _player_cache
Shared.get_color = get_color
Shared.get_color_for_account_id = get_color_for_account_id
Shared.get_player_by_account_id = get_player_by_account_id
Shared.get_player_by_slot = get_player_by_slot
Shared.is_in_non_mission_context = is_in_non_mission_context
Shared.refresh_settings = refresh_settings
Shared.reset_frame_cache = reset_frame_cache
Shared.settings = settings
Shared.should_color_names = should_color_names
