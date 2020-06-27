
require_relative 'Animatable.rb'

# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	module Animation
		class Eye < Animatable
			animatable_color :outer_color, 0
			animatable_color :inner_color, 1
			animatable_color :blush, 2

			animatable_attr :iris_x, 0x0

			animatable_attr :angry, 0x100
			animatable_attr :happy, 0x101
			animatable_attr :heart, 0x102
			animatable_attr :surprised, 0x103
			animatable_attr :shy, 0x104

			def initialize()
				super();

				@last_mood = :relaxed;
				@animatable_colors[:blush].configure({ target: 0xFF000000, delay_a: 1 });
			end

			def set_mood(mood, amount: 1)
				if @last_mood != :relaxed
					@animatable_attributes[@last_mood].add = 0;
				end

				return if mood.nil?
				@last_mood = mood.to_sym;

				return if @last_mood == :relaxed

				self.configure({ @last_mood.to_sym => { add: amount, dampen: 0.1 }});
			end
		end
	end
end
