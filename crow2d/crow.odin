package crowd2d

import "core:time"

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

MAX_EVENT_COUNT :: 512

Color :: distinct [4]u8

WHITE       :: Color{255, 255, 255, 255}
BLACK       :: Color{  0,   0,   0, 255}
BLANK       :: Color{  0,   0,   0,   0}

LIGHT_GREY  :: Color{200, 200, 200, 255}
GREY        :: Color{130, 130, 130, 255}
DARK_GREY   :: Color{ 80,  80,  80, 255}

RED         :: Color{230,  41,  55, 255}
MAROON      :: Color{190,  33,  55, 255}
ORANGE      :: Color{255, 161,   0, 255}
YELLOW      :: Color{253, 249,   0, 255}
GOLD        :: Color{255, 203,   0, 255}
GREEN       :: Color{  0, 228,  48, 255}
LIME        :: Color{  0, 158,  47, 255}
DARK_GREEN  :: Color{  0, 117,  44, 255}
SKY_BLUE    :: Color{127, 178, 255, 255}
BLUE        :: Color{  0, 121, 241, 255}
DARK_BLUE   :: Color{  0,  82, 172, 255}
PURPLE      :: Color{200, 122, 255, 255}
VIOLET      :: Color{135,  60, 190, 255}
DARK_PURPLE :: Color{112,  31, 126, 255}
MAGENTA     :: Color{255,   0, 255, 255}
PINK        :: Color{255, 109, 194, 255}
BEIGE       :: Color{211, 176, 131, 255}
BROWN       :: Color{127, 106,  79, 255}
DARK_BROWN  :: Color{ 76,  63,  47, 255}

Camera :: struct {
	offset:   Vec2,
	target:   Vec2,
	rotation: f32,
	zoom:     f32,
	near:     f32,
	far:      f32,
}
Camera_Default :: Camera{
	zoom = 1,
	near = -1024,
	far  = +1024,
}


Vertex :: struct {
	pos: Vec3, // 3 components to allow for possible depth testing
	col: Color,
	uv:  Vec2,
}

Draw_Call :: struct {
	shader:     Shader,
	texture:    Texture,
	depth_test: bool,

	offset:     int,
	length:     int,
}

Draw_State :: struct {
	camera:     Camera,
	vertices:   [dynamic]Vertex,
	draw_calls: [dynamic]Draw_Call,
}


Context :: struct {
	canvas_id:     string,
	canvas_width:  f32,
	canvas_height: f32,
	pixel_scale:   u8,
	clear_color:   Color,

	prev_time: f64,
	curr_time: f64,

	frame_counter: u64,

	io: IO,

	user_data:  rawptr,
	user_index: int,

	default_shader:  Shader,
	default_texture: Texture,
	vertex_buffer:   Buffer,

	curr_z: f32,

	update: Update_Proc,
	fini: Fini_Proc,

	using draw_state: Draw_State,

	is_done: bool,

	_next: ^Context,

	platform_data: Platform_Data,
}

Update_Proc :: proc(ctx: ^Context, dt: f32)
Init_Proc :: proc(ctx: ^Context) -> bool
Fini_Proc :: proc(ctx: ^Context)


Shader :: struct {
	handle: u32,
}
Buffer :: struct {
	handle: u32,
}
Texture :: struct {
	handle: u32,
	width:  i32,
	height: i32,
}

HANDLE_INVALID :: ~u32(0)

SHADER_INVALID  :: Shader{  handle = HANDLE_INVALID }
BUFFER_INVALID  :: Buffer{  handle = HANDLE_INVALID }
TEXTURE_INVALID :: Texture{ handle = HANDLE_INVALID }


@(private)
global_context_list: ^Context

init :: proc(ctx: ^Context, canvas_id: string, init: Init_Proc, update: Update_Proc, fini: Fini_Proc = nil, pixel_scale := 1) -> bool {
	ctx.canvas_id = canvas_id
	ctx.update = update
	ctx.fini = fini
	ctx.pixel_scale = u8(clamp(pixel_scale, 1, 255))
	ctx.camera = Camera_Default
	ctx.clear_color = SKY_BLUE
	ctx.curr_z = 0

	reserve(&ctx.vertices,   1<<20)
	reserve(&ctx.draw_calls, 1<<12)

	platform_init(ctx) or_return

	ctx._next = global_context_list
	global_context_list = ctx

	if !init(ctx) {
		fini(ctx)
		return false
	}

	return true
}

// Only needed for non-JS platforms
start :: proc() {
	start_time := time.tick_now()
	for ODIN_OS != .JS && global_context_list != nil {
		curr_time := time.duration_seconds(time.tick_since(start_time))
		if !step(curr_time) {
			break
		}
	}
}

fini :: proc(ctx: ^Context) {
	if ctx == nil {
		return
	}
	if ctx.fini != nil {
		ctx->fini()
	}

	platform_fini(ctx)

	delete(ctx.vertices)
	delete(ctx.draw_calls)
}


@(export)
step :: proc(curr_time: f64) -> bool {
	free_all(context.temp_allocator)

	for ctx := global_context_list; ctx != nil; /**/ {
		defer ctx = ctx._next

		dt := curr_time - ctx.curr_time
		ctx.prev_time = ctx.curr_time
		ctx.curr_time = curr_time
		ctx.frame_counter += 1
		ctx.curr_z = 0

		if ctx.is_done {
			p := &global_context_list
			for p^ != ctx {
				p = &p^._next
			}
			p^ = ctx._next
			fini(ctx)
			continue
		}

		platform_update(ctx) or_continue

		io_init(ctx)
		defer io_fini(ctx)

		ctx.update(ctx, f32(dt))

		_ = draw_all(ctx)
	}
	return global_context_list != nil
}


@(private)
draw_all :: proc(ctx: ^Context) -> bool {
	if len(ctx.draw_calls) > 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		last.length = len(ctx.vertices)-last.offset
	}

	sort_draw_calls(&ctx.draw_calls)

	ok := platform_draw(ctx)
	clear(&ctx.vertices)
	clear(&ctx.draw_calls)
	return ok
}
