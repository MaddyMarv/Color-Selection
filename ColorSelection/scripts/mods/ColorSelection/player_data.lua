local mod = get_mod("ColorSelection")
local Shared = mod._shared

local CONSTANTS = {
	MAX_PLAYERS_PER_PAGE = 14,
	MAX_COLOR_VALUE = 255,
	UUID_LENGTH_WITH_HYPHENS = 36,
	UUID_LENGTH_WITHOUT_HYPHENS = 32,
	SLIDER_HOLD_DELAY = 0.5,
	PLAYER_CHECK_INTERVAL = 1.0,
	SWATCH_SIZE = { 30, 20 },
	LINE_HEIGHT = 30,
}

local ColorUtils = {}

local function _is_player_valid(p)
	return p ~= nil and not rawget(p, "__deleted")
end

local function _call_slot(p)
	return p:slot()
end
local function _call_account_id(p)
	return p:account_id()
end
local function _call_name(p)
	return p:name()
end
local function _call_profile(p)
	return p:profile()
end
local function _call_user_display_name(p)
	return p:user_display_name(nil, true)
end
local function _call_is_bot(p)
	return (p.type and p:type() == "BotPlayer") or not p:is_human_controlled()
end

local function _get_player_slot(p)
	if not _is_player_valid(p) then
		return nil
	end
	local s, r = pcall(_call_slot, p)
	return s and r or nil
end
local function _get_player_account_id(p)
	if not _is_player_valid(p) then
		return nil
	end
	local s, r = pcall(_call_account_id, p)
	return s and r or nil
end
local function _get_player_name(p)
	if not _is_player_valid(p) then
		return nil
	end
	local s, r = pcall(_call_name, p)
	return s and r or nil
end
local function _get_player_profile(p)
	if not _is_player_valid(p) then
		return nil
	end
	local s, r = pcall(_call_profile, p)
	return s and r or nil
end
local function _get_user_display_name(p)
	if not _is_player_valid(p) then
		return nil
	end
	local s, r = pcall(_call_user_display_name, p)
	return s and r or nil
end
local function _set_vector3_for_materials(unit, param, color, val)
	if Unit and Unit.set_vector3_for_materials then
		Unit.set_vector3_for_materials(unit, param, color, val)
	end
end
local function _get_is_bot(p)
	if not _is_player_valid(p) then
		return false
	end
	local s, r = pcall(_call_is_bot, p)
	return s and r or false
end
local function _call_mechanism_name(m)
	return m:mechanism_name()
end
local function _call_mission_name(m)
	return m:mission_name()
end
local function _get_mechanism_name(m)
	if not m then
		return nil
	end
	local s, r = pcall(_call_mechanism_name, m)
	return s and r or nil
end
local function _get_mission_name(m)
	if not m then
		return nil
	end
	local s, r = pcall(_call_mission_name, m)
	return s and r or nil
end

function ColorUtils.normalize_to_rgb(color)
	if not color or type(color) ~= "table" then
		return { r = CONSTANTS.MAX_COLOR_VALUE, g = CONSTANTS.MAX_COLOR_VALUE, b = CONSTANTS.MAX_COLOR_VALUE }
	end

	if color.r and color.g and color.b then
		return {
			r = math.clamp(color.r or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			g = math.clamp(color.g or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			b = math.clamp(color.b or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
		}
	elseif color[1] and color[2] and color[3] then
		return {
			r = math.clamp(color[2] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			g = math.clamp(color[3] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			b = math.clamp(color[4] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
		}
	end

	return { r = CONSTANTS.MAX_COLOR_VALUE, g = CONSTANTS.MAX_COLOR_VALUE, b = CONSTANTS.MAX_COLOR_VALUE }
end

function ColorUtils.rgb_to_argb(rgb)
	return { CONSTANTS.MAX_COLOR_VALUE, rgb.r, rgb.g, rgb.b }
end

function ColorUtils.argb_to_rgb(argb)
	return {
		r = argb[2] or CONSTANTS.MAX_COLOR_VALUE,
		g = argb[3] or CONSTANTS.MAX_COLOR_VALUE,
		b = argb[4] or CONSTANTS.MAX_COLOR_VALUE,
	}
end

mod._player_custom_colors = {}
mod._local_player_account_id = nil

mod.account_id_color_map = mod:persistent_table("account_id_color_map")

function mod.get_default_color_value(prefix, component)
	local defaults = {
		slot1 = { r = 226, g = 210, b = 117 },
		slot2 = { r = 180, g = 88, b = 108 },
		slot3 = { r = 84, g = 172, b = 121 },
		slot4 = { r = 126, g = 153, b = 230 },
		bot = { r = 128, g = 128, b = 128 },
		veteran = { r = 84, g = 172, b = 121 },
		zealot = { r = 180, g = 88, b = 108 },
		psyker = { r = 126, g = 153, b = 230 },
		ogryn = { r = 226, g = 210, b = 117 },
		broker = { r = 217, g = 104, b = 41 },
		adamant = { r = 138, g = 43, b = 226 },
		cryptic = { r = 32, g = 178, b = 170 },
	}

	local color_data = defaults[prefix]
	if color_data and component then
		return color_data[component] or CONSTANTS.MAX_COLOR_VALUE
	end

	return CONSTANTS.MAX_COLOR_VALUE
end

local function update_local_player_id()
	local pm = Managers and Managers.player
	if pm then
		local local_player = pm:local_player_safe(1)
		if local_player then
			local success, account_id = pcall(_get_player_account_id, local_player)
			if success and account_id and account_id ~= "" then
				mod._local_player_account_id = account_id
				return true
			end
		end
	end
	return false
end

local function pcall_safe(func, a, b, c, d)
	return func(a, b, c, d)
end

Shared.CONSTANTS = CONSTANTS
Shared.ColorUtils = ColorUtils
Shared._get_is_bot = _get_is_bot
Shared._get_mechanism_name = _get_mechanism_name
Shared._get_mission_name = _get_mission_name
Shared._get_player_account_id = _get_player_account_id
Shared._get_player_name = _get_player_name
Shared._get_player_profile = _get_player_profile
Shared._get_player_slot = _get_player_slot
Shared._get_user_display_name = _get_user_display_name
Shared._is_player_valid = _is_player_valid
Shared._set_vector3_for_materials = _set_vector3_for_materials
Shared.pcall_safe = pcall_safe
Shared.update_local_player_id = update_local_player_id
