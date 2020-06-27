
require_relative 'Animatable.rb'

module TEF
	module Animation
		class StringDisplay < Animatable
			animatable_color :color, 0

			animatable_attr :x, 1
			animatable_attr :y, 2
			animatable_attr :alignment, 3

			attr_reader :string

			def initialize()
				super();

				self.string = "";
			end

			def string=(new_string)
				return if new_string == @string
				@string = new_string
				
				@animatable_pending_strings = [new_string]
			end
		end
	end
end
