
$coordinate_def ||= {
	x: 0,
	y: 1,
}

# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	# Animation-Related Module
	#
	# This module wraps all classes related to TEF 'Synth'-Line animation.
	# They are meant to provide an abstraction layer over the hardware-implemented
	# animations that run on slave devices, such as the FurComs-Connected Synth Bit,
	# and give the user full access to high-level functions such as configuring
	# named parameters, setting up value smoothing and transitions, and
	# creating and deleting objects.
	module Animation
		class Coordinate
			$coordinate_def.each do |c, id|
				define_method(c.to_s) do
					@animatable_attributes[c]
				end

				define_method("#{c}=") do |arg|
					if arg.is_a? Numeric
						@animatable_attributes[c].add = arg
					else
						@animatable_attributes[c].from = arg
					end
				end
			end

			def initialize(start_offset)
				@animatable_attributes = {}

				$coordinate_def.each do |key, v|
					@animatable_attributes[key] = Value.new(v + start_offset)
				end
			end

			def animatable_attributes
				@animatable_attributes.values
			end

			def configure(data)
				raise ArgumentError, 'Coordinate config must be a hash!' unless data.is_a? Hash

				data.each do |key, value|
					coord = @animatable_attributes[key]

					raise ArgumentError, "Coordinate #{key} does not exist!" unless coord

					coord.configure value
				end
			end
		end
	end
end
