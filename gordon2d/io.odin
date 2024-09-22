package gordon

import js "vendor:wasm/js"

import "core:fmt"

IO :: struct {
	mouse_pos:         [2]i32,
	mouse_last_pos:    [2]i32,
	mouse_pressed_pos: [2]i32,
	mouse_delta:       [2]i32,

	mouse_down:     Mouse_Button_Set,
	mouse_pressed:  Mouse_Button_Set,
	mouse_released: Mouse_Button_Set,
	internal_mouse_was_down: Mouse_Button_Set,

	key_down: Key_Set,

	key_pressed:  Key_Set,
	key_released: Key_Set,
	key_repeat:   Key_Set,

	modifiers: Modifier_Key_Set,
	pressed_key_stroke: Key_Stroke,

	last_key_press_time: f64,

	scroll_delta: [2]i32,

	last_mouse_button:     Mouse_Button,
	last_mouse_press_time: f64,

	click_count: i32,

	full_reset: bool,
}


Mouse_Button :: enum u16 {
	Left,
	Right,
	Middle,
}

Modifier_Key :: enum u32 {
	Ctrl,
	Shift,
	Alt,
}

Key :: enum u16 {
	Invalid,

	Left_Ctrl,  Left_Shift,  Left_Alt,
	Right_Ctrl, Right_Shift, Right_Alt,

	A, B, C, D, E, F, G, H,
	I, J, K, L, M, N, O, P,
	Q, R, S, T, U, V, W, X,
	Y, Z,

	Key_1, Key_2, Key_3, Key_4, Key_5,
	Key_6, Key_7, Key_8, Key_9, Key_0,

	Numpad_0, Numpad_1, Numpad_2, Numpad_3, Numpad_4,
	Numpad_5, Numpad_6, Numpad_7, Numpad_8, Numpad_9,
	Numpad_Divide, Numpad_Multiply, Numpad_Subtract,
	Numpad_Add, Numpad_Enter, Numpad_Decimal,

	Escape,
	Return,
	Tab,
	Backspace,
	Space,
	Delete,
	Insert,

	Apostrophe,
	Comma,
	Minus,
	Period,
	Slash,
	Semicolon,
	Equal,
	Backslash,
	Bracket_Left,
	Bracket_Right,
	Grave_Accent,
	Home,
	End,
	Page_Up,
	Page_Down,


	Up,
	Down,
	Left,
	Right,
}

Key_Stroke :: struct {
	modifiers: Modifier_Key_Set,
	key:       Key,
}


Mouse_Button_Set :: distinct bit_set[Mouse_Button; u16]
Key_Set          :: distinct bit_set[Key; u128]
Modifier_Key_Set :: distinct bit_set[Modifier_Key; u32]

MODIFIER_KEYS :: Key_Set{
	.Left_Ctrl,  .Left_Shift,  .Left_Alt,
	.Right_Ctrl, .Right_Shift, .Right_Alt,
}


key_strings := [Key]string{
	.Invalid = "invalid",

	.Left_Ctrl   = "lctrl",
	.Left_Shift  = "lshift",
	.Left_Alt    = "lalt",
	.Right_Ctrl  = "rctrl",
	.Right_Shift = "rshift",
	.Right_Alt   = "ralt",

	.Escape    = "escape",
	.Return    = "return",
	.Tab       = "tab",
	.Backspace = "backspace",
	.Space     = "space",
	.Delete    = "delete",
	.Insert    = "insert",

	.Apostrophe    = "'",
	.Comma         = ",",
	.Minus         = "-",
	.Period        = ".",
	.Slash         = "/",
	.Semicolon     = ";",
	.Equal         = "=",
	.Backslash     = `\`,
	.Bracket_Left  = "[",
	.Bracket_Right = "]",
	.Grave_Accent  = "`",
	.Home          = "home",
	.End           = "end",
	.Page_Up       = "page_up",
	.Page_Down     = "page_down",


	.A = "a", .B = "b", .C = "c", .D = "d", .E = "e", .F = "f", .G = "g", .H = "h",
	.I = "i", .J = "j", .K = "k", .L = "l", .M = "m", .N = "n", .O = "o", .P = "p",
	.Q = "q", .R = "r", .S = "s", .T = "t", .U = "u", .V = "v", .W = "w", .X = "x",
	.Y = "y", .Z = "z",

	.Key_1 = "1", .Key_2 = "2", .Key_3 = "3", .Key_4 = "4", .Key_5 = "5",
	.Key_6 = "6", .Key_7 = "7", .Key_8 = "8", .Key_9 = "9", .Key_0 = "0",

	.Numpad_0 = "numpad_0", .Numpad_1 = "numpad_1", .Numpad_2 = "numpad_2", .Numpad_3 = "numpad_3", .Numpad_4 = "numpad_4",
	.Numpad_5 = "numpad_5", .Numpad_6 = "numpad_6", .Numpad_7 = "numpad_7", .Numpad_8 = "numpad_8", .Numpad_9 = "numpad_9",
	.Numpad_Divide = "numpad_divide", .Numpad_Multiply = "numpad_multiply", .Numpad_Subtract = "numpad_subtract",
	.Numpad_Add    = "numpad_add",    .Numpad_Enter    = "numpad_enter",    .Numpad_Decimal  = "numpad_decimal",

	.Up    = "up",
	.Down  = "down",
	.Left  = "left",
	.Right = "right",
}


@(private)
event_callback :: proc(e: js.Event) {
	ctx := (^Context)(e.user_data)
	handle_event(ctx, e)
}

io_init :: proc(ctx: ^Context) {
	ctx.io.key_pressed -= ctx.io.key_released

	ctx.io.key_down += ctx.io.key_pressed
	ctx.io.key_down -= ctx.io.key_released

	ctx.io.mouse_delta = ctx.io.mouse_pos - ctx.io.mouse_last_pos

	ctx.io.mouse_pressed  = ctx.io.mouse_down - ctx.io.internal_mouse_was_down
	ctx.io.mouse_released = ctx.io.internal_mouse_was_down - ctx.io.mouse_down


	ctx.io.modifiers = nil
	for mod in MODIFIER_KEYS {
		if mod in ctx.io.key_down {
			#partial switch mod {
			case .Left_Ctrl,  .Right_Ctrl:  ctx.io.modifiers += {.Ctrl}
			case .Left_Shift, .Right_Shift: ctx.io.modifiers += {.Shift}
			case .Left_Alt,   .Right_Alt:   ctx.io.modifiers += {.Alt}
			}
		}
	}

}
io_fini :: proc(ctx: ^Context) {
	ctx.io.mouse_delta    = { 0, 0 }
	ctx.io.scroll_delta   = { 0, 0 }
	ctx.io.mouse_last_pos = ctx.io.mouse_pos

	ctx.io.internal_mouse_was_down = ctx.io.mouse_down
	ctx.io.mouse_down = nil

	ctx.io.key_pressed  = nil
	ctx.io.key_released = nil
	ctx.io.key_repeat   = nil

	ctx.io.pressed_key_stroke = {}

	if ctx.io.full_reset {
		ctx.io.key_released  = ctx.io.key_down
		ctx.io.mouse_released  = ctx.io.mouse_down
		ctx.io.key_down      = nil
		ctx.io.key_pressed   = nil
		ctx.io.key_repeat    = nil
		ctx.io.mouse_down    = nil
		ctx.io.mouse_pressed = nil
		ctx.io.modifiers     = nil
		ctx.io.full_reset    = false
	}
}

@(private)
handle_event :: proc(ctx: ^Context, e: js.Event) {
	#partial switch e.kind {
	case .Focus: // Enter
		// ignore
	case .Blur: // Exit
		ctx.io.full_reset = true
	case .Mouse_Move:
		ctx.io.mouse_pos = {i32(e.mouse.offset.x), i32(e.mouse.offset.y)}
	case .Mouse_Up:
		ctx.io.mouse_pos = {i32(e.mouse.offset.x), i32(e.mouse.offset.y)}
		switch e.mouse.button {
		case 0: ctx.io.mouse_down += {.Left}
		case 1: ctx.io.mouse_down += {.Middle}
		case 2: ctx.io.mouse_down += {.Right}
		}
	case .Mouse_Down:
		ctx.io.mouse_pos = {i32(e.mouse.offset.x), i32(e.mouse.offset.y)}
		ctx.io.mouse_pressed_pos = {i32(e.mouse.offset.x), i32(e.mouse.offset.y)}
		switch e.mouse.button {
		case 0: ctx.io.mouse_pressed += {.Left}
		case 1: ctx.io.mouse_pressed += {.Middle}
		case 2: ctx.io.mouse_pressed += {.Right}
		}
		ctx.io.mouse_down -= ctx.io.mouse_pressed

	case .Key_Down:
		if key, _ := code_to_key(e.key.code); key != .Invalid {
			if !e.key.repeat {
				ctx.io.last_key_press_time = ctx.curr_time
				ctx.io.key_pressed += {key}

				if key not_in MODIFIER_KEYS {
					ctx.io.pressed_key_stroke = { ctx.io.modifiers, key }
				}
			} else {
				ctx.io.key_repeat += {key}
			}
		}
	case .Key_Up:
		if key, _ := code_to_key(e.key.code); key != .Invalid {
			ctx.io.key_released += {key}
		}

	case .Scroll:
		ctx.io.scroll_delta.x += i32(e.scroll.delta.x)
		ctx.io.scroll_delta.y += i32(e.scroll.delta.y)
	}
}

events_to_handle := [?]js.Event_Kind{
	.Focus,
	.Blur,
	.Mouse_Move,
	.Mouse_Up,
	.Mouse_Down,
	.Key_Down,
	.Key_Up,
	.Scroll,
}

window_wide_events := #partial [js.Event_Kind]bool {
	.Focus     = true,
	.Focus_In  = true,
	.Focus_Out = true,
	.Blur      = true,
	.Key_Down  = true,
	.Key_Up    = true,
	.Key_Press = true,
}


@(private)
code_to_key :: proc(code: string) -> (key: Key, printable: bool) {
	switch code {
	case "KeyA": return .A, true
	case "KeyB": return .B, true
	case "KeyC": return .C, true
	case "KeyD": return .D, true
	case "KeyE": return .E, true
	case "KeyF": return .F, true
	case "KeyG": return .G, true
	case "KeyH": return .H, true
	case "KeyI": return .I, true
	case "KeyJ": return .J, true
	case "KeyK": return .K, true
	case "KeyL": return .L, true
	case "KeyM": return .M, true
	case "KeyN": return .N, true
	case "KeyO": return .O, true
	case "KeyP": return .P, true
	case "KeyQ": return .Q, true
	case "KeyR": return .R, true
	case "KeyS": return .S, true
	case "KeyT": return .T, true
	case "KeyU": return .U, true
	case "KeyV": return .V, true
	case "KeyW": return .W, true
	case "KeyX": return .X, true
	case "KeyY": return .Y, true
	case "KeyZ": return .Z, true

	case "Digit1": return .Key_1, true
	case "Digit2": return .Key_2, true
	case "Digit3": return .Key_3, true
	case "Digit4": return .Key_4, true
	case "Digit5": return .Key_5, true
	case "Digit6": return .Key_6, true
	case "Digit7": return .Key_7, true
	case "Digit8": return .Key_8, true
	case "Digit9": return .Key_9, true
	case "Digit0": return .Key_0, true


	case "Numpad1": return .Numpad_1, true
	case "Numpad2": return .Numpad_2, true
	case "Numpad3": return .Numpad_3, true
	case "Numpad4": return .Numpad_4, true
	case "Numpad5": return .Numpad_5, true
	case "Numpad6": return .Numpad_6, true
	case "Numpad7": return .Numpad_7, true
	case "Numpad8": return .Numpad_8, true
	case "Numpad9": return .Numpad_9, true
	case "Numpad0": return .Numpad_0, true

	case "NumpadDivide":   return .Numpad_Divide,   true
	case "NumpadMultiply": return .Numpad_Multiply, true
	case "NumpadSubtract": return .Numpad_Subtract, true
	case "NumpadAdd":      return .Numpad_Add,      true
	case "NumpadEnter":    return .Numpad_Enter,    true
	case "NumpadDecimal":  return .Numpad_Decimal,  true

	case "Escape":    return .Escape,    false
	case "Enter":     return .Return,    true
	case "Tab":       return .Tab,       false
	case "Backspace": return .Backspace, false
	case "Space":     return .Space,     true
	case "Delete":    return .Delete,    false
	case "Insert":    return .Insert,    false

	case "Quote":         return .Apostrophe,    true
	case "Comma":         return .Comma,         true
	case "Minus":         return .Minus,         true
	case "Period":        return .Period,        true
	case "Slash":         return .Slash,         true
	case "Semicolon":     return .Semicolon,     true
	case "Equal":         return .Equal,         true
	case "Backslash":     return .Backslash,     true
	case "IntlBackslash": return .Backslash,     true
	case "BracketLeft":   return .Bracket_Left,  true
	case "BracketRight":  return .Bracket_Right, true
	case "Backquote":     return .Grave_Accent,  true

	case "Home":     return .Home,      false
	case "End":      return .End,       false
	case "PageUp":   return .Page_Up,   false
	case "PageDown": return .Page_Down, false

	case "ControlLeft":  return .Left_Ctrl,   false
	case "ShiftLeft":    return .Left_Shift,  false
	case "AltLeft":      return .Left_Alt,    false
	case "ControlRight": return .Right_Ctrl,  false
	case "ShiftRight":   return .Right_Shift, false
	case "AltRight":     return .Right_Alt,   false


	case "ArrowUp":    return .Up,    false
	case "ArrowDown":  return .Down,  false
	case "ArrowLeft":  return .Left,  false
	case "ArrowRight": return .Right, false
	}
	return .Invalid, false
}
