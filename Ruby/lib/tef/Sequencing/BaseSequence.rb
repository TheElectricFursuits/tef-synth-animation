
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
			# - :idle (after teardown() was called)
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
				@slope  = slope.round(6);
				# Explanation: For some bizarre reason, rounding is necessary
				# to avoid a glitch in the timing math. 6 digits of precision
				# should be precise enough anyways.

				@state = :uninitialized

				@opts_hash = options;
			end

			def parent_start_time
				@offset + @start_time / @slope
			end
			def parent_end_time
				return nil if @end_time.nil?

				@offset + @end_time / @slope
			end

			def parent_end_time=(new_time)
				if(new_time.nil?)
					@end_time = nil;
					return;
				end

				@end_time = (new_time - @offset) * @slope;
			end

			def setup()
				return unless @state == :idle
				@state = :running
			end

			def teardown()
				return unless @state == :running
				@state = :idle
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
				return if @state == :uninitialized

				local_collector = collector.offset_collector(@offset, @slope);

				# Return if the collector has events before our start time
				return if local_collector.has_events? &&
							 local_collector.event_time < @start_time

				if !@end_time.nil?
					if @state == :running
	 					local_collector.add_event({
	 						time: [@end_time, local_collector.start_time + 0.01].max,
	 						code: proc { self.teardown() }
	 					})
					end

					return if local_collector.start_time >= @end_time
 				end

				if @state == :idle
					local_collector.add_event({
						time: [@start_time, local_collector.start_time + 0.01].max,
						code: proc { self.setup() }
					});
				end

				overload_append_events(local_collector)
			end

			def overload_append_events(_collector) end

			def destroy!()
				teardown() if @state == :running
			end
		end
	end
end
