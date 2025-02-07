//
// Created by dev on 10/4/22.
//

#ifndef COURSE_RENDERER_SCENE_LOADER_H
#define COURSE_RENDERER_SCENE_LOADER_H

#include <functional>
#include <string>

#include "../util/singleton.h"

class SceneLoader {
private:
	std::unordered_map<std::string, std::function<void()>> load_callbacks;
	std::function<bool()> can_load_scene = []() { return false; };
public:
	SceneLoader() = default;
	void display_widget();
	void load_scene(const std::string &name);
	void register_load_scene(const std::string &name, const std::function<void()> &callback);
	void register_can_load_scene(const std::function<bool()> &callback);
};


using SceneLoaderSingleton = SingletonCreator<SceneLoader>;

#endif//COURSE_RENDERER_SCENE_LOADER_H
