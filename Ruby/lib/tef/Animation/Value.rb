
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
		class Value
			PARAM_TYPES = 	[:add, :multiply, :dampen, :delay, :from, :jump, :velocity];

			# @return [Integer] Hardware-Number of this Value
			attr_reader :ID

			# @return [String, nil] Module-ID of the {Animatable} that this
			#  Value belongs to.
			attr_reader :module_id

			# @!attribute [rw] add
			# @return [Numeric] The add-offset to apply to this Value.
			#  Can be used either to set the absolute target (with {#from} being
			# nil), or to specify an offset of the number grabbed from {#from}.

			# @!attribute [rw] multiply
			# @return [Numeric] Multiplication factor. Will be applied to
			#  ({#from} + {#add}) * {#multiply}. 0 means no multiplication.

			# @!attribute [rw] dampen
			# @return [Numeric] dampening factor. Causes the actual output value
			#  to smoothly transition to the target value ((from + add) * multiply).
			#  Larger values take longer (higher dampening)

			# @!attribute [rw] delay
			# @return [Numeric] delay factor. If it and {#dampen} are nonzero,
			#  will cause the actual output to oscillate slightly. Also
			#  causes {#velocity} to have an effect. Higher delays cause
			#  slower transitions, and may need more {#dampen}ing to mitigate
			#  overshoot.

			# @!attribute [rw] from
			# @return [String,nil] If not set to nil, defines the other {Value}
			#  that this Value will take the output from. Allows the user
			#  to follow some other parameter and create interesting linkages.

			# @!attribute [w] jump
			# @return [Numeric] Instantly jump to the given number, skipping
			#  animation and smoothing. Will not reconfigure the actual target,
			#  and can thusly be used to temporarily "bump" the value.

			# @!attribute [w] velocity
			# @return [Numeric] Set the velocity of the value. Only has an
			#  effect if {#dampen} and {#delay} are nonzero.

			# Initialize a new Value.
			# @param [Integer] value_num The hardware ID of this Value.
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

			# @return [String] Total ID of this Value, in the form
			#   'SxxMxxVxx'
			def total_id()
				"#{@module_id}V#{@ID.to_s(16)}"
			end

			# Internal function to set any of the Value's parameters.
			#
			# This can be called by the user, but it is preferrable to use
			# {#configure} or the matching parameter setter functions.
			def generic_set(key, value)
				if key == :from
					self.from = value
					return
				end

				raise ArgumentError, 'Key does not exist!' unless PARAM_TYPES.include? key
				raise ArgumentError, "Input must be numeric!" unless value.is_a? Numeric

				return if (value == @current[key] && ![:jump, :velocity].include?(key))

				if [:multiply, :dampen, :delay].include? key
					@is_animated = true
				end

				@current[key] = value
				@changes[key] = true
			end

			[:jump, :velocity, :add, :multiply, :dampen, :delay].each do |key|
				define_method(key.to_s) do
					@current[key]
				end

				define_method("#{key}=") do |input|
					generic_set key, input
				end
			end

			# Configure the Value with a Hash.
			#
			# This lets the user configure the Value by passing a Hash.
			# The data will be passed into the six attributes of this Value
			# according to their key.
			# @example
			#  a_color.configure({ add: 2, dampen: 10 })
			def configure(data)
				if data.is_a? Numeric
					self.add = data
				elsif data.is_a? Hash
					data.each do |key, value|
						generic_set key, value
					end
				else
					self.from = data;
				end
			end

			def from() return @current[:from] end

			def from=(target)
				if target.is_a? Value
					target = target.total_id
				end

				if target.nil?
					target = 'S0M0V0'
				end

				unless target =~ /^S[\d]{1,3}M[\da-f]{1,3}V\d+$/
					raise ArgumentError, 'Target must be a valid Animation Value'
				end

				return if target == @current[:from]

				@current[:from] = target
				@changes[:from] = true
				@is_animated = true
			end

			def has_changes?
				return !@changes.empty?
			end

			# Internal function to strip trailing zeroes for floats
			private def rcut(value)
				value.to_s.gsub(/(\.)0+$/, '')
			end

			# @private
			# Internal function to retrieve the list of changes for this Value.
			# @note Do not call this as user unless you know what you are doing!
			#  This will delete the retrieved changes, which may cause loss of
			#  data if they are not properly sent to the animation slaves!
			def set_string()
				return nil unless has_changes?

				if !@is_animated
					return nil unless @changes[:add]

					out_str = "J#{rcut(@current[:add])};"

					@changes = {}

					return out_str
				end

				out_str = [];

				out_str << "J#{rcut(@current[:jump])}" if @changes[:jump]
				out_str << "V#{rcut(@current[:velocity])}" if @changes[:velocity]

				out_str << @current[:from] if @changes[:from]

				config_strs = [];
				config_strs_out = [];
				[:add, :multiply, :dampen, :delay].each do |k|
					config_strs << rcut(@current[k])

					config_strs_out = config_strs.dup if @changes[k]
				end

				@changes = {}

				(out_str + config_strs_out).join(' ') + ';'
			end
		end
	end
end
