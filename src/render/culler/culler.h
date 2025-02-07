//
// Created by dev on 10/3/22.
//

#ifndef COURSE_RENDERER_CULLER_H
#define COURSE_RENDERER_CULLER_H
#include "../../camera/camera.h"
#include "../../model/inc/bounding_volume.h"
#include "../misc/draw_caller_args.cuh"
#include <glm/glm.hpp>
#include <vector>


Frustum frustum_from_camera(const Camera &cam);

class Culler {
public:
	DrawCallArgs cull(const DrawCallArgs &args, const Camera &cam);
};


#endif//COURSE_RENDERER_CULLER_H
