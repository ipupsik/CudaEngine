//
// Created by dev on 8/27/22.
//

#include "../../shader/all.h"
#include "../../util/const.h"
#include "../misc/image.cuh"
#include "rasterizer.h"
#include <glm/glm.hpp>

template <typename ShaderType>
__forceinline__ __device__ void triangle(DrawCallBaseArgs &args, ModelDrawCallArgs &model_args, int position, Image &image, ZBuffer &zbuffer) {

	auto light_dir = args.light_dir;
	auto &model = model_args.model;

	auto sh = BaseShader<ShaderType>(model, light_dir, args.projection, args.view, model_args.model_matrix, args.screen_size, args, position);

	for (int i = 0; i < 3; i++)
		sh.vertex(position, i, true);

	auto &pts = sh.pts;
	glm::vec3 n = glm::cross(pts[2] - pts[0], pts[1] - pts[0]);
	glm::vec3 look_dir = args.look_at - args.camera_pos;
	if (glm::dot(look_dir, {0, 0, 1}) > 0)
		n = -n;
	if (glm::dot(n, look_dir) < 0)
		return;

	auto &normals = sh.normals;
	auto &textures = sh.textures;

	if (pts[0].y==pts[1].y && pts[0].y==pts[2].y) return;

	glm::vec2 bboxmin{float(image.width-1),  float(image.height-1)};
	glm::vec2 bboxmax{0., 0.};
	glm::vec2 clamp{float(image.width-1), float(image.height-1)};
	for (auto &pt : pts) {
		bboxmin.x = max(0.0f, min(bboxmin.x, pt.x));
		bboxmin.y = max(0.0f, min(bboxmin.y, pt.y));

		bboxmax.x = min(clamp.x, max(bboxmax.x, pt.x));
		bboxmax.y = min(clamp.y, max(bboxmax.y, pt.y));
	}

	glm::vec3 P{0, 0, 0};

	int cnt = 0;
	for (P.x=floor(bboxmin.x); P.x <= bboxmax.x; P.x++) {
		for (P.y=floor(bboxmin.y); P.y <= bboxmax.y; P.y++) {
			auto bc_screen  = barycentric(pts[0], pts[1], pts[2], P);

			if (bc_screen.x < 0 || bc_screen.y < 0 || bc_screen.z < 0)
				continue;

			auto bc_clip = glm::vec3(bc_screen[0]/pts[0].z, bc_screen[1]/pts[1].z, bc_screen[2]/pts[2].z);
			bc_clip = bc_clip / (bc_clip.x + bc_clip.y + bc_clip.z);

			P.z = 0;
			for (int i = 0; i < 3; i++)
				P.z += pts[i].z * bc_clip[i];

			if (zbuffer.zbuffer[int(P.x + P.y* image.width)] == P.z) {
				uint color;
				sh.fragment(bc_clip, color, P.z);
				image.set((int)P.x, (int)P.y, color);
			}

			cnt++;
			if (cnt > MAX_PIXELS_PER_KERNEL)
				return;
		}
	}
}



template <typename ShaderType>
__global__ void draw_faces(DrawCallBaseArgs args, ModelDrawCallArgs model_args, Image image, ZBuffer zbuffer) {
	int position = blockIdx.x * blockDim.x + threadIdx.x;
	auto model = model_args.model;
	if (position >= model.n_faces)
		return;
	triangle<ShaderType>(args, model_args, position, image, zbuffer);
}

template <typename ShaderType>
__global__ void draw_faces_mask(DrawCallBaseArgs args, ModelDrawCallArgs model_args, Image image, ZBuffer zbuffer) {
	int position = blockIdx.x * blockDim.x + threadIdx.x;
	auto model = model_args.model;
	if (position >= model.n_faces)
		return;
	bool should_draw = model_args.disabled_faces[position];
	if (should_draw)
		return;
	//if (!model.is_virtual)
	//	return;
	triangle<ShaderType>(args, model_args, position, image, zbuffer);
}

void Rasterizer::async_rasterize(DrawCallArgs &args, int model_index, Image image, ZBuffer zbuffer)
{
	auto &model_args = args.models[model_index];
	auto &model = model_args.model;
	auto n_grid = get_grid_size(model.n_faces);
	auto n_block = get_block_size(model.n_faces);

	if (model_args.disabled_faces == nullptr) {
		switch (model.shader) {
			case RegisteredShaders::Default:
				draw_faces<ShaderDefault><<<n_grid, n_block, 0, stream>>>(args.base, model_args, image, zbuffer);
				break;
			case RegisteredShaders::Water:
				draw_faces<ShaderWater><<<n_grid, n_block, 0, stream>>>(args.base, model_args, image, zbuffer);
				break;
			case RegisteredShaders::VGeom:
				draw_faces<ShaderVGeom><<<n_grid, n_block, 0, stream>>>(args.base, model_args, image, zbuffer);
				break;
		}
	}
	else {
		switch (model.shader) {
			case RegisteredShaders::Default:
				draw_faces_mask<ShaderDefault><<<n_grid, n_block, 0, stream>>>(args.base, model_args, image, zbuffer);
				break;
			case RegisteredShaders::Water:
				draw_faces_mask<ShaderWater><<<n_grid, n_block, 0, stream>>>(args.base, model_args, image, zbuffer);
				break;
			case RegisteredShaders::VGeom:
				draw_faces_mask<ShaderVGeom><<<n_grid, n_block, 0, stream>>>(args.base, model_args, image, zbuffer);
				break;
		}
	}
}

