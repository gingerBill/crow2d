package crowd2d

import "core:math"
import "core:math/linalg"

@(require_results)
default_draw_call :: proc(ctx: ^Context) -> Draw_Call {
	return Draw_Call{
		shader     = ctx.default_shader,
		texture    = ctx.default_texture,

		depth_test = false,

		offset     = len(ctx.vertices),
		length     = 0,
	}
}

set_shader :: proc(ctx: ^Context, shader: Shader) -> (prev: Shader) {
	prev = ctx.default_shader
	dc := default_draw_call(ctx)
	if len(ctx.draw_calls) != 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		prev = last.shader
		if last.shader == shader {
			return
		}
		last.length = len(ctx.vertices)-last.offset
		dc = last^
	}
	dc.shader = shader
	dc.offset = len(ctx.vertices)
	append(&ctx.draw_calls, dc)
	return
}

set_texture :: proc(ctx: ^Context, texture: Texture) -> (prev: Texture) {
	texture := texture
	if texture.handle == HANDLE_INVALID {
		texture = ctx.default_texture
	}

	prev = ctx.default_texture
	dc := default_draw_call(ctx)
	if len(ctx.draw_calls) != 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		prev = last.texture
		if last.texture == texture {
			return
		}
		last.length = len(ctx.vertices)-last.offset
		dc = last^
	}
	dc.texture = texture
	dc.offset = len(ctx.vertices)
	append(&ctx.draw_calls, dc)
	return
}

set_depth_test :: proc(ctx: ^Context, depth_test: bool) -> (prev: bool) {
	prev = false
	dc := default_draw_call(ctx)
	if len(ctx.draw_calls) != 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		prev = last.depth_test
		if last.depth_test == depth_test {
			return
		}
		last.length = len(ctx.vertices)-last.offset
		dc = last^
	}
	dc.depth_test = depth_test
	dc.offset = len(ctx.vertices)
	append(&ctx.draw_calls, dc)
	return
}

sort_draw_calls :: proc(draw_calls: ^[dynamic]Draw_Call) {
	// for i := 1; i < len(draw_calls); /**/ {
	// 	a := &draw_calls[i-1]
	// 	b := &draw_calls[i]
	// 	if a.shader == b.shader &&
	// 	   a.texture == b.texture &&
	// 	   a.depth_test == b.depth_test &&
	// 	   a.layer == b.layer {
	// 		if a.offset+a.length == b.offset {
	// 			a.length += b.length
	// 			ordered_remove(draw_calls, i)
	// 			continue
	// 		}
	// 		if b.offset+b.length == a.offset {
	// 			a.offset = b.offset
	// 			a.length = a.length+b.length
	// 			ordered_remove(draw_calls, i)
	// 			continue
	// 		}
	// 	}
	// 	i += 1
	// }
}



@(private="file")
check_draw_call :: proc(ctx: ^Context) {
	set_texture(ctx, ctx.default_texture)
}



@(private)
rotate_vectors :: proc(ctx: ^Context, offset: int, pos, origin: Vec2, rotation: f32) {
	s, c := math.sincos(rotation)
	for &v in ctx.vertices[offset:] {
		p := v.pos.xy - pos - origin
		p = {c*p.x - s*p.y, s*p.x + c*p.y}
		p.xy += pos
		v.pos.xy = p
	}
}


draw_rect :: proc(
	ctx: ^Context, pos: Vec2, size: Vec2,
	origin   := Vec2{0, 0},
	rotation := f32(0),
	texture  := TEXTURE_INVALID,
	uv0      := Vec2{0, 0},
	uv1      := Vec2{1, 1},
	color    := WHITE,
) {
	set_texture(ctx, texture)

	offset := len(ctx.vertices)

	a := pos
	b := pos + {size.x, 0}
	c := pos + {size.x, size.y}
	d := pos + {0, size.y}

	z := ctx.curr_z

	append(&ctx.vertices, Vertex{pos = {a.x, a.y, z}, col = color, uv = {uv0.x, uv0.y}})
	append(&ctx.vertices, Vertex{pos = {b.x, b.y, z}, col = color, uv = {uv1.x, uv0.y}})
	append(&ctx.vertices, Vertex{pos = {c.x, c.y, z}, col = color, uv = {uv1.x, uv1.y}})

	append(&ctx.vertices, Vertex{pos = {c.x, c.y, z}, col = color, uv = {uv1.x, uv1.y}})
	append(&ctx.vertices, Vertex{pos = {d.x, d.y, z}, col = color, uv = {uv0.x, uv1.y}})
	append(&ctx.vertices, Vertex{pos = {a.x, a.y, z}, col = color, uv = {uv0.x, uv0.y}})
	rotate_vectors(ctx, offset, pos, origin, rotation)
}

draw_rect_outline :: proc(
	ctx: ^Context, pos: Vec2, size: Vec2, thickness: f32,
	origin   := Vec2{0, 0},
	rotation := f32(0),
	color    := WHITE,
) {
	offset := len(ctx.vertices)

	draw_rect(ctx, pos + {0, -thickness}, {size.x+thickness, thickness}, color=color)
	draw_rect(ctx, pos + {size.x, 0}, {thickness, size.y+thickness}, color=color)

	draw_rect(ctx, pos + {-thickness, size.y}, {size.x+thickness, thickness}, color=color)
	draw_rect(ctx, pos + {-thickness, -thickness}, {thickness, size.y+thickness}, color=color)

	for &v in ctx.vertices[offset:] {
		v.uv = {0, 0}
	}
	rotate_vectors(ctx, offset, pos, origin, rotation)
}



draw_quad :: proc(ctx: ^Context, verts: [4]Vec2, color: Color, tex := TEXTURE_INVALID, uvs := [4]Vec2{}) {
	set_texture(ctx, tex)

	z := ctx.curr_z

	a := Vertex{pos = {verts[0].x, verts[0].y, z}, uv = uvs[0], col = color}
	b := Vertex{pos = {verts[1].x, verts[1].y, z}, uv = uvs[1], col = color}
	c := Vertex{pos = {verts[2].x, verts[2].y, z}, uv = uvs[2], col = color}
	d := Vertex{pos = {verts[3].x, verts[3].y, z}, uv = uvs[3], col = color}

	append(&ctx.vertices, a, b, c)
	append(&ctx.vertices, c, d, a)
}


draw_convex_polygon :: proc(ctx: ^Context, vertices: []Vertex, tex := TEXTURE_INVALID) {
	set_texture(ctx, tex)

	for i in 0..<len(vertices)-2 {
		append(&ctx.vertices, vertices[0], vertices[i+1], vertices[i+2])
	}
}

draw_line :: proc(ctx: ^Context, start, end: Vec2, thickness: f32, col: Color) {
	check_draw_call(ctx)

	dx := end-start
	dy := linalg.normalize0(Vec2{-dx.y, +dx.x})

	t := dy*thickness*0.5
	a := start - t
	c := end   + t
	b := end   - t
	d := start + t

	z := ctx.curr_z

	append(&ctx.vertices, Vertex{pos = {a.x, a.y, z}, col = col, uv = {0, 0}})
	append(&ctx.vertices, Vertex{pos = {b.x, b.y, z}, col = col, uv = {1, 0}})
	append(&ctx.vertices, Vertex{pos = {c.x, c.y, z}, col = col, uv = {1, 1}})

	append(&ctx.vertices, Vertex{pos = {c.x, c.y, z}, col = col, uv = {1, 1}})
	append(&ctx.vertices, Vertex{pos = {d.x, d.y, z}, col = col, uv = {0, 1}})
	append(&ctx.vertices, Vertex{pos = {a.x, a.y, z}, col = col, uv = {0, 0}})
}

draw_circle :: proc(ctx: ^Context, centre: Vec2, radius: f32, col: Color, segments := 32) {
	draw_ellipse(ctx, centre, {radius, radius}, col, segments)
}


draw_ellipse :: proc(ctx: ^Context, centre: Vec2, #no_broadcast radii: Vec2, col: Color, segments := 32) {
	check_draw_call(ctx)


	c := Vertex{pos = {centre.x, centre.y, ctx.curr_z}, col = col}

	for i in 0..<segments {
		t0 := f32(i+0)/f32(segments) * math.TAU
		t1 := f32(i+1)/f32(segments) * math.TAU

		a := c
		b := c

		a.pos.x += radii.x * math.cos(t0)
		a.pos.y += radii.y * math.sin(t0)

		b.pos.x += radii.x * math.cos(t1)
		b.pos.y += radii.y * math.sin(t1)

		append(&ctx.vertices, c, a, b)
	}
}


draw_ring :: proc(ctx: ^Context, centre: Vec2, inner_radius, outer_radius: f32, angle_start, angle_end: f32, col: Color, segments := 32) {
	check_draw_call(ctx)

	p := Vertex{pos = {centre.x, centre.y, ctx.curr_z}, col = col}

	for i in 0..<segments {
		t0 := math.lerp(angle_start, angle_end, f32(i+0)/f32(segments))
		t1 := math.lerp(angle_start, angle_end, f32(i+1)/f32(segments))

		a := p
		b := p
		c := p
		d := p

		a.pos.x += outer_radius * math.cos(t0)
		a.pos.y += outer_radius * math.sin(t0)

		b.pos.x += outer_radius * math.cos(t1)
		b.pos.y += outer_radius * math.sin(t1)


		c.pos.x += inner_radius * math.cos(t1)
		c.pos.y += inner_radius * math.sin(t1)

		d.pos.x += inner_radius * math.cos(t0)
		d.pos.y += inner_radius * math.sin(t0)

		append(&ctx.vertices, a, b, c)
		append(&ctx.vertices, c, d, a)
	}
}

draw_sector :: proc(ctx: ^Context, centre: Vec2, radius: f32, angle_start, angle_end: f32, col: Color, segments := 32) {
	draw_ring(ctx, centre, 0, radius, angle_start, angle_end, col, segments)
}

draw_sector_outline :: proc(ctx: ^Context, centre: Vec2, radius: f32, thickness: f32, angle_start, angle_end: f32, col: Color, segments := 32) {
	draw_ring(ctx, centre, radius, radius+thickness, angle_start, angle_end, col, segments)
}

draw_ellipse_ring :: proc(ctx: ^Context, centre: Vec2, #no_broadcast inner_radii, outer_radii: Vec2, angle_start, angle_end: f32, col: Color, segments := 32) {
	check_draw_call(ctx)

	p := Vertex{pos = {centre.x, centre.y, ctx.curr_z}, col = col}

	for i in 0..<segments {
		t0 := math.lerp(angle_start, angle_end, f32(i+0)/f32(segments))
		t1 := math.lerp(angle_start, angle_end, f32(i+1)/f32(segments))

		a := p
		b := p
		c := p
		d := p

		a.pos.x += outer_radii.x * math.cos(t0)
		a.pos.y += outer_radii.y * math.sin(t0)

		b.pos.x += outer_radii.x * math.cos(t1)
		b.pos.y += outer_radii.y * math.sin(t1)


		c.pos.x += inner_radii.x * math.cos(t1)
		c.pos.y += inner_radii.y * math.sin(t1)

		d.pos.x += inner_radii.x * math.cos(t0)
		d.pos.y += inner_radii.y * math.sin(t0)

		append(&ctx.vertices, a, b, c)
		append(&ctx.vertices, c, d, a)
	}
}

draw_ellipse_arc :: proc(ctx: ^Context, centre: Vec2, radii: Vec2, thickness: f32, angle_start, angle_end: f32, col: Color, segments := 32) {
	draw_ellipse_ring(ctx, centre, radii, radii+thickness, angle_start, angle_end, col, segments)
}


draw_triangle :: proc(ctx: ^Context, v0, v1, v2: Vec2, col: Color) {
	check_draw_call(ctx)

	z := ctx.curr_z

	a := Vertex{pos = {v0.x, v0.y, z}, col = col}
	b := Vertex{pos = {v1.x, v1.y, z}, col = col}
	c := Vertex{pos = {v2.x, v2.y, z}, col = col}

	append(&ctx.vertices, a, b, c)
}


draw_triangle_lines :: proc(ctx: ^Context, v0, v1, v2: Vec2, thickness: f32, col: Color) {
	draw_line(ctx, v0, v1, thickness, col)
	draw_line(ctx, v1, v2, thickness, col)
	draw_line(ctx, v2, v0, thickness, col)
}


draw_triangle_strip :: proc(ctx: ^Context, points: []Vec2, col: Color) {
	if len(points) < 3 {
		return
	}

	check_draw_call(ctx)

	z := ctx.curr_z

	for i in 2..<len(points) {
		a, b, c: Vertex
		a.pos.z = z
		b.pos.z = z
		c.pos.z = z
		a.col = col
		b.col = col
		c.col = col

		if i&1 != 0 {
			a.pos.xy = points[i]
			b.pos.xy = points[i-2]
			c.pos.xy = points[i-1]
		} else {
			a.pos.xy = points[i]
			b.pos.xy = points[i-1]
			c.pos.xy = points[i-2]
		}
		append(&ctx.vertices, a, b, c)
	}
}


draw_line_strip :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Color) {
	if len(points) < 2 {
		return
	}

	check_draw_call(ctx)

	for i in 0..<len(points)-1 {
		draw_line(ctx, points[i], points[i+1], thickness, col)
	}
}


draw_spline_linear :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Color) {
	if len(points) < 2 {
		return
	}

	prev_normal := Vec2{-points[1].y + points[0].y, points[1].x - points[0].x}
	prev_normal = linalg.normalize0(prev_normal)

	prev_radius := 0.5*thickness*prev_normal

	for i in 0..<len(points)-1 {
		normal: Vec2
		if i < len(points)-2 {
			normal = Vec2{-points[i+2].y + points[i+1].y, points[i+2].x - points[i+1].x}
			normal = linalg.normalize0(normal)
		} else {
			normal = prev_normal
		}

		radius := linalg.normalize(prev_normal + normal)

		cos_theta := linalg.dot(radius, normal)
		if cos_theta != 0 {
			radius *= 0.5*thickness/cos_theta
		} else {
			radius = {0, 0}
		}

		strip := [4]Vec2{
			{points[i].x - prev_radius.x, points[i].y - prev_radius.y},
			{points[i].x + prev_radius.x, points[i].y + prev_radius.y},
			{points[i+1].x - radius.x,    points[i+1].y - radius.y},
			{points[i+1].x + radius.x,    points[i+1].y + radius.y},
		}

		draw_triangle_strip(ctx, strip[:], col)

		prev_radius = radius
		prev_normal = normal
	}
}


SPLINE_SEGMENT_DIVISIONS :: 24

draw_spline_basis :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Color) {
	if len(points) < 4 {
		return
	}

	a, b: [4]f32
	dy := f32(0)
	dx := f32(0)
	size := f32(0)

	curr_point: Vec2
	next_point: Vec2
	vertices: [2*SPLINE_SEGMENT_DIVISIONS + 2]Vec2

	for i in 0..<len(points)-3 {
		p0 := points[i+0]
		p1 := points[i+1]
		p2 := points[i+2]
		p3 := points[i+3]

		a[0] = (-p0.x + 3*p1.x - 3*p2.x + p3.x)/6
		a[1] = (3*p0.x - 6*p1.x + 3*p2.x)/6
		a[2] = (-3*p0.x + 3*p2.x)/6
		a[3] = (p0.x + 4*p1.x + p2.x)/6

		b[0] = (-p0.y + 3*p1.y - 3*p2.y + p3.y)/6
		b[1] = (3*p0.y - 6*p1.y + 3*p2.y)/6
		b[2] = (-3*p0.y + 3*p2.y)/6
		b[3] = (p0.y + 4*p1.y + p2.y)/6

		curr_point.x = a[3]
		curr_point.y = b[3]

		if i == 0 {
			draw_circle(ctx, curr_point, thickness*0.5, col)
		}

		if i > 0 {
			vertices[0].x = curr_point.x + dy*size
			vertices[0].y = curr_point.y - dx*size
			vertices[1].x = curr_point.x - dy*size
			vertices[1].y = curr_point.y + dx*size
		}

		for j in 1..=SPLINE_SEGMENT_DIVISIONS {
			t := f32(j)/f32(SPLINE_SEGMENT_DIVISIONS)

			next_point.x = a[3] + t*(a[2] + t*(a[1] + t*a[0]))
			next_point.y = b[3] + t*(b[2] + t*(b[1] + t*b[0]))

			dy = next_point.y - curr_point.y
			dx = next_point.x - curr_point.x
			size = 0.5*thickness/math.sqrt(dx*dx+dy*dy)

			if (i == 0) && (j == 1) {
				vertices[0].x = curr_point.x + dy*size
				vertices[0].y = curr_point.y - dx*size
				vertices[1].x = curr_point.x - dy*size
				vertices[1].y = curr_point.y + dx*size
			}

			vertices[2*j + 1].x = next_point.x - dy*size
			vertices[2*j + 1].y = next_point.y + dx*size
			vertices[2*j].x = next_point.x + dy*size
			vertices[2*j].y = next_point.y - dx*size

			curr_point = next_point
		}

	        draw_triangle_strip(ctx, vertices[:], col)
	}

	draw_circle(ctx, curr_point, thickness*0.5, col)
}

draw_spline_catmull_rom :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Color) {
	if len(points) < 4 {
		return
	}

	dy := f32(0)
	dx := f32(0)
	size := f32(0)

	curr_point := points[1]
	next_point: Vec2
	vertices: [2*SPLINE_SEGMENT_DIVISIONS + 2]Vec2

	draw_circle(ctx, curr_point, thickness*0.5, col)

	for i in 0..<len(points)-3 {
		p0 := points[i+0]
		p1 := points[i+1]
		p2 := points[i+2]
		p3 := points[i+3]

		if i > 0 {
			vertices[0].x = curr_point.x + dy*size
			vertices[0].y = curr_point.y - dx*size
			vertices[1].x = curr_point.x - dy*size
			vertices[1].y = curr_point.y + dx*size
		}

		for j in 1..=SPLINE_SEGMENT_DIVISIONS {
			t := f32(j)/f32(SPLINE_SEGMENT_DIVISIONS)

			q0 := (-1.0*t*t*t) + (2.0*t*t) + (-1.0*t)
			q1 := (3.0*t*t*t) + (-5.0*t*t) + 2.0
			q2 := (-3.0*t*t*t) + (4.0*t*t) + t
			q3 := t*t*t - t*t

			next_point.x = 0.5*((p0.x*q0) + (p1.x*q1) + (p2.x*q2) + (p3.x*q3))
			next_point.y = 0.5*((p0.y*q0) + (p1.y*q1) + (p2.y*q2) + (p3.y*q3))

			dy = next_point.y - curr_point.y
			dx = next_point.x - curr_point.x
			size = (0.5*thickness)/math.sqrt(dx*dx + dy*dy)

			if (i == 0) && (j == 1) {
				vertices[0].x = curr_point.x + dy*size
				vertices[0].y = curr_point.y - dx*size
				vertices[1].x = curr_point.x - dy*size
				vertices[1].y = curr_point.y + dx*size
			}

			vertices[2*j + 1].x = next_point.x - dy*size
			vertices[2*j + 1].y = next_point.y + dx*size
			vertices[2*j].x = next_point.x + dy*size
			vertices[2*j].y = next_point.y - dx*size

			curr_point = next_point
		}

	        draw_triangle_strip(ctx, vertices[:], col)
	}

	draw_circle(ctx, curr_point, thickness*0.5, col)
}