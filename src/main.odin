package main

import gordon "../gordon2d"
import "core:math"
import "core:fmt"
_ :: math
_ :: fmt

ctx0: gordon.Context

@(fini)
fini :: proc() {
	gordon.fini(&ctx0)
}


main :: proc() {
	gordon.init(&ctx0, "canvas0", proc(ctx: ^gordon.Context, dt: f32) {
		// ctx.curr_depth = +1
		// ctx.camera.zoom = f32(math.cos(ctx.curr_time) + 2)*2
		// ctx.camera.target.x = f32(math.cos(ctx.curr_time))*50
		// ctx.camera.target.y = f32(math.sin(ctx.curr_time))*50

		@static pos := gordon.Vec2{200, 200}
		@static col := gordon.Colour{0, 255, 0, 255}

		if .Up in ctx.io.key_down {
			pos.y -= 1000*dt
		}
		if .Down in ctx.io.key_down {
			pos.y += 1000*dt
		}
		if .Left in ctx.io.key_down {
			pos.x -= 1000*dt
		}
		if .Right in ctx.io.key_down {
			pos.x += 1000*dt
		}
		if .Left in ctx.io.mouse_pressed {
			col.rgb = col.brg
		}

		gordon.draw_rect_rotated(ctx, {400, 400}, {32, 64}, {16, 32}, f32(ctx.curr_time), {255, 0, 255, 255})
		gordon.draw_rect_rotated_outlines(ctx, {400, 400}, {32, 64}, {16, 32}, f32(ctx.curr_time), 10, {0, 0, 255, 127})

		gordon.draw_line(ctx, {20, 20}, {100, 200}, 4, {255, 128, 0, 255} if ctx.click else {0, 255, 128, 255})

		gordon.draw_circle(ctx, pos, 40, col)


		gordon.draw_spline_catmull_rom(ctx, {
				{10, 10},
				{10, 10},
				{100, 200},
				{50, 300},
				{500, 150},
				{100, 300},

			},
			20,
			{255, 0, 0, 255},
		)

		gordon.draw_rect_textured(ctx, {500, 500}, {128, 128}, ctx.default_texture)

		// gordon.draw_sector(ctx, {100, 100}, 40, 0, 0.75*math.TAU, {255, 0, 0, 255})
		// gordon.draw_sector_outline(ctx, {100, 100}, 40, 10, 0, 0.75*math.TAU, {255, 255, 0, 255})

		// gordon.draw_rect(ctx, {200, 100}, {300, 200}, {50, 175, 240, 255})
		// gordon.draw_rect(ctx, {400, 200}, {300, 200}, {175, 240, 50, 128})
		// gordon.draw_rect_outlines(ctx, {400, 200}, {300, 200}, 10, {255, 128, 0, 200})

		// gordon.draw_quad(ctx, {
		// 	{pos = { 10, 100, 0}, col = {255,   0,   0, 255}},
		// 	{pos = {100, 100, 0}, col = {255, 255,   0, 255}},
		// 	{pos = {100,  10, 0}, col = {  0, 255,   0, 255}},
		// 	{pos = { 10,  10, 0}, col = {  0,   0, 255, 255}},
		// })

	})
}

