/*
 * MatrixString.h
 *
 *  Created on: 16 Jun 2020
 *      Author: xasin
 */

#ifndef MATRIXPLAYGROUND_MATRIXSTRING_H_
#define MATRIXPLAYGROUND_MATRIXSTRING_H_

#include <Animation/AnimationElement.h>
#include <tef/led/GenericMatrix.h>

#include <string>

namespace TEF {
namespace Animation {

class MatrixString: public AnimationElement {
public:
	LED::GenericMatrix &matrix;

	std::string current_str;
	float pos_x, pos_y, alignment;
	float scroll_speed;

	LED::Colour print_colour;

	MatrixString(AnimationServer &server, animation_id_t ID, LED::GenericMatrix &matrix);

	float *get_flt(animation_value_id_t val);
	LED::Colour *get_color(uint8_t val);

	void set_string(const char *str);

	void tick(float delta_t);
};

}
}
#endif /* MATRIXPLAYGROUND_MATRIXSTRING_H_ */
