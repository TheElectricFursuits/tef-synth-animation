
require_relative 'BaseSequence.rb'
require_relative 'EventCollector.rb'

require_relative 'SheetSequence.rb'

module TEF
	module Sequencing
		# Sequene Player class.
		#
		# This class is meant as a easy means to play {BaseSequence}s.
		# It allows the user to start and stop sequences, play them in parallel,
		# or overwrite them.
		#
		# Register hooks to be called after an execution step with {#after_exec}.
		#
		# Start playing a sequence by using {#[]=}, then use {#delete} to stop
		# it prematurely.
		#
		# @todo Add pausing of sequences. Requires the BaseSequence to have a
		#   time conversion built-in as well.
		class Player

			# Initialize a player instance
			#
			# It can immediately be used to play {BaseSequence}s or {Sheet}s, though
			# {#after_exec} callbacks should first be registered.
			def initialize()
				@activeSequences = {}
				@sequenceMutex = Mutex.new

				@post_exec_cbs = []

				@collector = EventCollector.new()

				@retryCollecting = false

				@playThread = Thread.new do
					_run_play_thread()
				end

				@playThread.abort_on_exception = true
			end

			# Add a callback to be executed after a animation step.
			#
			# The block passed to this function will be executed after each
			# {EventCollector#execute!}, i.e. after every tick of the animation
			# system.
			# This makes it possible to connect it to the Animation system,
			# for example by calling {Animation::Handler#update_tick},
			# as well as the parameter stack by calling
			# {ParameterStack::Stack#process_changes}
			def after_exec(&block)
				@post_exec_cbs << block if block_given?
			end

			# Insert and start a new program.
			#
			# This will:
			# - Stop and tear the currently playing program under 'key' down.
			# - Instantiate a {SheetSequence} IF the program is a {Sheet}
			# - Immediately start playing the new program.
			#
			# The inserted program is returned.
			# {#delete} can be used to stop a given program.
			#
			# @param key Arbitrary key to identify the program with.
			# @param [BaseSequence, Sheet] program Program to start playing.
			def []=(key, program)
				@sequenceMutex.synchronize do
					if @activeSequences[key]
						@activeSequences[key].teardown
					end

					if program.is_a? Sheet
						program = SheetSequence.new(Time.now(), 1, sheet: program)
					end

					@activeSequences[key] = program
					@retryCollecting = true
				end

				@playThread.run();

				program
			end

			# Delete a given program by its key.
			# This will stop and tear the specified program down.
			def delete(key)
				@sequenceMutex.synchronize do
					if @activeSequences[key]
						@activeSequences[key].teardown
					end

					@activeSequences.delete key
					@retryCollecting = true
					@playThread.run();
				end
			end

			def [](key)
				@activeSequences[key]
			end

			private def _run_play_thread()
				loop do
					@sequenceMutex.synchronize do
						@retryCollecting = false
						@activeSequences.delete_if do |k, seq|
							if(seq.parent_end_time >= Time.now())
								seq.destroy!()
								true
							else
								false
							end
						end
						@activeSequences.each { |k, seq| seq.append_events @collector }
					end

					if @collector.has_events?
						@collector.wait_until_event
					else
						Thread.stop
					end

					if @retryCollecting
						@collector.restart
					else
						@collector.execute!
						@post_exec_cbs.each(&:call)
					end
				end
			end
		end
	end
end
