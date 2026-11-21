local mod = get_mod("ColorSelection")
local Shared = mod._shared

local _get_player_account_id = Shared._get_player_account_id
local _get_player_slot = Shared._get_player_slot
local _is_player_valid = Shared._is_player_valid
local _set_vector3_for_materials = Shared._set_vector3_for_materials
local get_color_for_account_id = Shared.get_color_for_account_id
local pcall_safe = Shared.pcall_safe
local settings = Shared.settings

local function _is_dog_breed(breed)
	local name = breed.name
	return breed.breed_type == "companion"
		or (name and (string.find(name, "dog", 1, true) or string.find(name, "mastiff", 1, true))) and true
		or false
end

local function _classify_non_player(unit, extension)
	local ext = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = ext and ext.breed and ext:breed()
	if not breed then
		return nil
	end
	if _is_dog_breed(breed) then
		extension._cs_kind = "dog"
	elseif breed.breed_type ~= "player" then
		extension._cs_kind = "other"
	end
	return extension._cs_kind
end

local function _find_dog_owner(pm, unit)
	local players = pm:players()
	if not players then
		return nil
	end
	for _, p in pairs(players) do
		local p_unit = p.player_unit
		if p_unit and ALIVE[p_unit] then
			local spawner_ext = ScriptUnit.has_extension(p_unit, "companion_spawner_system")
			local spawned = spawner_ext and spawner_ext._spawned_units
			if spawned then
				for i = 1, #spawned do
					if spawned[i] == unit then
						return p
					end
				end
			end
		end
	end
	return nil
end

local function _apply_outline_color(unit, extension, owner)
	local outlines = extension.outlines
	local top_outline = outlines[1]
	if not top_outline then
		return
	end

	local color =
		get_color_for_account_id(pcall_safe(_get_player_account_id, owner), pcall_safe(_get_player_slot, owner))
	if not color then
		return
	end

	local r, g, b, count = color[2], color[3], color[4], #outlines
	local visible_layers = extension.visible_material_layers
	if
		extension._cs_top == top_outline
		and extension._cs_count == count
		and extension._cs_r == r
		and extension._cs_g == g
		and extension._cs_b == b
		and extension._cs_visible == visible_layers
	then
		return
	end
	extension._cs_visible = visible_layers
	extension._cs_top, extension._cs_count, extension._cs_r, extension._cs_g, extension._cs_b =
		top_outline, count, r, g, b
	Unit.set_vector3_for_materials(unit, "outline_color", Vector3(r / 255, g / 255, b / 255), true)
end

local function _clear_outline_cache(extension)
	extension._cs_top, extension._cs_count, extension._cs_r, extension._cs_g, extension._cs_b = nil, nil, nil, nil, nil
	extension._cs_owner = nil
	extension._cs_visible = nil
end

local function reset_character_outlines()
	local extension_manager = Managers and Managers.state and Managers.state.extension
	if not extension_manager then
		return
	end

	local outline_system = extension_manager:system("outline_system")
	if not outline_system or not outline_system._unit_extension_data then
		return
	end

	local pm = Managers.player
	local default_outline_color = Vector3(163 / 255, 255 / 255, 185 / 255)
	for unit, extension in pairs(outline_system._unit_extension_data) do
		_clear_outline_cache(extension)
		local kind = extension._cs_kind
		local is_player = kind ~= "other" and kind ~= "dog" and pm and pm:player_by_unit(unit)
		if is_player or kind == "dog" or (not kind and _classify_non_player(unit, extension) == "dog") then
			pcall_safe(_set_vector3_for_materials, unit, "outline_color", default_outline_color, true)
		end
	end
end

mod:hook_safe("OutlineSystem", "update", function(self)
	if not mod:is_enabled() then
		return
	end
	local color_players, color_dogs = settings.color_outlines, settings.color_dog_outlines
	if not color_players and not color_dogs then
		return
	end
	if self._total_num_outlines == 0 then
		return
	end
	if not self._visible then
		return
	end

	local pm = Managers and Managers.player
	if not pm then
		return
	end

	for unit, extension in pairs(self._unit_extension_data) do
		local kind = extension._cs_kind
		if kind ~= "other" and extension.outlines[1] then
			if kind == "dog" then
				if color_dogs then
					local owner = extension._cs_owner
					if not _is_player_valid(owner) then
						owner = _find_dog_owner(pm, unit)
						extension._cs_owner = owner
					end
					if owner then
						_apply_outline_color(unit, extension, owner)
					end
				end
			else
				local player = pm:player_by_unit(unit)
				if player then
					if color_players then
						_apply_outline_color(unit, extension, player)
					end
				elseif _classify_non_player(unit, extension) == "dog" and color_dogs then
					local owner = _find_dog_owner(pm, unit)
					extension._cs_owner = owner
					if owner then
						_apply_outline_color(unit, extension, owner)
					end
				end
			end
		end
	end
end)

Shared.reset_character_outlines = reset_character_outlines
