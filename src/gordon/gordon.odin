package gordon

#assert(ODIN_OS == .JS)

import gl "vendor:wasm/WebGL"
import js "vendor:wasm/js"
import "core:fmt"
import "core:math"
import "core:slice"
import glm "core:math/linalg/glsl"

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

MAX_EVENT_COUNT :: 512

Colour :: distinct [4]u8

Context :: struct {
	canvas_id:     string,
	canvas_width:  i32,
	canvas_height: i32,
	pixel_scale:   u8,

	prev_time: f64,
	curr_time: f64,



	frame_counter: u64,

	io: IO,

	user_data:  rawptr,
	user_index: int,

	program: gl.Program,
	vertex_buffer: gl.Buffer,

	update: Update_Proc,
	fini: Fini_Proc,

	camera:     Camera,
	vertices:   [dynamic]Vertex,
	draw_calls: [dynamic]Draw_Call,

	is_done: bool,

	click: bool,

	_next: ^Context,
}

Update_Proc :: proc(ctx: ^Context, dt: f32)
Fini_Proc :: proc(ctx: ^Context)


@(private)
global_context_list: ^Context

init :: proc(ctx: ^Context, canvas_id: string, update: Update_Proc, fini: Fini_Proc = nil, pixel_scale := 1) -> bool {
	ctx.canvas_id = canvas_id
	gl.CreateCurrentContextById(ctx.canvas_id, gl.DEFAULT_CONTEXT_ATTRIBUTES) or_return
	assert(gl.IsWebGL2Supported(), "WebGL 2 must be supported")
	ctx.update = update
	ctx.fini = fini
	ctx.pixel_scale = u8(clamp(pixel_scale, 1, 255))

	ctx.camera = Camera_Default

	gl.SetCurrentContextById(ctx.canvas_id) or_return
	ctx.program = gl.CreateProgramFromStrings({shader_vert}, {shader_frag}) or_return

	reserve(&ctx.vertices,   1<<20)
	reserve(&ctx.draw_calls, 1<<12)

	ctx.vertex_buffer = gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vertex_buffer)
	gl.BufferData(gl.ARRAY_BUFFER, len(ctx.vertices)*size_of(ctx.vertices[0]), nil, gl.DYNAMIC_DRAW)

	for kind in events_to_handle {
		if window_wide_events[kind] {
			js.add_window_event_listener(kind, ctx, event_callback, true)
		} else {
			js.add_event_listener(ctx.canvas_id, kind, ctx, event_callback, true)
		}
	}

	ctx._next = global_context_list
	global_context_list = ctx


	return true
}

fini :: proc(ctx: ^Context) {
	if ctx.fini != nil {
		ctx->fini()
	}
	for kind in events_to_handle {
		if window_wide_events[kind] {
			js.remove_window_event_listener(kind, ctx, event_callback)
		} else {
			js.remove_event_listener(ctx.canvas_id, kind, ctx, event_callback)
		}
	}


	gl.DeleteBuffer(ctx.vertex_buffer)
	gl.DeleteProgram(ctx.program)

	delete(ctx.vertices)
	delete(ctx.draw_calls)
}


@(export)
step :: proc(curr_time: f64) -> bool {
	for ctx := global_context_list; ctx != nil; ctx = ctx._next {
		dt := curr_time - ctx.curr_time
		ctx.prev_time = ctx.curr_time
		ctx.curr_time = curr_time
		ctx.frame_counter += 1

		if ctx.is_done {
			p := &global_context_list
			for p^ != ctx {
				p = &p^._next
			}
			p^ = ctx._next
			fini(ctx)
			continue
		}

		io_init(ctx)
		defer io_fini(ctx)

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

		gl.SetCurrentContextById(ctx.canvas_id) or_continue

		ctx.update(ctx, f32(dt))

		draw_all(ctx)
	}
	return true
}



@(private)
draw_all :: proc(ctx: ^Context) -> bool {
	enable_program_state :: proc(program: gl.Program, camera: Camera, width, height: i32) {
		gl.UseProgram(program)

		a_pos := gl.GetAttribLocation(program, "a_pos")
		gl.EnableVertexAttribArray(a_pos)
		gl.VertexAttribPointer(a_pos, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))

		a_col := gl.GetAttribLocation(program, "a_col")
		gl.EnableVertexAttribArray(a_col)
		gl.VertexAttribPointer(a_col, 4, gl.UNSIGNED_BYTE, true, size_of(Vertex), offset_of(Vertex, col))

		a_uv := gl.GetAttribLocation(program, "a_uv")
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

			gl.UniformMatrix4fv(gl.GetUniformLocation(program, "u_camera"), mvp)
		}
	}

	gl.SetCurrentContextById(ctx.canvas_id) or_return

	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vertex_buffer)
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

	prev_draw_call := Draw_Call_Default
	prev_draw_call.program = ~gl.Program(0)
	prev_draw_call.texture = ~gl.Texture(0)

	for dc in ctx.draw_calls {
		defer prev_draw_call = dc

		if prev_draw_call.program != dc.program {
			enable_program_state(dc.program, ctx.camera, width, height)
		}

		gl.Uniform1f(gl.GetUniformLocation(dc.program, "u_layer"), dc.layer)

		if prev_draw_call.depth_test != dc.depth_test {
			if dc.depth_test {
				gl.Enable(gl.DEPTH_TEST)
			} else {
				gl.Disable(gl.DEPTH_TEST)
			}
		}

		if prev_draw_call.texture != dc.texture {
			gl.BindTexture(gl.TEXTURE_2D, dc.texture)
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


