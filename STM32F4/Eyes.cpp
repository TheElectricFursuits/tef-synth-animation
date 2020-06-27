/*
 * Eyes.cpp
 *
 *  Created on: 17 May 2020
 *      Author: xasin
 */

#include <Animation/Eyes.h>
#include <math.h>

extern const uint8_t console_font[];

namespace TEF {
namespace Animation {

Eyes::Eyes(AnimationServer &server, animation_id_t ID, LED::GenericMatrix &target_matrix)
	: AnimationElement(server, ID),
	  matrix(target_matrix), offset(30), outer_color(0x9900AA), inner_color(0),
	  iris_x(3) {

	emotions = {
			(eye_shape_def){ &angry_eye, 0 },
			(eye_shape_def){ &happy_eye, 0 },
			(eye_shape_def){ &heart_eye, 0 },
			(eye_shape_def){ &surprised_eye, 0},
			(eye_shape_def){ &shy_eye, 0}
	};

	blush_colour = Material::PINK;
}

float *Eyes::get_flt(animation_value_id_t val) {
	if(val - 0x100 >= 0 && val - 0x100 < emotions.size())
		return &(emotions[val - 0x100].expressiveness);

	switch(val) {
	case 0x000:
		return &iris_x;
	default: return nullptr;
	}
}

LED::Colour * Eyes::get_color(uint8_t val) {
	switch(val) {
	default:
		return nullptr;
	case 0:
		return &outer_color;
	case 1:
		return &inner_color;
	case 2:
		return &blush_colour;
	}
}

void add_shapes(eye_shape &source, const eye_shape *to_add, float fact) {
	if(fact < 0.1)
		return;

	for(unsigned int i=0; i<source.size(); i++)
		source[i] += (*to_add)[i] * fact;
}

void Eyes::draw_total_eye(const eye_shape &total_eye) {
	for(unsigned int i=0; i<total_eye.size(); i += 2) {
		if(total_eye[i] >= total_eye[i+1])
			continue;

		for(int y=ceilf(total_eye[i]); y < floorf(total_eye[i + 1]); y++) {
			matrix.set_colour(i/2 + 18, y + 1, outer_color);
		}

		const LED::Colour &o_c = outer_color;

		matrix.set_colour(i/2 + 18, floorf(total_eye[i]) + 1, o_c.bMod(1 - fmodf(total_eye[i], 1)));
		matrix.set_colour(i/2 + 18, floorf(total_eye[i+1]) + 1, o_c.bMod(fmodf(total_eye[i+1], 1)));
	}
}

void Eyes::calculate_blink(eye_shape &total_eye) {
	float eye_close_factor =  1.3 - fabsf(fmodf(server.get_synch_time(), 10) - 5) * 15;

	if(eye_close_factor > 0) {
		float top_fact_top     = 1 - 0.7 * eye_close_factor;
		float top_fact_bottom  = 0.7 * eye_close_factor;

		float bottom_fact_top    = 0.3 * eye_close_factor;
		float bottom_fact_bottom = 1 - 0.7 * eye_close_factor;

		for(unsigned int i=0; i<total_eye.size(); i += 2) {
			total_eye[i] = total_eye[i] * top_fact_top + total_eye[i+1] * top_fact_bottom;
			total_eye[i+1] = total_eye[i] * bottom_fact_top + total_eye[i+1] * bottom_fact_bottom;
		}
	}
}

void Eyes::draw_blush() {
	if(blush_colour.alpha < 0.1)
		return;

	for(int y=0; y<3; y++) {
		for(int x = 0; x<5; x++) {
			matrix.set_colour(3*x - y + 17, y + 9, blush_colour);
		}
	}
}

void Eyes::tick(float delta_t) {
	// float c_cycle = server.get_synch_time()/6;
	// emotions[static_cast<int>(floorf(c_cycle)) % emotions.size()].expressiveness = 6 - 10*cosf(2 * M_PI * (c_cycle));

	eye_shape total_eye = { 0.01, -0.01, 0.1, -0.1, 0.1, -0.1,0.1, -0.1,0.1, -0.1,0.1, -0.1,0.1, -0.1,0.1, -0.1,0.1, -0.1,0.1, -0.1,0.1, -0.1,};

	float expression_sum = 0;
	for(const auto &shape : emotions)
		expression_sum += std::max(shape.expressiveness, 0.0F);

	add_shapes(total_eye, &relaxed_eye, std::max(0.0F, 1 - expression_sum));

	expression_sum = std::max(expression_sum, 1.0F);

	for(const auto &shape : emotions) {
		add_shapes(total_eye, shape.shape, shape.expressiveness / expression_sum);
	}

	calculate_blink(total_eye);

	int rounded_iris = roundf(iris_x);
	if(rounded_iris >= 0 && rounded_iris <= total_eye.size()/2-1) {
		total_eye[rounded_iris*2] = std::max(total_eye[rounded_iris*2], total_eye[rounded_iris*2+1]-0.1F);
	}

	draw_total_eye(total_eye);

	draw_blush();
}

}
} /* namespace Xasin */
