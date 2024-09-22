#+private
package gordon

import js "vendor:wasm/js"
import gl "vendor:wasm/WebGL"

import glm "core:math/linalg/glsl"

@(require_results)
platform_init :: proc(ctx: ^Context) -> bool {
	gl.CreateCurrentContextById(ctx.canvas_id, gl.DEFAULT_CONTEXT_ATTRIBUTES) or_return
	assert(gl.IsWebGL2Supported(), "WebGL 2 must be supported")

	gl.SetCurrentContextById(ctx.canvas_id) or_return
	ctx.default_shader = Shader(gl.CreateProgramFromStrings({shader_vert}, {shader_frag}) or_return)

	ctx.vertex_buffer = Buffer(gl.CreateBuffer())
	gl.BindBuffer(gl.ARRAY_BUFFER, gl.Buffer(ctx.vertex_buffer))
	gl.BufferData(gl.ARRAY_BUFFER, len(ctx.vertices)*size_of(ctx.vertices[0]), nil, gl.DYNAMIC_DRAW)

	for kind in events_to_handle {
		if window_wide_events[kind] {
			js.add_window_event_listener(kind, ctx, platform_event_callback, true)
		} else {
			js.add_event_listener(ctx.canvas_id, kind, ctx, platform_event_callback, true)
		}
	}

	return true
}

platform_fini :: proc(ctx: ^Context) {
	for kind in events_to_handle {
		if window_wide_events[kind] {
			js.remove_window_event_listener(kind, ctx, platform_event_callback)
		} else {
			js.remove_event_listener(ctx.canvas_id, kind, ctx, platform_event_callback)
		}
	}

	gl.DeleteBuffer(gl.Buffer(ctx.vertex_buffer))
	gl.DeleteProgram(gl.Program(ctx.default_shader))
}

@(require_results)
platform_update :: proc(ctx: ^Context) -> bool {
	{
		client_width  := i32(js.get_element_key_f64(ctx.canvas_id, "clientWidth"))
		client_height := i32(js.get_element_key_f64(ctx.canvas_id, "clientHeight"))
		client_width  /= i32(ctx.pixel_scale)
		client_height /= i32(ctx.pixel_scale)

		width  := i32(js.get_element_key_f64(ctx.canvas_id, "width"))
		height := i32(js.get_element_key_f64(ctx.canvas_id, "height"))

		if client_width != width {
			js.set_element_key_f64(ctx.canvas_id, "width",  f64(client_width))
		}
		if client_height != height {
			js.set_element_key_f64(ctx.canvas_id, "height", f64(client_height))
		}

		ctx.canvas_width  = client_width
		ctx.canvas_height = client_width
	}

	gl.SetCurrentContextById(ctx.canvas_id) or_return
	return true
}



@(require_results)
platform_draw :: proc(ctx: ^Context) -> bool {
	enable_shader_state :: proc(shader: gl.Program, camera: Camera, width, height: i32) {
		gl.UseProgram(shader)

		a_pos := gl.GetAttribLocation(shader, "a_pos")
		gl.EnableVertexAttribArray(a_pos)
		gl.VertexAttribPointer(a_pos, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))

		a_col := gl.GetAttribLocation(shader, "a_col")
		gl.EnableVertexAttribArray(a_col)
		gl.VertexAttribPointer(a_col, 4, gl.UNSIGNED_BYTE, true, size_of(Vertex), offset_of(Vertex, col))

		a_uv := gl.GetAttribLocation(shader, "a_uv")
		gl.EnableVertexAttribArray(a_uv)
		gl.VertexAttribPointer(a_uv, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

		{
			proj := glm.mat4Ortho3d(0, f32(width), f32(height), 0, camera.near, camera.far)

			origin := glm.mat4Translate({-camera.target.x, -camera.target.y, 0})
			rotation := glm.mat4Rotate({0, 0, 1}, camera.rotation_radians)
			scale := glm.mat4Scale({camera.zoom, camera.zoom, 1})
			translation := glm.mat4Translate({camera.offset.x, camera.offset.y, 0})

			view := origin * scale * rotation * translation

			mvp := proj * view

			gl.UniformMatrix4fv(gl.GetUniformLocation(shader, "u_camera"), mvp)
		}
	}

	gl.SetCurrentContextById(ctx.canvas_id) or_return

	gl.BindBuffer(gl.ARRAY_BUFFER, gl.Buffer(ctx.vertex_buffer))
	gl.BufferData(gl.ARRAY_BUFFER, len(ctx.vertices)*size_of(ctx.vertices[0]), raw_data(ctx.vertices), gl.DYNAMIC_DRAW)

	defer {
		clear(&ctx.vertices)
		clear(&ctx.draw_calls)
	}

	width, height := gl.DrawingBufferWidth(), gl.DrawingBufferHeight()

	gl.Viewport(0, 0, width, height)
	gl.ClearColor(0.5, 0.7, 1.0, 1.0)
	gl.Disable(gl.DEPTH_TEST)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	if len(ctx.draw_calls) > 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		last.length = len(ctx.vertices)-last.offset
	}

	prev_draw_call := Draw_Call{}
	prev_draw_call.shader  = ~Shader(0)
	prev_draw_call.texture = ~Texture(0)

	for dc in ctx.draw_calls {
		defer prev_draw_call = dc

		if prev_draw_call.shader != dc.shader {
			enable_shader_state(gl.Program(dc.shader), ctx.camera, width, height)
		}

		gl.Uniform1f(gl.GetUniformLocation(gl.Program(dc.shader), "u_layer"), dc.layer)

		if prev_draw_call.depth_test != dc.depth_test {
			if dc.depth_test {
				gl.Enable(gl.DEPTH_TEST)
			} else {
				gl.Disable(gl.DEPTH_TEST)
			}
		}

		if prev_draw_call.texture != dc.texture {
			gl.BindTexture(gl.TEXTURE_2D, gl.Texture(dc.texture))
		}

		gl.DrawArrays(gl.TRIANGLES, dc.offset, dc.length)
	}

	return true
}



shader_vert := `
precision highp float;

uniform mat4  u_camera;
uniform float u_layer;

attribute vec2 a_pos;
attribute vec4 a_col;
attribute vec2 a_uv;

varying vec4 v_color;
varying vec2 v_uv;

void main() {
	v_color = a_col;
	v_uv = a_uv;
	gl_Position = u_camera * vec4(a_pos, u_layer, 1.0);
}
`

shader_frag := `
precision highp float;

varying vec4 v_color;
varying vec2 v_uv;

void main() {
	gl_FragColor = v_color;
}
`




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

platform_event_callback :: proc(e: js.Event) {
	ctx := (^Context)(e.user_data)

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

