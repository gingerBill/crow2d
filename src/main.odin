package main

import crow "../crow2d"
import "core:math"
import "core:fmt"
_ :: math
_ :: fmt

// import "vendor:stb/easy_font"

ctx0: crow.Context

puppy: crow.Texture
puppy_data := #load("puppy.png")

@(fini)
fini :: proc() {
	crow.texture_unload(puppy)

	crow.fini(&ctx0)
}


player_pos: crow.Vec2
player_size :: crow.Vec2{64, 64}
player_speed :: 500
ground := f32(0)
y_velocity := f32(0)
jump_height :: -500
gravity :: -1000

roboto_font: crow.Font

main :: proc() {
	crow.init(&ctx0, "canvas0",
	init = proc(ctx: ^crow.Context) -> bool {
		puppy = crow.texture_load_from_memory(puppy_data) or_return

		width := ctx.canvas_width
		height := ctx.canvas_height

		player_pos = {width*0.5, height*0.5 - player_size.y}
		ground = player_pos.y


		ok: bool
		roboto_font, ok = crow.font_load_from_memory(#load("Roboto-Regular.ttf"), 64)

		return true
	},
	update = proc(ctx: ^crow.Context, dt: f32) {
		width := ctx.canvas_width
		height := ctx.canvas_height


		crow.draw_rect(ctx, {0, ground+player_size.y}, {width, height-ground-player_size.y})
		crow.draw_rect(ctx, player_pos, player_size, texture=puppy, color={200, 200, 200, 255})

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

		// @static pos := crow.Vec2{200, 200}
		// @static col := crow.Colour{0, 255, 0, 255}

		// if .W in ctx.io.key_down {
		// 	player_pos.y -= player_speed*dt
		// }
		// if .S in ctx.io.key_down {
		// 	player_pos.y += player_speed*dt
		// }
		if .Space in ctx.io.key_pressed {
			if y_velocity == 0 {
				y_velocity = jump_height
			}
		}
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

		if y_velocity != 0 {
			player_pos.y += y_velocity * dt
			y_velocity -= gravity * dt
		}

		player_pos.x = clamp(player_pos.x, 0, width-player_size.x)
		if player_pos.y > ground {
			player_pos.y = ground
			y_velocity = 0
		}
		player_pos.y = clamp(player_pos.y, 0, ground)

		crow.draw_text(ctx, &roboto_font, "Hellope!\nWhatever\tthe fuck", {60, 60}, crow.WHITE)



		crow.draw_rect(ctx, {500, 500}, {128, 128}, origin={64, 64}, rotation=-2*f32(ctx.curr_time), texture=puppy)

		crow.draw_rect(ctx, {400, 400}, {32, 64}, origin={16, 32}, rotation=f32(ctx.curr_time), color={255, 0, 255, 255})
		crow.draw_rect_outline(ctx, {400, 400}, {32, 64}, thickness=10, origin={16, 32}, rotation=f32(ctx.curr_time), color={0, 0, 255, 127})

		crow.draw_spline_catmull_rom(ctx, {
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
	})

	crow.start() // only needed on non-javascript platforms
}

