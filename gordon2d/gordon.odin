package gordon

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

	default_shader:  Shader,
	default_texture: Texture,
	vertex_buffer:   Buffer,

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
Init_Proc :: proc(ctx: ^Context) -> bool
Fini_Proc :: proc(ctx: ^Context)


Shader  :: distinct u32
Buffer  :: distinct u32
Texture :: distinct u32

SHADER_INVALID  :: ~Shader(0)
BUFFER_INVALID  :: ~Buffer(0)
TEXTURE_INVALID :: ~Texture(0)


@(private)
global_context_list: ^Context

init :: proc(ctx: ^Context, canvas_id: string, init: Init_Proc, update: Update_Proc, fini: Fini_Proc = nil, pixel_scale := 1) -> bool {
	ctx.canvas_id = canvas_id
	ctx.update = update
	ctx.fini = fini
	ctx.pixel_scale = u8(clamp(pixel_scale, 1, 255))
	ctx.camera = Camera_Default


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

fini :: proc(ctx: ^Context) {
	if ctx.fini != nil {
		ctx->fini()
	}

	platform_fini(ctx)

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

		platform_update(ctx) or_continue

		ctx.update(ctx, f32(dt))

		draw_all(ctx)
	}
	return true
}



@(private)
draw_all :: proc(ctx: ^Context) -> bool {
	if len(ctx.draw_calls) > 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		last.length = len(ctx.vertices)-last.offset
	}

	ok := platform_draw(ctx)
	clear(&ctx.vertices)
	clear(&ctx.draw_calls)
	return ok
}
