
require_relative 'EventCollector.rb'

# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	module Sequencing
		# Base sequence class.
		#
		# It implements the minium necessary tools to make different Sequences
		# work together nicely. It's main function is to provide {#append_events},
		# which is used by a {Player} to fetch the next queued event for execution.
		class BaseSequence
			# @return [Numeric] Start time of this sequence, in local time.
			#  Specifies when to call {#setup}
			attr_reader :start_time
			# @return [Numeric, nil] End time of this sequence, in local time.
			#  Specifies when to call {#teardown}. Can be left as nil for no
			#  automatic teardown.
			attr_reader :end_time

			# @return [Numeric, Time] The offset to apply to this Sequence,
			#  used when converting between local-time and parent-time.
			#
			#  This MAY be modified during runtime, though this may cause some
			#  events to be skipped!
			attr_reader :offset
			# @return [Numeric] Slope to apply to this sequence.
			# @see #offset
			attr_reader :slope

			# @return [Symbol] State of this Sequence. Mainly used for internal
			# purposes. Can be:
			# - :uninitialized (right after construction)
			# - :running (after having called setup())
			# - :torn_down (after teardown() was called)
			attr_reader :state

			# Initialize a BaseSequence.
			#
			# @param [Numeric, Time] offset Provide a offset for time-conversion.
			#  @see #offset
			# @param [Numeric] slope Provide a slope for time-conversion.
			#  @see #slope
			#
			# @param [Numeric] :start_time Local time to begin playing at.
			# @param [Numeric] :end_time   Local time to tear down at.
			def initialize(offset, slope, **options)
				@start_time ||= options[:start_time] || 0;
				@end_time   ||= options[:end_time];

				@offset = offset;
				@slope  = slope;

				@state = :uninitialized

				@opts_hash = options;
			end

			def parent_start_time
				@offset + @start_time / @slope
			end

			def setup()
				raise 'Program had to be uninitialized!' unless @state == :uninitialized
				@state = :running
			end

			def teardown()
				return unless @state == :running
				@state = :torn_down

				@opts_hash = nil;
			end

			# Look for the next possible event that this sequence wants to
			# execute.
			# Will ensure that this sequence's {#setup} and {#teardown} blocks
			# are called at the appropriate time.
			#
			# Should only be called by a {Player} or another sequence!
			#
			# @note When using BaseSequence as base class, the user
			#  shall overload {#overload_append_events} rather than this function!
			def append_events(collector)
				local_collector = collector.offset_collector(@offset, @slope);

				return if local_collector.has_events? &&
							 local_collector.event_time < @start_time
				return if @state == :torn_down

				if @state == :uninitialized
					local_collector.add_event({
						time: [@start_time, local_collector.start_time + 0.01].max,
						code: proc { self.setup() }
					});
				end

				if @state == :running
					overload_append_events(local_collector)
				end

				if !@end_time.nil?
					local_collector.add_event({
						time: @end_time,
						code: proc { self.teardown() }
					})
				end
			end

			def overload_append_events(_collector) end
		end
	end
end
