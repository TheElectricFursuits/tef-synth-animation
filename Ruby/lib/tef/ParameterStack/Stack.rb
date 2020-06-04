
require_relative 'Override.rb'

# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	# Module for the ParameterStack TEF code.
	#
	# The ParameterStack system is a module designed to let multiple different
	# subsystems of code interact and configure certain core parameters.
	# Each subystem is assigned its own {ParameterStack::Override}, and can
	# seamlessly take and relinquish control over parameters at any time.
	module ParameterStack
		# Parameter Stack class.
		#
		# This class contains all parameters that have been configured by
		# {Override}s. It provides a way to retrieve the currently valid
		# coniguration, as well as letting the user (de)regsiter new {Override}s.
		class Stack

			# @return [Hash] Hash whose keys specify which parameters have been
			#  changed since the last recompute cycle.
			attr_reader :changes

			# @return [Hash] Hash of the overrides that have control over
			#  a given parameter key.
			attr_reader :active_overrides

			def initialize()
				@current_values   = {}
				@active_overrides = {}

				@changes = {}

				@override_list_mutex = Mutex.new()
				@override_list = []

				@recompute_blocks    = []
				@value_change_blocks = []

				@default_override = Override.new(self, -1);
			end

			# @return Returns the currently configured parameter for the given key.
			def [](key)
				@current_values[key]
			end

			# Set the default parameter for a given key.
			#
			# Default parameters have a level of -1, meaning that any
			# {Override} with priority >= 0 (the default) will claim the value.
			def []=(key, value)
				@default_override[key] = value
			end

			def keys
				@current_values.keys
			end

			# Add a callback for immediate parameter changes.
			#
			# The given block will be called for any change of a parameter,
			# so should be used sparingly. Recursive parameter setting should also
			# be carefully avoided!
			#
			# @param [Array] keys Key whitelist to trigger on.
			# @yieldparam key Key that was changed.
			# @yieldparam value New value of the key
			def on_recompute(*keys, &block)
				@recompute_blocks << {
					block: block,
					keys: keys
				}
			end

			# Add a callback to be called during {#process_changes}.
			#
			# The given block will be called if a change in a key specified by
			# the filters occoured, and will be called during {#process_changes}.
			#
			# This lets the user only act on changes, and act on them in bunches,
			# rather than on every individual change.
			#
			# @param [String, Regexp] filters List of filters to use. Acts like
			#  a whitelist, can be a Regexp
			def on_change(*filters, &block)
				filters = nil if filters.empty?

				@value_change_blocks << {
					block: block,
					filters: filters
				}
			end

			private def mark_key_change(key)
				@changes[key] = true

				@recompute_blocks.each do |block_cfg|
					next unless block_cfg[:keys].include? key
					block_cfg[:block].call(key, @current_values[key])
				end
			end

			# Check if an {Override} can claim a key.
			#
			# This is mainly an internal function. It will check if the passed
			# {Override} has permission to claim the given key, and will
			# change the value accordingly.
			def override_claims(override, key)
				return if !(@active_overrides[key].nil?) && (@active_overrides[key] > override)

				@active_overrides[key] = override;
				value = override[key];

				return if @current_values[key] == value

				@current_values[key] = value
				mark_key_change key
			end

			# Re-Calculate which {Override} is currently claiming a given key.
			#
			# This method is mainly for internal work. It will iterate through
			# the list of {Overrides} to find the next in line that wants
			# to claim the given key.
			# May be slow!
			def recompute_single(key)
				old_value = @current_values[key]

				found_override = false;

				@override_list_mutex.synchronize do
					@override_list.each do |override|
						next unless override.include? key

						@active_overrides[key] = override;
						@current_values[key]   = override[key];

						found_override = true;

						break;
					end
				end

				if !found_override
					@current_values.delete key
					@active_overrides.delete key
				end

				mark_key_change key if old_value != @current_values[key]
			end

			# Recompute the owner of the list of keys.
			# Mainly an internal function, used by an {Override} that is
			# de-registering itself.
			def recompute(keys)
				keys.each do |key|
					recompute_single key
				end
			end

			private def keys_match_filters(keys, filters)
				return true if filters.nil?

				filters = [filters] unless filters.is_a? Array

				filters.each do |filter|
					keys.each do |key|
						return true if filter.is_a?(Regexp) && key =~ filter
						return true if filter.is_a?(String) && key == filter
					end
				end

				return false
			end

			# Trigger processing of all {#on_change} callbacks.
			#
			# Works best when triggered after all changes for a given
			# time-tick have been performed, such as during a
			# {Sequencing::Player#after_exec} callback.
			def process_changes()
				change_list = @changes.keys

				@value_change_blocks.each do |block_cfg|
					next unless keys_match_filters change_list, block_cfg[:filters]

					block_cfg[:block].call()
				end

				@changes = {}
			end

			def add_override(override)
				@override_list_mutex.synchronize do
					@override_list << override unless @override_list.include? override
					@override_list.sort!
				end
			end

			def remove_override(override)
				return unless @override_list.include? override

				@override_list_mutex.synchronize do
					@override_list.delete override
				end

				recompute override.keys
			end
		end
	end
end
