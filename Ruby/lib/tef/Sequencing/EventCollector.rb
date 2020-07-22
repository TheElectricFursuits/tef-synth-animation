
require 'xasin_logger'

# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	# Program Sequencing module.
	#
	# This module contains all components necessary to define how and when
	# a animation or program will execute. It provides a base class
	# to define how execution information is passed along between code, as well
	# as a more user friendly interface to define a fixed sequence of events,
	# a so called {Sheet}.
	#
	# {Sheet}s are designed to be as reuseable as possible,
	# with dynamic creation to let the same sheet be adapted to different
	# situations, as well as Sheet and Event nesting that makes it easy to
	# re-use other {Sheet}s, for example to define segments of a song or
	# generic beat-segments.
	module Sequencing
		# Purely internal class
		#
		# Used by {BaseSequence} when fetching the next event from child
		# sequences. It wraps {EventCollector} and automatically applies
		# a sequence's offset and slope, converting between the timeframe
		# of the parent and the child.
		#
		# This collector is created in the child, within {BaseSequence#append_events}
		class OffsetCollector
			# @return [EventCollector] Top-Level collector
			attr_reader :parent

			# @return [Time] Offset of the conversion. Used as follows:
			#   local_time = (Time.at(x) - total_offset) * total_slope
			attr_reader :total_offset
			# @return [Numeric] Slope of the time conversion.
			# @see #total_offset
			attr_reader :total_slope

			# Initialize a new offset collector.
			# This should only be done via {EventCollector#offset_collector}!
			def initialize(parent, total_offset, total_slope)
				@parent = parent

				@total_offset = total_offset
				@total_slope  = total_slope.to_f
			end

			# @param [Time, nil] global_time Time to convert
			# @return [Numeric, nil] Converted time
			def convert_to_local(global_time)
				return nil if global_time.nil?

				((global_time - @total_offset) * @total_slope).round(3)
			end

			# @param [Numeric, nil] local_time Time (abstract) to convert back
			#  into the global frame.
			# @return [Time, nil] Time (as Time object) of the event
			def convert_to_global(local_time)
				return nil if local_time.nil?

				@total_offset + (local_time.to_f.round(3) / @total_slope)
			end

			# (see EventCollector#start_time)
			def start_time
				convert_to_local @parent.start_time
			end

			# (see EventCollector#event_time)
			def event_time
				convert_to_local @parent.event_time
			end

			# (see EventCollector#has_events?)
			def has_events?
				return @parent.has_events?
			end

			# (see EventCollector#add_event)
			def add_event(event)
				event = event.clone

				event[:time] = convert_to_global event[:time]

				@parent.add_event event
			end

			# (see EventCollector#add_events)
			def add_events(list)
				list.each { |event| add_event event }
			end

			# (see EventCollector#offset_collector)
			def offset_collector(offset, slope)
				OffsetCollector.new(@parent, convert_to_global(offset), @total_slope * slope)
			end
		end

		# Event Collector class
		#
		# This class provides the means to efficiently fetch the next event
		# from a list of {BaseSequence}s, and is mainly meant for
		# internal purposes. It is created by {Player}
		class EventCollector
			include XasLogger::Mix

			# @return [Time] The Time to start looking for an event.
			#  Any event earlier than this will be discarded!
			attr_accessor :start_time

			# @return [nil, Time] The Time of the current event, or nil if
			#  there is no event. Any event later than this will be
			#  discarded. Any event equal to this time will be appended to
			#  {#current_events}
			attr_reader   :event_time

			# @return [Array<Hash>] List of current events to execute.
			attr_reader :current_events

			def initialize()
				@current_events = []
				@start_time = Time.at(0);
				@event_time = nil;

				init_x_log("Sequence Player")
			end

			# Internal function to add an event.
			# The event will be discarded if it is earlier than or equal to
			# start time, or later than the event time.
			# It if it is earlier than event time it will set the new event time
			# and set the event list to [event], else append the event
			# to the event list.
			def add_event(event)
				event = event.clone

				return if event[:time] <= @start_time
				return if (!@event_time.nil?) && (event[:time] > @event_time)
				return unless event[:code].is_a? Proc

				if (!@event_time.nil?) && (event[:time] == @event_time)
					@current_events << event
				else
					@current_events = [event]
					@event_time = event[:time]
				end
			end

			# @return [true, false] Were any events found?
			def has_events?
				!@current_events.empty?
			end

			# This function will try to wait until {#event_time}.
			# If no event was found it will return immediately, and Thread.run()
			# can be used to prematurely end the wait.
			def wait_until_event
				return unless has_events?

				t_diff = @event_time - Time.now();

				if t_diff < -0.5
					x_logf('Sequence long overdue!')
				elsif t_diff < -0.1
					x_logw('Sequencing overdue')
				end

				sleep t_diff if t_diff > 0
			end

			# Wait until the next event and then execute
			# the code of each event.
			def execute!
				return unless has_events?

				wait_until_event

				@current_events.each do |event|
					event[:code].call()
				end

				@start_time = @event_time
				restart();
			end

			# Restart this collector.
			# Will clear {#current_events} and {#event_time}
			def restart()
				@current_events = []
				@event_time = nil;
			end

			# Generate a {OffsetCollector}
			# This is mainly an internal function used by {BaseSequence} to
			# provide an {OffsetCollector}. It converts between the global time-frame
			# used by this collector, and the local timeframes of each
			# sub-sequence.
			def offset_collector(offset, slope)
				OffsetCollector.new(self, offset, slope);
			end
		end
	end
end
