local mod = get_mod("ColorSelection")
local UISettings = require("scripts/settings/ui/ui_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

mod._shared = {}

mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/helpers/player_data")
mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/helpers/colors")
mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/features/team_panels")
mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/features/nameplates")
mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/features/slot_colors")
mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/features/squad_watch")
mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/features/names")
mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/features/outlines")

local Shared = mod._shared
local _get_player_account_id = Shared._get_player_account_id
local _on_player_removed = Shared._on_player_removed
local apply_slot_colors = Shared.apply_slot_colors
local check_roster_changes = Shared.check_roster_changes
local colored_names = Shared.colored_names
local flush_pending_apply = Shared.flush_pending_apply
local refresh_settings = Shared.refresh_settings
local reset_character_outlines = Shared.reset_character_outlines
local reset_frame_cache = Shared.reset_frame_cache
local restore_previous = Shared.restore_previous
local settings = Shared.settings
local should_color_names = Shared.should_color_names
local update_local_player_id = Shared.update_local_player_id
local update_player_panel_colors = Shared.update_player_panel_colors

local color_customizer_view_name = "color_customizer"
local color_customizer_view_path =
	"ColorSelection/scripts/mods/ColorSelection/views/color_customizer_view/color_customizer_view"

mod:add_require_path(color_customizer_view_path)

mod:register_view({
	view_name = color_customizer_view_name,
	view_settings = {
		init_view_function = function(ingame_ui_context)
			return true
		end,
		state_bound = true,
		display_name = "loc_eye_color_sienna_desc",
		path = color_customizer_view_path,
		package = "packages/ui/views/credits_goods_vendor_view/credits_goods_vendor_view",
		class = "ColorCustomizerView",
		load_in_hub = false,
		game_world_blur = 1,
		enter_sound_events = {
			"wwise/events/ui/play_ui_enter_short",
		},
		exit_sound_events = {
			"wwise/events/ui/play_ui_back_short",
		},
		wwise_states = {},
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

function mod.open_color_customizer()
	if Managers.ui:view_active(color_customizer_view_name) then
		Managers.ui:close_view(color_customizer_view_name)
		return
	end

	if Managers.ui:has_active_view() or Managers.ui:chat_using_input() then
		return
	end

	Managers.ui:open_view(color_customizer_view_name)
end

local function setup_state_your_name_integration()
	local syn = get_mod("state_your_name")
	if syn and syn.identity and not syn.identity.__cs_hooked then
		syn.identity.__cs_hooked = true
		local orig_color_selection_color = syn.identity._color_selection_color
		syn.identity._color_selection_color = function(self, record)
			local is_local = false
			if record then
				if record.account_id and mod._local_player_account_id then
					is_local = (record.account_id == mod._local_player_account_id)
				end
				if not is_local and record.player_info and record.player_info.is_own_player then
					is_local = record.player_info:is_own_player()
				end
				if not is_local and Managers.player then
					local lp = Managers.player:local_player_safe(1)
					if lp then
						if record.player == lp then
							is_local = true
						elseif record.account_id and _get_player_account_id(lp) == record.account_id then
							is_local = true
						end
					end
				end
				if not is_local and record.slot == 1 and settings.force_local_slot_1 ~= false then
					is_local = true
				end
			end

			if not should_color_names(is_local) then
				return nil
			end

			return orig_color_selection_color(self, record)
		end
	end
end
setup_state_your_name_integration()

local function _strip_cs_color_tags(text)
	if not text or type(text) ~= "string" then
		return text
	end

	local cleaned = text:gsub("{#color%(%d+,%d+,%d+%)}", ""):gsub("{#reset%(%)}", "")
	return cleaned
end

local function reset_team_panel_colors()
	local ui_manager = Managers and Managers.ui
	if not ui_manager then
		return
	end

	local hud = ui_manager:get_hud()
	if not hud then
		return
	end

	local handler = hud:element("HudElementTeamPanelHandler")
	if not handler or not handler._player_panels_array then
		return
	end

	for i = 1, #handler._player_panels_array do
		local p = handler._player_panels_array[i] and handler._player_panels_array[i].panel
		if p and p._widgets_by_name then
			local class_icon = p._widgets_by_name.class_icon or p._widgets_by_name.character_portrait
			if class_icon and class_icon.style and class_icon.style.texture then
				local c = class_icon.style.texture.color
				if c and type(c) == "table" then
					c[1], c[2], c[3], c[4] = 255, 255, 255, 255
					class_icon.dirty = true
				end
			end

			local widget = p._widgets_by_name.player_name
			if widget and widget.content and type(widget.content.text) == "string" then
				widget.content.text = _strip_cs_color_tags(widget.content.text)
				widget.dirty = true
			end
		end
	end
end

local function reset_nameplate_colors()
	local ui_manager = Managers and Managers.ui
	if not ui_manager then
		return
	end
	local hud = ui_manager._hud
	if not hud then
		return
	end
	local world_markers = hud:element("HudElementWorldMarkers")
	if not world_markers or not world_markers._markers_by_id then
		return
	end
	for _, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type
		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			if marker.widget and marker.widget.content then
				if marker.widget.content.header_text and type(marker.widget.content.header_text) == "string" then
					marker.widget.content.header_text = _strip_cs_color_tags(marker.widget.content.header_text)
					marker._cs_last_header = nil
				end
				if
					marker_type:match("companion")
					and marker.widget.content.icon_text
					and type(marker.widget.content.icon_text) == "string"
				then
					marker.widget.content.icon_text = _strip_cs_color_tags(marker.widget.content.icon_text)
				end
			end
		end
	end
end

mod:hook_require(
	"scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup_content_list",
	function(module)
		if module.from_player_info then
			module.__cs_original_from_player_info = module.__cs_original_from_player_info or module.from_player_info
			local original_from_player_info = module.__cs_original_from_player_info

			module.from_player_info = function(parent, player_info)
				local popup_menu_items, num_menu_items = original_from_player_info(parent, player_info)

				if not player_info:is_own_player() and player_info:account_id() then
					local account_id = player_info:account_id()

					local _add_divider = function(at_index)
						local _get_next_list_item = function(at_index)
							local last_item_index = num_menu_items + 1
							local new_item = popup_menu_items[last_item_index]

							if new_item then
								table.clear(new_item)
							else
								new_item = {}
								popup_menu_items[last_item_index] = new_item
							end

							if at_index then
								popup_menu_items[last_item_index] = nil
								table.insert(popup_menu_items, at_index, new_item)
							end

							num_menu_items = last_item_index
							return new_item, last_item_index
						end

						local item, num_items = _get_next_list_item(at_index)
						item.blueprint = "group_divider"
						item.label = "divider_" .. num_items
					end

					local _get_next_list_item = function(at_index)
						local last_item_index = num_menu_items + 1
						local new_item = popup_menu_items[last_item_index]

						if new_item then
							table.clear(new_item)
						else
							new_item = {}
							popup_menu_items[last_item_index] = new_item
						end

						if at_index then
							popup_menu_items[last_item_index] = nil
							table.insert(popup_menu_items, at_index, new_item)
						end

						num_menu_items = last_item_index
						return new_item, last_item_index
					end

					_add_divider()

					local copy_button = _get_next_list_item()
					copy_button.blueprint = "button"
					copy_button.label = mod:localize("copy_account_id_button")
					copy_button.callback = function()
						if account_id then
							Clipboard.put(account_id)
							mod:notify(mod:localize("account_id_copied"))
						end
					end
					copy_button.on_pressed_sound = UISoundEvents.social_menu_see_player_profile
				end

				return popup_menu_items, num_menu_items
			end
		end
	end
)

mod.on_all_mods_loaded = function()
	local career_outlines = get_mod("CareerColourOutlines")
	if career_outlines and career_outlines:is_enabled() then
		mod:echo(
			"{#color(255,50,50)}[ColorSelection] WARNING:{#reset()} CareerColourOutlines is enabled! It conflicts with this mod and will cause outline colors to bug out. Please disable it!"
		)
	end

	mod:add_global_localize_strings({
		players_list_title = {
			en = "Customized Players",
		},
		preset_colors_title = {
			en = "Preset Colors",
		},
	})

	update_local_player_id()
	setup_state_your_name_integration()

	if Managers.state and Managers.state.game_mode then
		mod._in_gameplay_state = true
		if mod:is_enabled() then
			apply_slot_colors(true)
		end
	end

	if mod.command then
		mod:command("cs_menu", "open color customizer menu", function()
			mod.open_color_customizer()
		end)
		mod:command("cs_sync", "sync/apply color settings", function()
			if UISettings and mod._in_gameplay_state then
				apply_slot_colors()
				mod:notify("Colors synced")
			else
				mod:notify("Cannot sync colors outside of gameplay")
			end
		end)
	end

	local dmf = get_mod("DMF")
	if dmf then
		mod:hook(dmf, "check_keybinds", function(func)
			if Managers.ui and Managers.ui:view_active(color_customizer_view_name) then
				return
			end

			return func()
		end)
	end

	mod:hook_safe("HumanGameplay", "on_player_removed", function(self, player)
		_on_player_removed(player)

		if mod._in_gameplay_state then
			mod:pcall(function()
				apply_slot_colors()
			end)
		end
	end)

	mod:hook_safe("GameModeManager", "on_player_unit_spawn", function(self, player, player_unit, is_respawn)
		if mod._in_gameplay_state then
			mod:pcall(function()
				apply_slot_colors()
			end)
		end
	end)

	local slotfix = get_mod("SlotFix")
	if not slotfix then
		mod:echo("WARNING: SlotFix mod is required for ColorSelection to work properly!")
	end
end

function mod.update(dt)
	reset_frame_cache()
	if not mod:is_enabled() then
		return
	end
	check_roster_changes()
	if flush_pending_apply then
		flush_pending_apply()
	end
end

mod.on_game_state_changed = function(status, state_name)
	update_local_player_id()
	table.clear(colored_names)

	if status == "enter" and state_name == "StateGameplay" then
		mod._in_gameplay_state = true
		mod._mission_color_cache = {}
		mod._known_slot_account_ids = {}
		mod._last_roster_check_t = 0
		apply_slot_colors()
	elseif status == "exit" and state_name == "StateGameplay" then
		mod._in_gameplay_state = false
		mod._known_slot_account_ids = {}
		mod._last_roster_check_t = 0
		restore_previous()
	end
end

mod.on_enabled = function()
	update_local_player_id()
	if UISettings and mod._in_gameplay_state then
		apply_slot_colors()
	end
end

mod.on_disabled = function()
	if mod._slot_colors_replaced then
		restore_previous()

		if mod._in_gameplay_state then
			update_player_panel_colors()
		end
	end

	reset_team_panel_colors()
	reset_nameplate_colors()
	reset_character_outlines()
end

mod.on_unload = function(exit_game)
	restore_previous()
	reset_team_panel_colors()
	reset_nameplate_colors()
	reset_character_outlines()
end

mod.on_setting_changed = function(setting_id)
	refresh_settings()
	local triggers_update = false

	if setting_id == "saved_player_colors" then
		mod._cached_saved_colors = mod:get("saved_player_colors")
		mod._cached_saved_colors_loaded = true
		triggers_update = true
	end
	if string.find(setting_id, "slot%d") or string.find(setting_id, "bot_") or setting_id == "bot" then
		triggers_update = true
	elseif
		setting_id == "color_bots"
		or setting_id == "color_by_class"
		or setting_id == "color_local_outside_mission"
		or setting_id == "color_custom_outside_mission"
		or setting_id == "color_names"
		or setting_id == "color_local_inside_mission"
	then
		triggers_update = true
	elseif setting_id == "force_local_slot_1" then
		if settings.force_local_slot_1 == false then
			mod:set("color_local_outside_mission", false, true)
		end
		triggers_update = true
	else
		local classes = { "veteran", "zealot", "psyker", "ogryn", "broker", "adamant", "cryptic" }
		for _, class_name in ipairs(classes) do
			if string.find(setting_id, class_name) then
				triggers_update = true
				break
			end
		end
	end

	if triggers_update then
		local syn = get_mod("state_your_name")
		if syn then
			syn._identity_revision = (syn._identity_revision or 0) + 1
		end
		if UISettings and mod._in_gameplay_state then
			apply_slot_colors()
		else
			update_player_panel_colors()
		end
	end

	if setting_id == "color_outlines" or setting_id == "color_dog_outlines" then
		if mod._in_gameplay_state then
			reset_character_outlines()
		end
	end
end

mod.save_custom_player_colors = function(colors)
	mod:set("saved_player_colors", colors)
	if mod.on_setting_changed then
		mod.on_setting_changed("saved_player_colors")
	end
end
