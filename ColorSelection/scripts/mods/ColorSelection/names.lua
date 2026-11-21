local mod = get_mod("ColorSelection")
local Shared = mod._shared

local _get_player_account_id = Shared._get_player_account_id
local _get_player_slot = Shared._get_player_slot
local _get_user_display_name = Shared._get_user_display_name
local get_color = Shared.get_color
local get_color_for_account_id = Shared.get_color_for_account_id
local get_player_by_account_id = Shared.get_player_by_account_id
local pcall_safe = Shared.pcall_safe
local settings = Shared.settings
local should_color_names = Shared.should_color_names

mod:hook(CLASS.ConstantElementChat, "_participant_displayname", function(func, self, participant)
	func(self, participant)

	local is_local = false
	if participant then
		if participant.is_current_user then
			is_local = true
		elseif
			participant.account_id
			and mod._local_player_account_id
			and participant.account_id == mod._local_player_account_id
		then
			is_local = true
		end
	end

	if not mod:is_enabled() or not should_color_names(is_local) then
		return func(self, participant)
	end

	if is_local then
		local account_id = mod._local_player_account_id
		local pm = Managers.player
		local player = pm and pm:local_player_safe(1)
		local slot = player and pcall_safe(_get_player_slot, player) or 1
		local color = get_color_for_account_id(account_id, slot)

		local display_name
		local style = settings.chat_local_name_style or "colored_you"
		if style == "character" then
			display_name = func(self, participant)
		elseif style == "account" then
			local player_info = account_id and Managers.data_service.social:get_player_info_by_account_id(account_id)
			display_name = player_info and pcall_safe(_get_user_display_name, player_info)
		end

		if not display_name then
			display_name = mod:localize("loc_color_selection_you")
			if type(display_name) ~= "string" or display_name == "" or display_name == "<loc_color_selection_you>" then
				display_name = "You"
			end
		end

		if color then
			local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
			return color_tag .. display_name .. "{#reset()}"
		else
			return display_name
		end
	end

	local display_name = func(self, participant)

	if not display_name then
		return nil
	end

	local account_id = participant and participant.account_id
	if not account_id then
		return display_name
	end

	local slot = nil
	local player = get_player_by_account_id(account_id)

	if player then
		slot = pcall_safe(_get_player_slot, player)
	end

	local color = get_color_for_account_id(account_id, slot)
	if not color then
		return display_name
	end

	if color then
		local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
		local stripped_display_name = display_name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
		local result = color_tag .. stripped_display_name .. "{#reset()}"
		return result
	end

	return display_name
end)

mod:hook(
	CLASS.ConstantElementChat,
	"cb_chat_manager_message_recieved",
	function(func, self, channel_handle, participant, message)
		if not mod:is_enabled() then
			return func(self, channel_handle, participant, message)
		end

		local participant_current = participant and participant.is_current_user
		local message_current = message and message.is_current_user
		local style = settings.chat_local_name_style or "colored_you"

		if (participant_current or message_current) and style ~= "vanilla" then
			local cloned_participant = participant and table.clone(participant) or nil
			local cloned_message = message and table.clone(message) or nil

			if cloned_participant then
				cloned_participant.is_current_user = false
			end
			if cloned_message then
				cloned_message.is_current_user = false
			end

			return func(self, channel_handle, cloned_participant, cloned_message)
		end

		return func(self, channel_handle, participant, message)
	end
)

local colored_names = {}

local function colorize_name(name, color)
	if type(name) ~= "string" then
		return name
	end

	local r, g, b = color[2], color[3], color[4]
	local entry = colored_names[name]
	if entry and entry[1] == r and entry[2] == g and entry[3] == b then
		return entry[4]
	end

	local clean_name = name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
	local text = string.format("{#color(%d,%d,%d)}", r, g, b) .. clean_name .. "{#reset()}"
	if entry then
		entry[1], entry[2], entry[3], entry[4] = r, g, b, text
	else
		colored_names[name] = { r, g, b, text }
	end
	return text
end

local function apply_color_to_player_name(name, player)
	local is_local = false
	if player and Managers.player then
		is_local = (player == Managers.player:local_player_safe(1))
	end
	local account_id = pcall_safe(_get_player_account_id, player)
	if account_id and mod._local_player_account_id and account_id == mod._local_player_account_id then
		is_local = true
	end

	if not should_color_names(is_local) or not name or name == "" or not player then
		if name and type(name) == "string" and name:find("{#color") then
			return (name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", ""))
		end
		return name
	end

	if not account_id or account_id == "" then
		return name
	end

	local color = get_color_for_account_id(account_id)

	if color then
		return colorize_name(name, color)
	end

	return name
end

mod:hook(CLASS.HumanPlayer, "name", function(func, self)
	local name = func(self)

	if not mod:is_enabled() then
		return name
	end

	return apply_color_to_player_name(name, self)
end)

mod:hook(CLASS.RemotePlayer, "name", function(func, self)
	local name = func(self)

	if not mod:is_enabled() then
		return name
	end

	return apply_color_to_player_name(name, self)
end)

mod:hook(CLASS.PlayerInfo, "character_name", function(func, self)
	local name = func(self)

	local account_id = (self.account_id and self:account_id()) or self._account_id
	local is_local = (self.is_own_player and self:is_own_player())
		or (account_id and mod._local_player_account_id and (account_id == mod._local_player_account_id))
	if not mod:is_enabled() or not should_color_names(is_local) then
		if name and type(name) == "string" and name:find("{#color") then
			return (name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", ""))
		end
		return name
	end

	if account_id then
		local color = get_color_for_account_id(account_id)
		if color then
			return colorize_name(name, color)
		end
	end

	return name
end)

mod:hook(CLASS.RemotePlayer, "character_name", function(func, self)
	local name = func(self)

	if not mod:is_enabled() then
		return name
	end

	return apply_color_to_player_name(name, self)
end)

mod:hook(CLASS.PresenceEntryMyself, "character_name", function(func, self)
	local name = func(self)

	if not mod:is_enabled() or not should_color_names(true) then
		if name and type(name) == "string" and name:find("{#color") then
			return (name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", ""))
		end
		return name
	end

	local color = get_color("slot1")
	return colorize_name(name, color)
end)

mod:hook(CLASS.PresenceEntryImmaterium, "character_name", function(func, self)
	local name = func(self)

	local account_id = (self.account_id and self:account_id())
		or (self._immaterium_entry and self._immaterium_entry.account_id)
	local is_local = account_id and mod._local_player_account_id and (account_id == mod._local_player_account_id)
	if not mod:is_enabled() or not should_color_names(is_local) then
		if name and type(name) == "string" and name:find("{#color") then
			return (name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", ""))
		end
		return name
	end

	if account_id then
		local color = get_color_for_account_id(account_id)
		if color then
			return colorize_name(name, color)
		end
	end

	return name
end)

mod:hook_require("scripts/utilities/profile_utils", function(instance)
	mod:hook(instance, "character_name", function(func, profile)
		local name = func(profile)

		local account_id = profile and profile.account_id
		local is_local = false
		if account_id and mod._local_player_account_id and (account_id == mod._local_player_account_id) then
			is_local = true
		elseif profile and profile.character_id and Managers.player then
			local lp = Managers.player:local_player_safe(1)
			local lp_prof = lp and lp:profile()
			if lp_prof and lp_prof.character_id == profile.character_id then
				is_local = true
			end
		end

		if not mod:is_enabled() or not should_color_names(is_local) then
			if name and type(name) == "string" and name:find("{#color") then
				return (name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", ""))
			end
			return name
		end

		if account_id then
			local color = get_color_for_account_id(account_id)
			if color then
				return colorize_name(name, color)
			end
		end

		return name
	end)
end)

Shared.colored_names = colored_names
