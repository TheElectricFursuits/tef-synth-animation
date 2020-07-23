
require_relative 'BaseSequence.rb'
require_relative 'Sheet.rb'

module TEF
	module Sequencing
		# Sheet Sequence class.
		#
		# This is the main way for the user to specify an exact sequence of events
		# to execute. It is construced with the help of a {Sheet}, which
		# acts as specification for this Sheet Sequence.
		#
		# Think of the {Sheet} as being the script for a play or movie, while
		# the {SheetSequence} has the job of actually performing everything.
		class SheetSequence < BaseSequence
			# Initialize a SheetSequence.
			#
			# This is mostly done via {Player#[]=} by passing a {Sheet}.
			# However, a sequence can also be manually instantiated.
			#
			# After initialization, the sheet's {Sheet#setup_block} is called
			# to fill this SheetSequence with actual content.
			# The user may also call {#at} and {#after} manually to add additional
			# events.
			def initialize(offset, slope, **options)
				raise ArgumentError, 'Sheet must be supplied!' unless options[:sheet]

				@sheet = options[:sheet]

				if @sheet.tempo
					slope *= (@sheet.tempo / (60.to_f * (options[:top_slope] || 1)))
				end

				super(offset, slope, **options);

				@notes = []
				@latest_note_time = nil;

				@subprograms = []
				@active_music = []

				@start_time = @sheet.start_time
				@end_time = @sheet.end_time

				if block = @sheet.fill_block
					instance_exec(@opts_hash, &block)

					@start_time ||= @notes[0]&.dig(:time) || 0;
					@end_time	||= @notes[-1]&.dig(:time) || 0;

					@state = :idle;
				end
			end

			def setup()
				return unless @state == :idle

				super();

				if block = @sheet.setup_block
					instance_exec(@opts_hash, &block)
				end
			end

			def teardown()
				return unless @state == :running

				if block = @sheet.teardown_block
					instance_eval(&block)
				end

				@subprograms.each(&:teardown)

				@active_music.each do |pid|
					self.kill pid
				end

				super();
			end

			# Insert an event or subsheet into the event list.
			#
			# This is the main way of adding events to this sequence.
			# Each call to the function will insert a new event at the specified
			# time, which will call the passed block.
			# If, instead, a parameter called :sheet or :sequence is passed,
			# instead the the passed sequence will be instantiated and
			# added to the list of programs.
			# Any further options are directly passed to the constructor
			# of the class specified by the :sequence parameter
			#
			# If a block was passed, it will be instance_exec'd at the specified
			# time.
			#
			# Note that any used or created resources shall be destroyed in
			# the {Sheet#teardown} block. Sub-Sequences as well as notes
			# played by {#play} are automatically torn down.
			def at(time, **options, &block)
				time = time.to_f

				if repeat_time = @sheet.repeat_time
					time = time % repeat_time
				end

				time = time.round(3);

				@latest_note_time = time;

				options[:sequence] = SheetSequence if options[:sheet]

				if prog = options[:sequence]
					options[:slope] ||= 1
					options[:top_slope] = @slope

					prog = prog.new(time, options[:slope], **options)

					if e_time = options[:end_time]
						prog.parent_end_time = e_time;
					end

					i = @subprograms.bsearch_index { |s| s.parent_start_time > prog.parent_start_time }
					@subprograms.insert((i || -1), prog);

					return
				end

				new_event = {
					time: time,
					code: block,
					instance: self,
				}

				i = @notes.bsearch_index { |e| e[:time] > time }
				@notes.insert((i || -1), new_event);
			end

			# Similar to {#at}, but specifies time relative to the
			# last event time.
			# @see #at
			def after(time, **options, &block)
				at(time + (@latest_note_time || 0) , **options, &block);
			end

			# Play a music file, using `play`
			#
			# The PID of the music playing task is saved, and the process
			# will be killed when this sheet is torn down. The user does not
			# have to do anything else, but may choose to prematurely kill
			# the playback by using {#kill}
			#
			# @param [String] music_piece Path of the file to play.
			# @return [Numeric] The PID of the spawned process.
			def play(music_piece, volume = 0.3)
				play_pid = spawn(*%W{play -q --volume #{volume} #{music_piece}});

				Thread.new do
					@active_music << play_pid
					Process.wait(play_pid)
					@active_music.delete play_pid
				end

				play_pid
			end

			# Shorthand to kill
			def kill(pid)
				Process.kill('QUIT', pid);
			rescue Errno::ESRCH
				return false
			end

			private def overload_append_events(collector)
				i = 0

				if(@sheet.repeat_time)
					repeat_cycle = (collector.start_time / @sheet.repeat_time).floor
					repeat_shift_time = repeat_cycle * @sheet.repeat_time

					# This will wrap around and thusly implement the repeating nature
					# of this sequence
					collector = collector.offset_collector(repeat_shift_time, 1);
				end

				@subprograms.each do |program|
					if(collector.event_time &&
						(collector.event_time < program.parent_start_time))
						next
					end

					program.append_events collector
				end

				return if @notes.empty?

				if(@sheet.repeat_time)
					if(collector.start_time >= @notes[-1][:time])
						collector = collector.offset_collector(@sheet.repeat_time, 1);
					end
				end

				i = @notes.bsearch_index { |e| e[:time] > collector.start_time }
				return unless i

				note_time = @notes[i][:time]

				until (note = @notes[i])&.dig(:time) != note_time
					i += 1;
					collector.add_event note
				end
			end
		end
	end
end
