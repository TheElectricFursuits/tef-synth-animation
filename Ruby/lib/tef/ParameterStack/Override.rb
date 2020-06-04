
require_relative 'Stack.rb'

# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	module ParameterStack
		# Override class.
		#
		# This class represents one 'access point' for the software,
		# with which it can override certain values of the {Stack}
		# it belongs to.
		#
		# Using it is as simple as using a Hash:
		# @example
		#  override = Override.new(central_stack, 10);
		#  override['SomeParam'] = 5
		#  override['SomeParam'] = nil # Relinquish control over the value.
		class Override
			include Comparable

			# @return [Numeric] Level of this Override.
			#   Higher levels mean higher priority. The highest-level
			#   override that is active for any given key will determine
			#   that key's value!
			attr_reader :level

			# Initialize an Override.
			#
			# Values can be written into the Override immediately after
			# creation. When the Override is no longer used,
			# make sure to call {#destroy!}
			#
			# @param [Stack] stack The stack to write to.
			# @param [Numeric] init_level Level of this Override.
			#  Can not be changed, is always the same for all keys!
			def initialize(stack, init_level = 0)
				raise ArgumentError, 'Handler must be CoreStack!' unless stack.is_a? Stack

				@stack = stack

				@level = init_level;
				@overrides = {}

				@valid_until = nil;

				@stack.add_override self
			end

			# @return The value of this Override for a given key.
			# @note This will not be the global key. Use {Stack#[]} to retrieve
			#  the currently active key.
			def [](key)
				@overrides[key]
			end

			# Set the value for the given key.
			# Setting nil as value causes this Override to relinquish control
			# @param key Hash-Key
			# @param new_value User-defined value. If nil, relinquishes control.
			def []=(key, new_value)
				return if @overrides[key] == new_value

				if new_value.nil?
					delete(key)
					return
				end

				@overrides[key] = new_value
				@stack.override_claims self, key
			end

			# @return [true,false] Whether this Override includes a given key
			def include?(key)
				@overrides.include? key
			end

			# @return [Array] List of keys
			def keys
				@overrides.keys
			end

			# Delete a value for the given key.
			# Equivalent to calling {#[]=} nil
			def delete(key)
				return unless @overrides.include? key
				@overrides.delete key

				return unless @stack.active_overrides[key] == self

				@stack.recompute_single key
			end

			# Destroy this Override.
			#
			# This function MUST be called if the user no longer
			# needs this object. It relinquishes control over all the
			# values that this Override formerly held.
			#
			# Note that nothing else is modified, and
			# {Stack#add_override} could be used to re-add
			# this Override.
			def destroy!
				@stack.remove_override self
			end

			def <=>(other)
				return @level <=> other.level if other.level != @level
				return self.hash <=> other.hash
			end
		end
	end
end
