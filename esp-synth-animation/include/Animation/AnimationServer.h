/*
 * AnimatorServer.h
 *
 *  Created on: 15 Mar 2020
 *      Author: xasin
 */

#ifndef STM32F4_NEOCONTROLLER_ANIMATORSERVER_H_
#define STM32F4_NEOCONTROLLER_ANIMATORSERVER_H_

#include "tef/led/Colour.h"

#include <stdint.h>
#include <vector>

#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

namespace TEF {
namespace Animation {

union animation_id_t {
	struct {
		uint8_t set_id;
		uint8_t module_id;
	};
	uint16_t uniq_id;
};

typedef uint16_t animation_value_id_t;

struct animation_global_id_t {
	animation_value_id_t value;
	animation_id_t ID;
};

struct animation_copy_op {
	animation_global_id_t from_id;
	animation_value_id_t  to_value;
	const float * from;
	float * to;

	float add_offset;
	float mult_offset;
	float pt2_d;
	float pt2_t;
	float pt2_speed;
};
struct animation_color_op {
	LED::Colour * to;
	LED::Colour target_color;
	LED::Colour intermediate_color;

	float f1;
	float f2;
};

class AnimationElement;

class AnimationServer {
protected:
	friend AnimationElement;

	std::vector<AnimationElement *> animations;
	SemaphoreHandle_t animations_mutex;

	bool needs_relink;
	bool needs_deletion;

	float synch_time;

	void remove_pointer(AnimationElement * elem);
	void insert_pointer(AnimationElement * elem);

public:
	AnimationServer();

	void force_relink();

	AnimationElement * get_animation(animation_id_t id);
	void delete_animation(animation_id_t id);
	void delete_animation_set(uint8_t set_no);

	float * get_float_ptr(animation_global_id_t id);

	void  tick(float delta_t);
	float get_synch_time();

	void handle_set_command(const char *command);
	void handle_color_set_command(const char *command);
	void handle_string_set_command(const char *cmd);

	void handle_delete_command(const char *command);
	void handle_dtime_command(const char *command);

	bool parse_command(const char *topic, const char *command);

	static animation_global_id_t decode_value_tgt(const char *str);

};

}
} /* namespace Xasin */

#endif /* STM32F4_NEOCONTROLLER_ANIMATORSERVER_H_ */
