/*
 * MatrixString.cpp
 *
 *  Created on: 16 Jun 2020
 *      Author: xasin
 */

#include <Animation/MatrixString.h>

#include <cmath>

extern uint8_t console_font[];

namespace TEF {
namespace Animation {

MatrixString::MatrixString(AnimationServer &server, animation_id_t ID, LED::GenericMatrix &matrix)
	: AnimationElement(server, ID), matrix(matrix), current_str("") {

	pos_x = 0;
	pos_y = 8;
	alignment = 0;

	scroll_speed = 0;

	print_colour = 0;
}

float *MatrixString::get_flt(animation_value_id_t val) {
	switch(val) {
	case 1: return &pos_x;
	case 2: return &pos_y;
	case 3: return &alignment;
	case 4: return &scroll_speed;

	default: return nullptr;
	}
}

LED::Colour *MatrixString::get_color(uint8_t val) {
	if(val == 0)
		return &print_colour;

	return nullptr;
}

void MatrixString::set_string(const char *str) {
	if(str == nullptr)
		current_str = "";
	else
		current_str = str;
}

void MatrixString::tick(float delta_t) {
	const float font_width = 6;

	const float str_width = current_str.length() * font_width;

	if(fabsf(scroll_speed) > 0.1 && !current_str.empty()) {
		pos_x -= scroll_speed * delta_t;

		if(pos_x + (1 - alignment)*str_width < matrix.width) {
			pos_x += str_width - font_width * 6;
		}
	}

	matrix.draw_string(current_str.data(), console_font, pos_x - alignment*str_width, pos_y, 6, 8, print_colour);
}

}
}
