#include "../../model/inc/model.h"
#include "../../render/zbuffer/zbuffer.h"
#include "../../util/stream_manager.h"
#include "../inc/matrix.cuh"
#include "../inc/render.cuh"
#include "../inc/shader_impl.cuh"
#include <helper_functions.h>
#include <helper_math.h>

__device__ __constant__ mat<4,4> viewport_matrix{};
__device__ mat<4,4> projection_matrix{};
__device__ mat<4,4> view_matrix{};


__device__ void line(Image &image, int x0, int y0, int x1, int y1) {
	bool steep = false;
	if (std::abs(x0-x1)<std::abs(y0-y1)) {
		swap(x0, y0);
		swap(x1, y1);
		steep = true;
	}
	if (x0>x1) {
		swap(x0, x1);
		swap(y0, y1);
	}
	__syncthreads();

	uint color = rgbaFloatToInt(float4{1.0f, 1.0f, 1.0f, 1.0f});

	for (int x=x0; x<=x1; x++) {
		float t = (x-x0)/(float)(x1-x0);
		int y = y0*(1.-t) + y1*t;
		int x_draw = y * steep + x * (1 - steep);
		int y_draw = x * steep + y * (1 - steep);
		image.set(x_draw, y_draw, color);
	}
}

void render_init(int width, int height)
{
	int depth = 255;
	mat<4,4> ViewPort = viewport(width/8, height/8, width*3/4, height*3/4, depth);
	cudaMemcpyToSymbol(
	        viewport_matrix,
	        &ViewPort,
	        sizeof(mat<4,4>)
	        );
}

void update_device_parameters(const DrawCallArgs &args)
{
	mat<4,4> Projection = identity_matrix<4>();

	Projection.at(3, 2) = -1.f / args.base.camera_pos.z;
	cudaMemcpyToSymbol(
	        projection_matrix,
	        &Projection,
	        sizeof(mat<4,4>)
	        );

	mat<4,4> View = lookat(args.base.camera_pos, args.base.look_at, {0, 1, 0});
	cudaMemcpyToSymbol(
        view_matrix,
        &View,
        sizeof(mat<4,4>)
        );
}