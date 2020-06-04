

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
		class Color
			PARAM_TYPES = [:jump, :velocity, :target, :delay_a, :delay_b];

			# @return [Integer] Hardware-Number of this Color
			attr_reader :ID

			# @return [String, nil] Module-ID of the {Animatable} that this
			#  color belongs to.
			attr_reader :module_id

			# @!attribute [rw] jump
			# Immediately set the color of this Color to the jump value,
			# skipping animation. If animation is set, the Color will then
			# fade back to the value defined by {#target}
			# @return [Numeric] Current RGB color code.

			# @!attribute [rw] velocity
			# Set the animation buffer to the given color. Has no effect
			# unless {#delay_b} was configued, in which case the animation will
			# temporarily fade to velocity, then fade back to {#target}
			# @return [Numeric] Current RGB color code.

			# @!attribute [rw] target
			# Target of the color animation. Set this as hexadecimal RGB color
			# code, i.e. 0xRRGGBB, with an optional alpha channel (i.e. 0xFF000000)
			# for a fully transparent black.

			# @!attribute [rw] delay_a
			# Smoothing delay for color transition. If {#delay_b} is zero and
			# delay_a is nonzero, setting {#target} will cause the actual
			# color to slowly transition to {#target}. Larger values cause
			# *faster* transitions!
			#
			# If delay_b is set, delay_a defines the smoothing speed between the
			# 'velocity' color and the actual color.

			# @!attribute [rw] delay_b
			# Smoothing delay for color transition. If both {#delay_a} and delay_b
			# are nonzero, setting {#target} will cause a smooth transition of the
			# output color.
			#
			# delay_b defines the transition speed of {#target} to an internal,
			# non-visible 'velocity' color.

			# Initialize a new color.
			# @param [Integer] value_num The hardware ID of this Color.
			#  must match the ID defined in the animation slaves.
			def initialize(value_num)
				@ID = value_num;

				@current = Hash.new(0);
				@changes = {}

				@is_animated = false;
			end

			def module_id=(new_id)
				@module_id = new_id

				PARAM_TYPES.each do |key|
					@changes[:key] = true if @current[key] != 0
				end
			end

			# @return [String] Total ID of this Color, in the form
			#   'SxxMxxVxx'
			def total_id()
				"#{@module_id}V#{@ID}"
			end

			# Internal function to set any of the Color's parameters.
			#
			# This can be called by the user, but it is preferrable to use
			# {#configure} or the matching parameter setter functions.
			def generic_set(key, value)
				raise ArgumentError, 'Key does not exist!' unless PARAM_TYPES.include? key
				raise ArgumentError, "Input must be numeric!" unless value.is_a? Numeric

				return if ![:jump, :velocity].include?(key) && value == @current[key]

				if [:delay_a, :delay_b].include? key
					@is_animated = true
				end

				@current[key] = value
				@changes[key] = true
			end

			PARAM_TYPES.each do |key|
				define_method(key.to_s) do
					@current[key]
				end

				define_method("#{key}=") do |input|
					generic_set key, input
				end
			end

			# Configure the color with a hash.
			#
			# This lets the user configure the color by passing a hash.
			# The data will be passed into the five attributes of this color
			# according to their key.
			# @example
			#  a_color.configure({ delay_a: 10, target: 0xFF0000 })
			def configure(data)
				if data.is_a? Numeric
					self.target = data
				elsif data.is_a? Hash
					data.each do |key, value|
						generic_set key, value
					end
				else
					raise ArgumentError, 'Config data must be Hash or Numeric'
				end
			end

			def has_changes?
				return !@changes.empty?
			end

			# Internal function to strip trailing zeroes for floats
			private def rcut(value)
				value.to_s.gsub(/(\.)0+$/, '')
			end

			# @private
			# Internal function to retrieve the list of changes for this color.
			# @note Do not call this as user unless you know what you are doing!
			#  This will delete the retrieved changes, which may cause loss of
			#  data if they are not properly sent to the animation slaves!
			def set_string()
				return nil unless has_changes?

				if !@is_animated
					return nil unless @changes[:target]

					out_str = "V#{@ID} J#{@current[:target].to_s(16)};"

					@changes = {}

					return out_str
				end

				out_str = ["V#{@ID}"];

				out_str << "J#{@current[:jump].to_s(16)}" if @changes[:jump]
				out_str << "V#{@current[:velocity].to_s(16)}" if @changes[:velocity]

				config_strs = [];
				config_strs_out = [];
				[:target, :delay_a, :delay_b].each do |k|
					if k == :target
						config_strs << @current[k].to_s(16)
					else
						config_strs << rcut(@current[k])
					end

					config_strs_out = config_strs.dup if @changes[k]
				end

				@changes = {}

				(out_str + config_strs_out).join(' ') + ';'
			end
		end
	end
end
