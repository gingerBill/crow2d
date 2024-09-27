#+private
package crowd2d

import win32 "core:sys/windows"
import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"

import "core:fmt"
_ :: fmt

// Defining these will try to prefer discrete graphics over integrated graphics
@(export, link_name="NvOptimusEnablement")
NvOptimusEnablement: u32 = 0x00000001

@(export, link_name="AmdPowerXpressRequestHighPerformance")
AmdPowerXpressRequestHighPerformance: i32 = 1

#assert(size_of(int) >= size_of(uintptr))

Platform_Data :: struct {
	wc: win32.WNDCLASSEXW,
	wnd: win32.HWND,
	dc: win32.HDC,
	opengl_ctx: win32.HGLRC,

	vao: u32,

	is_showing: bool,
}

@(private="file")
platform_init_get_wgl_procedures_attempted: bool
@(private="file")
platform_init_get_wgl_procedures_successful: bool

@(private="file")
platform_init_get_wgl_procedures :: proc() -> bool {
	if platform_init_get_wgl_procedures_attempted {
		return platform_init_get_wgl_procedures_successful
	}
	platform_init_get_wgl_procedures_attempted = true

	dummy := win32.CreateWindowExW(0,
		win32.L("STATIC"), win32.L("Dummy Window"), win32.WS_OVERLAPPED,
		win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT,
		nil, nil, nil, nil,
	)
	(dummy != nil) or_return
	defer win32.DestroyWindow(dummy)

	dc := win32.GetDC(dummy)
	defer win32.ReleaseDC(dummy, dc)

	(dc != nil) or_return
	{
		pfd: win32.PIXELFORMATDESCRIPTOR
		pfd.nSize = size_of(pfd)
		pfd.nVersion = 1
		pfd.dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER
		pfd.iPixelType = win32.PFD_TYPE_RGBA
		pfd.cColorBits = 32
		pfd.cDepthBits = 24
		pfd.cStencilBits = 8
		pfd.iLayerType = win32.PFD_MAIN_PLANE
		pf := win32.ChoosePixelFormat(dc, &pfd)
		if pf == 0 {
			return false
		}
		if !win32.SetPixelFormat(dc, pf, &pfd) {
			return false
		}
		win32.DescribePixelFormat(dc, pf, size_of(pfd), &pfd)
	}

	rc := win32.wglCreateContext(dc)
	(rc != nil) or_return

	win32.wglMakeCurrent(dc, rc) or_return
	defer win32.wglDeleteContext(rc)
	defer win32.wglMakeCurrent(nil, nil)


	if win32.wglCreateContextAttribsARB == nil {
		win32.wglCreateContextAttribsARB = auto_cast win32.wglGetProcAddress("wglCreateContextAttribsARB")
		win32.wglChoosePixelFormatARB    = auto_cast win32.wglGetProcAddress("wglChoosePixelFormatARB")
		win32.wglSwapIntervalEXT         = auto_cast win32.wglGetProcAddress("wglSwapIntervalEXT")
		win32.wglGetExtensionsStringARB  = auto_cast win32.wglGetProcAddress("wglGetExtensionsStringARB")
	}
	ok := win32.wglCreateContextAttribsARB != nil &&
	      win32.wglChoosePixelFormatARB    != nil &&
	      win32.wglSwapIntervalEXT         != nil &&
	      win32.wglGetExtensionsStringARB  != nil
	platform_init_get_wgl_procedures_successful = ok
	return ok
}


@(require_results)
platform_init :: proc(ctx: ^Context) -> bool {
	has_wgl_extensions := platform_init_get_wgl_procedures()
	if !has_wgl_extensions {
		fmt.eprintln("Could not initialize wgl (Windows OpenGL) extensions")
		return false
	}

	pd := &ctx.platform_data

	pd.wc.cbSize = size_of(pd.wc)
	pd.wc.hInstance     = win32.HANDLE(win32.GetModuleHandleW(nil))
	pd.wc.lpfnWndProc   = platform_win_proc
	pd.wc.lpszClassName = win32.L("Crow2DWindowClass")
	pd.wc.hIcon         = win32.LoadIconW(nil, cast([^]u16)cast(rawptr)win32.IDI_APPLICATION)
	pd.wc.hCursor       = win32.LoadCursorW(nil, cast([^]u16)cast(rawptr)win32.IDC_ARROW)

	if win32.RegisterClassExW(&pd.wc) == 0 {
		return false
	}
	ex_style := u32(win32.WS_EX_APPWINDOW)
	pd.wnd = win32.CreateWindowExW(ex_style, pd.wc.lpszClassName, win32.L("Crow2D"), win32.WS_OVERLAPPEDWINDOW, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, 1280, 800, nil, nil, pd.wc.hInstance, nil)
	if pd.wnd == nil {
		return false
	}
	win32.SetWindowLongPtrW(pd.wnd, win32.GWLP_USERDATA, int(uintptr(ctx)))

	ctx.canvas_width  = 1
	ctx.canvas_height = 1
	if rect: win32.RECT; win32.GetClientRect(pd.wnd, &rect) {
		ctx.canvas_width  = max(f32(rect.right - rect.left), 1)
		ctx.canvas_height = max(f32(rect.bottom - rect.top), 1)
		fmt.println(ctx.canvas_width, ctx.canvas_height)
	}

	OPENGL_MAJOR :: 4
	OPENGL_MINOR :: 5

	pd.dc = win32.GetDC(pd.wnd)

	{
		attribs := [?]i32{
			win32.WGL_DRAW_TO_WINDOW_ARB, 1,
			win32.WGL_SUPPORT_OPENGL_ARB, 1,
			win32.WGL_DOUBLE_BUFFER_ARB,  1,
			win32.WGL_PIXEL_TYPE_ARB,     win32.WGL_TYPE_RGBA_ARB,
			win32.WGL_COLOR_BITS_ARB,     32,
			win32.WGL_DEPTH_BITS_ARB,     24,
			win32.WGL_STENCIL_BITS_ARB,   8,
			0,
		}

		format: i32
		formats: u32
		if !win32.wglChoosePixelFormatARB(pd.dc, &attribs[0], nil, 1, &format, &formats) || formats == 0 {
			return false
		}

		pfd: win32.PIXELFORMATDESCRIPTOR
		pfd.nSize = size_of(pfd)
		pfd.nVersion = 1
		pfd.dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER
		pfd.iPixelType = win32.PFD_TYPE_RGBA
		pfd.cColorBits = 32
		pfd.cDepthBits = 24
		pfd.cStencilBits = 8
		pfd.iLayerType = win32.PFD_MAIN_PLANE
		pf := win32.ChoosePixelFormat(pd.dc, &pfd)
		if pf == 0 {
			return false
		}
		if !win32.SetPixelFormat(pd.dc, pf, &pfd) {
			return false
		}
		win32.DescribePixelFormat(pd.dc, pf, size_of(pfd), &pfd)
	}

	attribs := [?]i32{
		win32.WGL_CONTEXT_MAJOR_VERSION_ARB, OPENGL_MAJOR,
		win32.WGL_CONTEXT_MINOR_VERSION_ARB, OPENGL_MINOR,
		win32.WGL_CONTEXT_FLAGS_ARB, win32.CONTEXT_CORE_PROFILE_BIT_ARB,
		0, 0,
		0,
	}
	if ODIN_DEBUG {
		attribs[len(attribs)-3] = win32.WGL_CONTEXT_FLAGS_ARB
		attribs[len(attribs)-2] = win32.WGL_CONTEXT_DEBUG_BIT_ARB
	}

	pd.opengl_ctx = win32.wglCreateContextAttribsARB(pd.dc, nil, &attribs[0])
	win32.wglMakeCurrent(pd.dc, pd.opengl_ctx) or_return

	gl.load_up_to(OPENGL_MAJOR, OPENGL_MINOR, win32.gl_set_proc_address)

	win32.wglSwapIntervalEXT(1)

	gl.GenVertexArrays(1, &pd.vao)
	gl.BindVertexArray(pd.vao)

	ctx.default_shader.handle = gl.load_shaders_source(shader_vert, shader_frag) or_return

	gl.GenBuffers(1, &ctx.vertex_buffer.handle)
	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vertex_buffer.handle)
	gl.BufferData(gl.ARRAY_BUFFER, len(ctx.vertices)*size_of(ctx.vertices[0]), nil, gl.DYNAMIC_DRAW)

	ctx.default_texture = texture_load_default_white(ctx) or_return

	return true
}

platform_fini :: proc(ctx: ^Context) {
	pd := &ctx.platform_data
	_ = win32.wglMakeCurrent(pd.dc, pd.opengl_ctx)

	texture_unload(ctx, ctx.default_texture)

	gl.DeleteBuffers(1, &ctx.vertex_buffer.handle)
	gl.DeleteProgram(ctx.default_shader.handle)

	gl.DeleteVertexArrays(1, &pd.vao)
	win32.wglDeleteContext(pd.opengl_ctx)
	// win32.ReleaseDC(pd.wnd, pd.dc)
	win32.DestroyWindow(pd.wnd)
}

@(require_results)
platform_update :: proc(ctx: ^Context) -> bool {
	process_key :: proc(ctx: ^Context, key: Key, pressed: bool) {
		if pressed {
			ctx.io.last_key_press_time = ctx.curr_time
			ctx.io.key_pressed += {key}

			if count := &ctx.io.key_pressed_count_per_frame[key]; count^ < 255 {
				count^ += 1
			}
		} else { // released
			ctx.io.key_released += {key}
		}
	}


	pd := &ctx.platform_data
	if !pd.is_showing {
		pd.is_showing = true
		win32.ShowWindow(pd.wnd, 1)
	}

	ctx.canvas_width  = 1
	ctx.canvas_height = 1
	if rect: win32.RECT; win32.GetClientRect(pd.wnd, &rect) {
		ctx.canvas_width  = max(f32(rect.right - rect.left), 1)
		ctx.canvas_height = max(f32(rect.bottom - rect.top), 1)
	}

	for {
		msg: win32.MSG
		win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) or_break

		switch msg.message {
		case win32.WM_QUIT:
			ctx.is_done = true

		case win32.WM_SYSKEYDOWN, win32.WM_SYSKEYUP, win32.WM_KEYDOWN, win32.WM_KEYUP:
			vk_code := u32(msg.wParam)
			is_extended := msg.lParam & 0x01000000 != 0

			switch vk_code {
			case win32.VK_CONTROL, win32.VK_MENU, win32.VK_SHIFT:
				scan_code := win32.HIWORD(msg.lParam)
				if is_extended {
					scan_code = win32.MAKEWORD(scan_code, 0xe0)
				}

				vk_code = u32(win32.MapVirtualKeyW(u32(scan_code), win32.MAPVK_VSC_TO_VK_EX))
			}


			was_down := msg.lParam & (1<<30) != 0
			is_down  := msg.lParam & (1<<31) == 0

			if was_down != is_down {
				switch vk_code {
				case win32.VK_LCONTROL: process_key(ctx, .Left_Ctrl,   is_down)
				case win32.VK_RCONTROL: process_key(ctx, .Right_Ctrl,  is_down)
				case win32.VK_LMENU:    process_key(ctx, .Left_Alt,    is_down)
				case win32.VK_RMENU:    process_key(ctx, .Right_Alt,   is_down)
				case win32.VK_LSHIFT:   process_key(ctx, .Left_Shift,  is_down)
				case win32.VK_RSHIFT:   process_key(ctx, .Right_Shift, is_down)

				case win32.VK_RETURN:
					process_key(ctx, .Numpad_Enter if is_extended else .Return, is_down)

				case win32.VK_ESCAPE: process_key(ctx, .Escape, is_down)
				case win32.VK_TAB:    process_key(ctx, .Tab,    is_down)
				case win32.VK_SPACE:  process_key(ctx, .Space,  is_down)
				case win32.VK_DELETE: process_key(ctx, .Delete, is_down)
				case win32.VK_INSERT: process_key(ctx, .Insert, is_down)

				case win32.VK_OEM_7:      process_key(ctx, .Apostrophe,    is_down)
				case win32.VK_OEM_COMMA:  process_key(ctx, .Comma,         is_down)
				case win32.VK_OEM_MINUS:  process_key(ctx, .Minus,         is_down)
				case win32.VK_OEM_PERIOD: process_key(ctx, .Period,        is_down)
				case win32.VK_OEM_2:      process_key(ctx, .Slash,         is_down)
				case win32.VK_OEM_1:      process_key(ctx, .Semicolon,     is_down)
				case win32.VK_OEM_PLUS:   process_key(ctx, .Equal,         is_down)
				case win32.VK_OEM_5:      process_key(ctx, .Backslash,     is_down)
				case win32.VK_OEM_4:      process_key(ctx, .Bracket_Left,  is_down)
				case win32.VK_OEM_6:      process_key(ctx, .Bracket_Right, is_down)
				case win32.VK_OEM_3:      process_key(ctx, .Grave_Accent,  is_down)

				case win32.VK_HOME:  process_key(ctx, .Home,      is_down)
				case win32.VK_END:   process_key(ctx, .End,       is_down)
				case win32.VK_PRIOR: process_key(ctx, .Page_Up,   is_down)
				case win32.VK_NEXT:  process_key(ctx, .Page_Down, is_down)

				case 'A'..='Z': process_key(ctx, .A + Key(vk_code-'A'), is_down)
				case '0'..='9': process_key(ctx, .Key_0 + Key(vk_code-'0'), is_down)

				case win32.VK_NUMPAD0..=win32.VK_NUMPAD9: process_key(ctx, .Numpad_0 + Key(vk_code-win32.VK_NUMPAD0), is_down)

				case win32.VK_DIVIDE:   process_key(ctx, .Numpad_Divide,   is_down)
				case win32.VK_MULTIPLY: process_key(ctx, .Numpad_Multiply, is_down)
				case win32.VK_SUBTRACT: process_key(ctx, .Numpad_Subtract, is_down)
				case win32.VK_ADD:      process_key(ctx, .Numpad_Add,      is_down)
				case win32.VK_DECIMAL:  process_key(ctx, .Numpad_Decimal,  is_down)

				case win32.VK_UP:    process_key(ctx, .Up,    is_down)
				case win32.VK_DOWN:  process_key(ctx, .Down,  is_down)
				case win32.VK_LEFT:  process_key(ctx, .Left,  is_down)
				case win32.VK_RIGHT: process_key(ctx, .Right, is_down)
				}
			}

		case win32.WM_MOUSEWHEEL:  ctx.io.scroll_delta.y = i32(win32.GET_WHEEL_DELTA_WPARAM(msg.wParam))
		case win32.WM_MOUSEHWHEEL: ctx.io.scroll_delta.x = i32(win32.GET_WHEEL_DELTA_WPARAM(msg.wParam))

		case:
			win32.TranslateMessage(&msg)
			win32.DispatchMessageW(&msg)
		}
	}

	mouse_stuff: { // Mouse stuff
		if point: win32.POINT; win32.GetCursorPos(&point) {
			if win32.ScreenToClient(pd.wnd, &point) {
				ctx.io.mouse_pos.x = i32(point.x)
				ctx.io.mouse_pos.y = i32(point.y)
			}

		}
		if ctx.io.mouse_pos.x < 0 || ctx.io.mouse_pos.y < 0 {
			break mouse_stuff
		}

		if ctx.io.mouse_pos.x >= i32(ctx.canvas_width) || ctx.io.mouse_pos.y >= i32(ctx.canvas_height) {
			break mouse_stuff
		}

		if win32.GetAsyncKeyState(win32.VK_LBUTTON) != 0 {
			ctx.io.mouse_down += {.Left}
			if .Left not_in ctx.io.internal_mouse_was_down {
				ctx.io.mouse_pressed_pos = ctx.io.mouse_pos
			}
		}
		if win32.GetAsyncKeyState(win32.VK_RBUTTON) != 0 {
			ctx.io.mouse_down += {.Right}
			if .Right not_in ctx.io.internal_mouse_was_down {
				ctx.io.mouse_pressed_pos = ctx.io.mouse_pos
			}
		}
		if win32.GetAsyncKeyState(win32.VK_MBUTTON) != 0 {
			ctx.io.mouse_down += {.Middle}
			if .Middle not_in ctx.io.internal_mouse_was_down {
				ctx.io.mouse_pressed_pos = ctx.io.mouse_pos
			}
		}
	}


	return true
}

@(require_results)
platform_draw :: proc(ctx: ^Context) -> bool {
	enable_shader_state :: proc(ctx: ^Context, shader: u32, camera: Camera, width, height: i32) {
		gl.UseProgram(shader)

		a_pos := u32(gl.GetAttribLocation(shader, "a_pos"))
		gl.EnableVertexAttribArray(a_pos)
		gl.VertexAttribPointer(a_pos, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))

		a_col := u32(gl.GetAttribLocation(shader, "a_col"))
		gl.EnableVertexAttribArray(a_col)
		gl.VertexAttribPointer(a_col, 4, gl.UNSIGNED_BYTE, true, size_of(Vertex), offset_of(Vertex, col))

		a_uv := u32(gl.GetAttribLocation(shader, "a_uv"))
		gl.EnableVertexAttribArray(a_uv)
		gl.VertexAttribPointer(a_uv, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

		{
			proj := glm.mat4Ortho3d(0, f32(width), f32(height), 0, camera.near, camera.far)

			origin := glm.mat4Translate({-camera.target.x, -camera.target.y, 0})
			rotation := glm.mat4Rotate({0, 0, 1}, camera.rotation)
			scale := glm.mat4Scale({camera.zoom, camera.zoom, 1})
			translation := glm.mat4Translate({camera.offset.x, camera.offset.y, 0})

			view := origin * scale * rotation * translation

			mvp := proj * view

			gl.UniformMatrix4fv(gl.GetUniformLocation(shader, "u_camera"),     1, false, &mvp[0, 0])
			gl.UniformMatrix4fv(gl.GetUniformLocation(shader, "u_view"),       1, false, &view[0, 0])
			gl.UniformMatrix4fv(gl.GetUniformLocation(shader, "u_projection"), 1, false, &proj[0, 0])
		}
		gl.Uniform2f(gl.GetUniformLocation(shader, "u_screen_size"), f32(width), f32(height))
		gl.Uniform2f(gl.GetUniformLocation(shader, "u_mouse_pos"), f32(ctx.io.mouse_pos.x), f32(ctx.io.mouse_pos.y))


		gl.Uniform1i(gl.GetUniformLocation(shader, "u_texture"), 0)
	}

	pd := &ctx.platform_data
	win32.wglMakeCurrent(pd.dc, pd.opengl_ctx) or_return
	defer win32.SwapBuffers(pd.dc)

	gl.BindVertexArray(pd.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vertex_buffer.handle)
	gl.BufferData(gl.ARRAY_BUFFER, len(ctx.vertices)*size_of(ctx.vertices[0]), raw_data(ctx.vertices), gl.DYNAMIC_DRAW)


	width, height := i32(ctx.canvas_width), i32(ctx.canvas_height)

	gl.Viewport(0, 0, width, height)
	gl.ClearColor(f32(ctx.clear_color.r)/255, f32(ctx.clear_color.g)/255, f32(ctx.clear_color.b)/255, f32(ctx.clear_color.a)/255)
	gl.Disable(gl.DEPTH_TEST)
	gl.Enable(gl.BLEND)
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK)
	gl.FrontFace(gl.CW)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)


	prev_draw_call := Draw_Call{}
	prev_draw_call.shader  = SHADER_INVALID
	prev_draw_call.texture = TEXTURE_INVALID

	for dc in ctx.draw_calls {
		defer prev_draw_call = dc

		if prev_draw_call.depth_test != dc.depth_test {
			if dc.depth_test {
				gl.Enable(gl.DEPTH_TEST)
			} else {
				gl.Disable(gl.DEPTH_TEST)
			}
		}

		if prev_draw_call.texture != dc.texture {
			gl.ActiveTexture(gl.TEXTURE0)
			gl.BindTexture(gl.TEXTURE_2D, dc.texture.handle)
		}

		if prev_draw_call.shader != dc.shader {
			enable_shader_state(ctx, dc.shader.handle, ctx.camera, width, height)
		}

		gl.DrawArrays(gl.TRIANGLES, i32(dc.offset), i32(dc.length))
	}


	gl.UseProgram(0)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, 0)

	return true
}


@(private="file", rodata)
shader_vert := `#version 120
precision highp float;

uniform mat4  u_camera;
uniform mat4  u_view;
uniform mat4  u_projection;

uniform vec2  u_screen_size;
uniform vec2  u_mouse_pos;

attribute vec3 a_pos;
attribute vec4 a_col;
attribute vec2 a_uv;

varying vec4 v_color;
varying vec2 v_uv;

void main() {
	v_color = a_col;
	v_uv = a_uv;
	gl_Position = u_camera * vec4(a_pos, 1.0);
}
`

@(private="file", rodata)
shader_frag := `#version 120
precision highp float;

uniform sampler2D u_texture;

varying vec4 v_color;
varying vec2 v_uv;

void main() {
	vec4 tex = texture2D(u_texture, v_uv);
	gl_FragColor = tex.rgba * v_color.rgba;

}
`

@(private="file")
texture_filter_map := [Texture_Filter]i32{
	.Linear  = i32(gl.LINEAR),
	.Nearest = i32(gl.NEAREST),
}
@(private="file")
texture_wrap_map := [Texture_Wrap]i32{
	.Clamp_To_Edge   = i32(gl.CLAMP_TO_EDGE),
	.Repeat          = i32(gl.REPEAT),
	.Mirrored_Repeat = i32(gl.MIRRORED_REPEAT),
}


@(require_results)
platform_texture_load_from_img :: proc(ctx: ^Context, img: Image, opts: Texture_Options) -> (tex: Texture, ok: bool) {
	t: u32
	gl.GenTextures(1, &t)
	defer if !ok {
		gl.DeleteTextures(1, &t)
	}
	assert(t != 0)
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.BindTexture(gl.TEXTURE_2D, t)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, texture_filter_map[opts.filter])
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, texture_filter_map[opts.filter])

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, texture_wrap_map[opts.wrap[0]])
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, texture_wrap_map[opts.wrap[1]])

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, img.width, img.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(img.pixels))
	gl.BindTexture(gl.TEXTURE_2D, 0)

	tex.handle = u32(t)
	tex.width  = img.width
	tex.height = img.height
	ok = true
	return
}

platform_texture_unload :: proc(ctx: ^Context, tex: Texture) {
	win32.wglMakeCurrent(ctx.platform_data.dc, ctx.platform_data.opengl_ctx)
	t := tex.handle
	gl.DeleteTextures(1, &t)
}

@(private="file")
platform_win_proc :: proc "system" (hwnd: win32.HWND, Msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
	ctx := (^Context)(uintptr(win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA)))
	if ctx == nil {
		return win32.DefWindowProcW(hwnd, Msg, wParam, lParam)
	}
	assert_contextless(ctx.platform_data.wnd == hwnd)

	switch Msg {
	case win32.WM_DESTROY:
		ctx.is_done = true
		win32.PostQuitMessage(0)

	case win32.WM_PAINT:
		ps: win32.PAINTSTRUCT
		hdc := win32.BeginPaint(hwnd, &ps)
		_ = hdc
		// win32.FillRect(hdc, &ps.rcPaint, win32.HBRUSH(uintptr(win32.COLOR_WINDOW+1)))
		win32.EndPaint(hwnd, &ps)

	case:
		return win32.DefWindowProcW(hwnd, Msg, wParam, lParam)
	}
	return 0

}