#+private
package crowd2d

import win32 "core:sys/windows"

#assert(size_of(int) >= size_of(uintptr))

Platform_Data :: struct {
	wc: win32.WNDCLASSW,
	wnd: win32.HWND,
	is_showing: bool,
}

@(require_results)
platform_init :: proc(ctx: ^Context) -> bool {
	pd := &ctx.platform_data
	pd.wc.hInstance = win32.HANDLE(win32.GetModuleHandleW(nil))
	pd.wc.lpfnWndProc = platform_win_proc
	pd.wc.lpszClassName = win32.L("Crow2DWindowClass")
	pd.wc.hbrBackground = win32.HBRUSH(uintptr(win32.COLOR_BACKGROUND))
	pd.wc.style = win32.CS_OWNDC
	if win32.RegisterClassW(&pd.wc) == 0 {
		return false
	}
	pd.wnd = win32.CreateWindowW(pd.wc.lpszClassName, win32.L("Crow2D"), win32.WS_OVERLAPPEDWINDOW, 0, 0, 854, 480, nil, nil, pd.wc.hInstance, nil)
	if pd.wnd == nil {
		return false
	}
	win32.SetWindowLongPtrW(pd.wnd, win32.GWLP_USERDATA, int(uintptr(ctx)))


	return true
}

platform_fini :: proc(ctx: ^Context) {
	pd := &ctx.platform_data
	win32.DestroyWindow(pd.wnd)
}

@(require_results)
platform_update :: proc(ctx: ^Context) -> bool {
	process_key :: proc(ctx: ^Context, key: Key, pressed: bool) {
		if pressed {
			ctx.io.last_key_press_time = ctx.curr_time
			ctx.io.key_pressed += {key}
		} else { // released
			ctx.io.key_released += {key}
		}
	}


	pd := &ctx.platform_data
	if !pd.is_showing {
		win32.ShowWindow(pd.wnd, 1)
	}

	if rect: win32.RECT; win32.GetClientRect(pd.wnd, &rect) {
		ctx.canvas_width  = max(f32(rect.right - rect.left), 1)
		ctx.canvas_height = max(f32(rect.bottom - rect.top), 1)
	} else {
		ctx.canvas_width  = 1
		ctx.canvas_height = 1
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
	return true
}

@(require_results)
platform_texture_load_from_img :: proc(img: Image, opts: Texture_Options) -> (tex: Texture, ok: bool) {
	return {}, true
}

platform_texture_unload :: proc(tex: Texture) {

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