
require 'xasin_logger'

require_relative 'Animatable.rb'

# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	module Animation
		# Animation object handler.
		#
		# This class is the handler for one coherent animation system.
		# Its main purpose is to (de)register animatable objects, distributing
		# IDs and handing out packed update messages onto a FurComs bus.
		class Handler
			include XasLogger::Mix

			# Initialize a Handler.
			#
			# This will initialize a handler and connect it to the passed FurComs
			# bus.
			# The user may immediately start registering objects after creating
			# this class, though if the FurComs bus is not connected yet this may
			# cause very early messages to be lost!
			#
			# @param [FurComs::Base] furcoms_bus The FurComs Bus connecting
			#  instance. Must support send_message(topic, data), nothing else.
			#
			# @note {#update_tick} MUST be called after performing any
			#  changes, be it adding a new {Animatable} or changing values
			#  of a known animatable. It is recommended to call this function
			#  only after all changes for a given tick have been performed, so
			#  that they can be sent over as a batch.
			#  {Sequencing::Player#after_exec} can be used to register a callback
			#  to call {#update_tick}.
			def initialize(furcoms_bus)
				@furcoms = furcoms_bus

				@animation_mutex = Mutex.new
				@active_animations = {}

				@pending_deletions = {}
				@pending_creations = {}

				init_x_log('Animation Handler')
			end

			# Create a String key representation.
			#
			# This will take either a hash or a String,
			# convert it to a standard String key representation, and then
			# verify it for correctness.
			# @param [String, Hash] key the key to clean up.
			# @return [String] Cleaned string
			def clean_key(key)
				key = 'S%<S>dM%<M>d' % key if key.is_a? Hash

				unless key =~ /^S[\d]{1,3}M[\d]{1,3}$/
					raise ArgumentError, 'Target must be a valid Animation Value'
				end

				key
			end

			private def internal_set_object(key, new_obj)
				key = clean_key key

				@active_animations[key]&.module_id = nil;

				if new_obj.nil?
					@pending_deletions[key] = true
					@pending_creations.delete key

				elsif new_obj.is_a? Animatable
					new_obj.module_id = key

					@active_animations[key] = new_obj
					@pending_creations[key] = new_obj.creation_string
					@pending_deletions.delete key
				else
					raise ArgumentError, 'New animation object is of invalid type'
				end
			end

			# @return [Animatable] Returns the Animatable with matching key.
			def [](key)
				@active_animations[clean_key key]
			end

			# Register or replace a {Animatable}.
			#
			# This lets the user register a new {Animatable} object with given
			# key, or replace or delete a pre-existing animation object.
			#
			# @param [String, Hash] key The key to write into.
			# @param [Animatable, nil] Will delete any pre-existing animation, then
			#  either replace it with the given {Animatable}, or, if nil was
			#  given, will delete the animation entry.
			def []=(key, new_obj)
				@animation_mutex.synchronize do
					internal_set_object(key, new_obj)
				end
			end

			def append_to_set(new_obj, set_no = 200)
				@animation_mutex.synchronize do
					start_no = { S: set_no, M: 0 };

					until(@active_animations[clean_key start_no].nil? ||
							@active_animations[clean_key start_no].is_dead?) do
						start_no[:M] += 1
					end

					if(start_no[:M] >= 255)
						raise ArgumentError, 'No more space for new animations!'
					end

					internal_set_object(start_no, new_obj)
				end

				new_obj
			end

			# Internal function to join an Array of strings and send it onto
			# the FurComs bus on a given topic.
			# Useful to batch-send, which is a bit more efficient.
			private def join_and_send(topic, data)
				return if data.empty?

				out_str = '';
				data.each do |str|
					if(out_str.length + str.length > 200)
						@furcoms.send_message topic, out_str
						out_str = ''
					end

					out_str += str
				end

				@furcoms.send_message topic, out_str
			end

			# Internal function to send out death updates.
		 	# This will send out to topic DTIME, updating the Animatable's
			# death_time, as well as sending to DELETE for deleted animations.
			#
			# @todo Replace this with a time-synched system
			# using the main synch time, rather than using relative time.
			private def update_deaths
				death_reconfigs = [];
				deletions = []

				@animation_mutex.synchronize do
					@active_animations.each do |key, animation|
						if animation.is_dead?
							@pending_deletions[key] = :silent
						end

						new_death = animation.death_time_string
						next if new_death.nil?

						death_reconfigs << new_death
					end

					@pending_deletions.each do |key, val|
						deletions << "#{key};" unless val == :silent
						@active_animations.delete key
					end
					@pending_deletions = {}

				end

				join_and_send('DTIME', death_reconfigs)
				join_and_send('DELETE', deletions)
			end

			# Private function to send out creation strings.
			# Will simply send a string per new object, as we do not often
			# need to initialize objects.
			private def update_creations
				@pending_creations.each do |key, val|
					@furcoms.send_message('NEW', val)
				end

				@pending_creations = {}
			end

			# Internal function to optimize sending values.
			#
			# Updating values can be optimized in certain ways. The initial
			# value specifier can be left out if the next value to update
			# has an ID one after the former message.
			#
			# This can significantly reduce message length, for example after
			# creating a new object and initializing it. Being able to leave out the
			# Value ID saves about 10 bytes per value!
			private def optimize_and_send(messages)
				last_change = {}
				out_str = '';
				can_optimize = false

				messages.each do |change|
					opt_string = change[:str]

					can_optimize = false if last_change[:module] != change[:module]
					can_optimize = false if last_change[:value]  != (change[:value] - 1)
					can_optimize = false if (out_str.length + opt_string.length) > 200
					can_optimize = false if opt_string[0] == 'S'

					opt_string = "#{change[:module]}V#{change[:value].to_s(16)} #{opt_string}" unless can_optimize

					if opt_string.length + out_str.length > 200
						@furcoms.send_message 'SET', out_str
						out_str = ''
					end

					out_str += opt_string


					can_optimize = true
					last_change = change
				end

				@furcoms.send_message 'SET', out_str
			end

			# Internal function, will merely collect
			# the change strings from all known animations.
			private def update_values()
				pending_changes = []

				@animation_mutex.synchronize {
					@active_animations.each do |_, anim|
						pending_changes += anim.get_set_strings
					end
				}

				return if pending_changes.empty?
				x_logd "Pending changes are #{pending_changes}"

				optimize_and_send pending_changes
			end

			# Internal function, will collect all color change strings from
			# active animations and send it over FurComs
			private def update_colors
				pending_changes = []

				@animation_mutex.synchronize do
					@active_animations.each do |key, anim|
						pending_changes += anim.get_setc_strings
					end
				end

				return if pending_changes.empty?
				x_logd "Pending changes are #{pending_changes}"

				join_and_send 'CSET', pending_changes
			end

			private def update_strings
				@animation_mutex.synchronize do
					@active_animations.values.each do |anim|
						anim.get_setss_strings().each do |str|
							puts "Sending string #{str}!"

							@furcoms.send_message 'SSET', str
						end
					end
				end
			end

			# Update tick.
			#
			# Calling this function will send all updates and changes over the
			# FurComs bus. It is ensured that they occour in the following order:
			#
			# - All modules that have actively been deleted in Ruby will be
			#   deleted.
			# - Newly created and registered {Animatable}s will be created
			#   on the animation slaves.
			# - All {Value} changes of all {Animatable}s will be sent.
			# - All {Color} changes will be sent.
			def update_tick()
				update_creations

				update_deaths

				update_values
				update_colors
				update_strings
			end
		end
	end
end
