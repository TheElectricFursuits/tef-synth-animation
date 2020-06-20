
require_relative 'Value.rb'
require_relative 'Color.rb'
require_relative 'Coordinate.rb'

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
		# Animatable base class.
		#
		# This class implements all necessary functions to write a custom
		# animatable object with ease. It provides a DSL to easily
		# register new animatable colours, values and coordinates, and handles
		# updating and configuring them.
		#
		# By inheriting from this base class, the user must only define
		# the animatable properties of their object by using:
		# - {Animatable#animatable_attr}
		# - {Animatable#animatable_color}
		# - {Animatable#animatable_coordinate}
		#
		# The object must also be passed to the Animation handler, by calling:
		# handler['S123M123'] = your_instance;
		class Animatable
			# @return [String, nil] Module ID of this object as in SxxMxx, or nil.
			attr_reader :module_id

			# @return [Time, nil] If set, returns the time this object will
			#  auto-delete. This will not delete the Ruby object, but it will
			#  send a delete request to the animation slaves.
			attr_reader :death_time

			# @return [Numeric, nil] If set, returns the time (in s) that this
			#  object will live for. If the object is currently a live animation,
			#  setting this will make the object die in the given number of
			#  seconds. If it is not currently animated, it will make the object
			#  die after the given number of seconds, starting from when it
			#  was registered with the handler.
			attr_reader :death_delay

			# @private
			# @return [Array<{Symbol, Integer>] List of registered animatable attributes
			def self.get_attr_list
				@class_attribute_list ||= {}
			end
			# @private
			# @return [Array<Symbol, Integer>] List of registered animatable colours
			def self.get_color_list
				@class_color_list ||= {}
			end
			# @private
			# @return [Array<Symbol, Integer>] List of registered animatable coordinates
			def self.get_coordinate_list
				@class_coordinate_list ||= {}
			end

			# Defines a new animatable attribute.
			#
			# The defined attribute will become accessible via a getter and
			# convenience setter function, giving the user access to the
			# created {Value} instance.
			#
			# @param name [Symbol] Name of the attribute, as symbol. Will
			#  create getter and setter functions.
			# @param id [Numeric] Address of the animatable attribute. Must match
			#  the address defined in the animation C++ code!
			#
			# @!macro [attach] anim.attribute
			#   @!attribute [rw] $1
			#     @return [Value] Animated value '$1' (ID $2)
			def self.animatable_attr(name, id)
				get_attr_list()[name] = id

				define_method(name.to_s) do
					@animatable_attributes[name]
				end

				define_method("#{name}=") do |arg|
					if arg.is_a? Numeric
						@animatable_attributes[name].add = arg
					else
						@animatable_attributes[name].from = arg
					end
				end
			end

			# Defines a new animatable color
			#
			# The defined color will become accessible via a getter and
			# convenience setter function, giving the user access to the
			# created {Color} instance.
			#
			# @param name [Symbol] Name of the color, as symbol. Will
			#  create getter and setter functions.
			# @param id [Numeric] Address of the animatable color. Must match
			#  the address defined in the animation C++ code!
			# @!macro [attach] anim.color
			#   @!attribute [rw] $1
			#     @return [Color] Animated color '$1' (ID $2)
			def self.animatable_color(name, id)
				get_color_list()[name] = id

				define_method(name.to_s) do
					@animatable_colors[name]
				end

				define_method("#{name}=") do |arg|
					@animatable_colors[name].target = arg
				end
			end

			# Defines a new animatable coordinate.
			#
			# The defined coordinate will become accessible via a getter and
			# convenience setter function, giving the user access to the
			# created {Value} instance.
			#
			# @param name [Symbol] Name of the coordinate, as symbol. Will
			#  create getter and setter functions.
			# @param id [Numeric] Starting address of the coordinates. Expects
			#  the coordinate parameters to be sequential!
			#
			# @!macro [attach] anim.attribute
			#   @!attribute [rw] $1
			#     @return [Coordinate] Coordinate for '$1' (ID $2)
			def self.animatable_coordinate(name, start)
				get_coordinate_list()[name] = start

				define_method(name.to_s) do
					@animatable_coordinates[name]
				end
			end

			# Initialize a generic animatable object.
			#
			# This will initialize the necessary internal hashes
			# that contain the animatable attributes, colors and coordinates.
			def initialize()
				@animatable_attributes = {}
				@animatable_colors = {}
				@animatable_coordinates = {}

				@animatable_pending_strings = [];

				self.class.get_attr_list.each do |key, val|
					@animatable_attributes[key] = Value.new(val)
				end

				self.class.get_color_list.each do |key, val|
					@animatable_colors[key] = Color.new(val)
				end

				self.class.get_coordinate_list.each do |key, offset|
					@animatable_coordinates[key] = Coordinate.new(offset)
				end
			end

			def death_time=(n_time)
				raise ArgumentError, 'Must be a Time!' unless n_time.is_a? Time || n_time.nil?

				return if n_time == @death_time

				@death_time = n_time
				@death_time_changed = true
			end

			# Make this object die in a given number of seconds.
			# After the timer set here expires, the object will automatically
			# be deleted. As the slaves will do it automatically, it is good
			# practice to give any temporary object a death time, if possible, to
			# have them automatically cleaned up.
			#
			# It is possible to remove a death time or extend it, by calling
			# this function another time.
			#
			# @note This will not delete the Ruby object, but it will be
			#  unregistered from the {Animation::Handler}. It can safely
			#  be re-registered to re-create a new object.
			#
			# @param t [Numeric, nil] The time, in seconds until this object will
			#  be killed.
			def die_in(t)
				if t.nil?
					self.death_time = nil
					@death_delay = nil

					return
				end

				raise ArgumentError, "Time must be num!" unless t.is_a? Numeric

				self.death_time = Time.now() + t
				@death_delay = t
			end

			# Instantly deletes this object from the animation slaves.
			# @see #die_in
			def die!
				self.death_time = Time.at(0)
			end

			# Quickly configure this object.
			#
			# This is a convenience function to very quickly and easily
			# (re)configure this animatable object. It will take a hash
			# or named options, and will pass the values of the hash to
			# the matching {Value}, {Color} or {Coordinate}
			#
			# @see Value#configure
			# @see Color#configure
			# @see Coordinate#configure
			#
			# @example
			#   my_box.configure up: 10, down: 5, left: { dampen: 0.4, add: 2 }
			def configure(h = nil, **opts)
				h ||= opts;

				raise ArgumentError, 'Config must be a hash!' unless h.is_a? Hash

				h.each do |key, data|
					value = 	@animatable_attributes[key] ||
								@animatable_colors[key] ||
								@animatable_coordinates[key]

					raise ArgumentError, "Parameter #{key} does not exist!" unless value

					value.configure(data);
				end
			end

			# Return a default creation string.
			#
			# This function MUST be overwritten by the user to provide a proper
			# creation string! It will be sent over FurComs via the 'NEW' topic
			# and must contain all necessary information for the slaves to
			# construct the matching object.
			def creation_string
				''
			end

			def send_string(str)
				@animatable_pending_strings << str;
			end

			private def all_animatable_attributes
				out =  @animatable_attributes.values
				out += @animatable_coordinates.values.map(&:animatable_attributes)

				out.flatten
			end

			# @private
			# Set the module ID of this object manually.
			#
			# @note Do not call this function, it is purely internal.
			#  Only the {Handler} may set the module ID, otherwise undefined
			#  behavior may occour!
			def module_id=(new_str)
				unless new_str =~ /^S[\d]{1,3}M[\d]{1,3}$/ || new_str.nil?
					raise ArgumentError, 'Target must be a valid Animation Value'
				end

				all_animatable_attributes.each do |value|
					value.module_id = new_str
				end

				die_in @death_delay if @death_delay

				@module_id = new_str
			end

			# @private
			#
			# Returns a String to be sent via FurComs to configure the object
			# to die in a certain number of seconds.
			def death_time_string
				return nil unless @death_time_changed

				@death_time_changed = false

				return "#{@module_id} N;" if @death_time.nil?

				remaining_time = (@death_time - Time.now()).round(2)

				"#{@module_id} #{remaining_time};"
			end

			# @private
			#
			# Returns an array of 'SET' Hashes, to be sent over the FurComs
			# bus, 'SET' topic. They represent raw value configurations of the
			# animatable values.
			#
			# The {Handler} that called this function has the duty of packing
			# them into complete commands, as the initial module ID can be
			# left out for sequential value access, saving a few bytes
			# each transfer.
			#
			# @note Never call this unless you are the {Handler}! It will
			#  mark the changes as already transmitted, so manually calling
			#  this will cause data loss!
			#
			# @return [Array<Hash>] An array containing Hashes outlining each
			#  value's SET string.
			def get_set_strings()
				return [] unless @module_id

				out_elements = []

				all_animatable_attributes.each do |val|
					o_str = val.set_string
					next if o_str.nil?

					out_elements << { module: @module_id, value: val.ID, str: o_str };
				end

				out_elements
			end

			# @private
			#
			# @see #get_set_strings
			def get_setc_strings()
				return [] unless @module_id

				out_elements = []

				@animatable_colors.values.each do |val|
					o_str = val.set_string
					next if o_str.nil?

					out_elements << "#{@module_id}#{o_str}"
				end

				out_elements
			end

			def get_setss_strings()
				return [] unless @module_id

				out =  @animatable_pending_strings.map do |str|
					"#{@module_id} #{str}"
				end

				@animatable_pending_strings.clear

				return out;
			end
		end

		class Box < Animatable
			animatable_color :color, 0

			animatable_attr :rotation, 0
			animatable_attr :up, 1
			animatable_attr :down, 2
			animatable_attr :left, 3
			animatable_attr :right, 4

			animatable_coordinate :x_dir, 0xC000
			animatable_coordinate :y_dir, 0xC100
			animatable_coordinate :center, 0xC200

			def initialize(layer_no = 0)
				super();

				@layer = layer_no;
			end

			def creation_string
				"BOX #{@module_id} #{@layer}"
			end
		end
	end
end
