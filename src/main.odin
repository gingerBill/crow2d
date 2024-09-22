package main

import gordon "../gordon2d"
import "core:math"
import "core:fmt"
_ :: math
_ :: fmt

// import "vendor:stb/easy_font"

ctx0: gordon.Context

puppy: gordon.Texture
puppy_data := #load("puppy.png")

@(fini)
fini :: proc() {
	gordon.texture_unload(puppy)

	gordon.fini(&ctx0)
}


player_pos: gordon.Vec2
player_size :: gordon.Vec2{64, 64}
player_speed :: 500
ground := f32(0)
y_velocity := f32(0)
jump_height :: -500
gravity :: -1000

main :: proc() {
	gordon.init(&ctx0, "canvas0",
	init = proc(ctx: ^gordon.Context) -> bool {
		puppy = gordon.texture_load_from_memory(puppy_data) or_return

		width := ctx.canvas_width
		height := ctx.canvas_height

		player_pos = {width*0.5, height*0.5 - player_size.y}
		ground = player_pos.y

		return true
	},
	update = proc(ctx: ^gordon.Context, dt: f32) {
		width := ctx.canvas_width
		height := ctx.canvas_height


		gordon.draw_rect(ctx, {0, ground+player_size.y}, {width, height-ground-player_size.y}, {255, 255, 255, 255})
		gordon.draw_rect_textured(ctx, player_pos, player_size, puppy, {200, 200, 200, 255})

		// if gamepad := &ctx.io.gamepads[0]; gamepad.connected && gamepad.buttons_pressed != nil {
		// 	fmt.println(gamepad.buttons_pressed)
		// }
		if gamepad := &ctx.io.gamepads[0]; gamepad.connected {
			value := gamepad.axis_values[.Left_X]
			if abs(value) < 0.2 {
				value = 0
			}
			player_pos.x += player_speed*dt * value

			if .A in gamepad.buttons_pressed {
				if y_velocity == 0 {
					y_velocity = jump_height
				}
			}
		}

		// ctx.camera.zoom = f32(math.cos(ctx.curr_time) + 2)*2
		// ctx.camera.target.x = f32(math.cos(ctx.curr_time))*50
		// ctx.camera.target.y = f32(math.sin(ctx.curr_time))*50

		// @static pos := gordon.Vec2{200, 200}
		// @static col := gordon.Colour{0, 255, 0, 255}

		// if .W in ctx.io.key_down {
		// 	player_pos.y -= player_speed*dt
		// }
		// if .S in ctx.io.key_down {
		// 	player_pos.y += player_speed*dt
		// }
		if ctx.io.key_down & {.D, .Right} != nil {
			if player_pos.x + player_size.x < width {
				player_pos.x += player_speed*dt
			}
		}
		if ctx.io.key_down & {.A, .Left} != nil {
			if player_pos.x > 0 {
				player_pos.x -= player_speed*dt
			}
		}
		if .Space in ctx.io.key_pressed {
			if y_velocity == 0 {
				y_velocity = jump_height
			}
		}

		if y_velocity != 0 {
			player_pos.y += y_velocity * dt
			y_velocity -= gravity * dt
		}

		player_pos.x = clamp(player_pos.x, 0, width-player_size.x-1)
		if player_pos.y > ground {
			player_pos.y = ground
			y_velocity = 0
		}
		player_pos.y = clamp(player_pos.y, 0, ground)


		// gordon.draw_circle(ctx, pos + {100, 0}, 40, col.gbra)

		// gordon.draw_rect_textured(ctx, {500, 500}, {128, 128}, puppy)

		// gordon.draw_rect_rotated(ctx, {400, 400}, {32, 64}, {16, 32}, f32(ctx.curr_time), {255, 0, 255, 255})
		// gordon.draw_rect_rotated_outlines(ctx, {400, 400}, {32, 64}, {16, 32}, f32(ctx.curr_time), 10, {0, 0, 255, 127})

		// gordon.draw_line(ctx, {20, 20}, {100, 200}, 4, {255, 128, 0, 255} if ctx.click else {0, 255, 128, 255})

		// gordon.draw_circle(ctx, pos, 40, col)

		// gordon.draw_spline_catmull_rom(ctx, {
		// 		{10, 10},
		// 		{10, 10},
		// 		{100, 200},
		// 		{50, 300},
		// 		{500, 150},
		// 		{100, 300},

		// 	},
		// 	20,
		// 	{255, 0, 0, 255},
		// )

		// {
		// 	@static quads: [1000]easy_font.Quad

		// 	size := f32(100)/12.0

		// 	t_pos := [2]f32{60, 60}
		// 	num_quads := easy_font.print(t_pos.x, t_pos.y, "Hellope!", {0, 0, 0, 255}, quads[:])

		// 	for q, _ in quads[:num_quads] {
		// 		q_pos := q.tl.v.xy
		// 		q_size := q.br.v.xy - q_pos

		// 		q_pos -= t_pos
		// 		q_pos *= size
		// 		q_pos += t_pos

		// 		q_size *= size

		// 		gordon.draw_rect(ctx, q_pos, q_size, cast(gordon.Colour)q.tl.c)
		// 	}
		// }



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

