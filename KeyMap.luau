-- Services
local ContextActionService = game:GetService("ContextActionService")

-- Types
type Keybind = {Keycodes: {Enum.KeyCode?}}
type ActionCallback = (InputObject) -> ()

type CachedKeybind = {
	metadata: {string},
	Keycodes: Keybind;
}

-- Module
local KeyMap = {}

local ActionCache: {[string]: {ActionCallback}} = {}
local Keybinds: {CachedKeybind} = {}

-- Private Functions
local function create_action_handler(id: string)
	return function(_, inputState: Enum.UserInputState, inputObject: InputObject)
		if inputState ~= Enum.UserInputState.Begin then return end
		for _, action in ActionCache[id] or {} do
			action(inputObject)
		end
	end
end

local function bind_keys_to_action(bind_id: string, keycodes: {Enum.KeyCode?})
	return ContextActionService:BindAction(bind_id, create_action_handler(bind_id), false, table.unpack(keycodes))
end

function KeyMap.RegisterKeybind(bind_id: string, keycodes: {Enum.KeyCode?})
	Keybinds[bind_id] = {Keycodes = keycodes}
	bind_keys_to_action(bind_id, keycodes)
end

function KeyMap.AddAction(bind_name: string, callback: ActionCallback)
	ActionCache[bind_name] = ActionCache[bind_name] or {}
	table.insert(ActionCache[bind_name], callback)
end

function KeyMap.UpdateKeybind(bind_name: string, new_key: Enum.KeyCode?, is_secondary: boolean)
	local keybind = Keybinds[bind_name]
	if not keybind then return end

	local keycodes = keybind.Keycodes
	keycodes[is_secondary and 2 or 1] = new_key

	ContextActionService:UnbindAction(bind_name)
	bind_keys_to_action(bind_name, keycodes)
end

return KeyMap