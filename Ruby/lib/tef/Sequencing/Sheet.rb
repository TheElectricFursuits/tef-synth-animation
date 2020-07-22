
require_relative 'EventCollector.rb'

module TEF
	module Sequencing
		# Sheet class
		#
		# This class is meant as a container for the minimum
		# amount of information necessary to instantiate a {SheetSequence}.
		#
		# It provides a clean and easy way for the user to define
		# a sequence of events, as well as minimally necessary information
		# such as the speed of the sequence or the starting and ending
		# times.
		class Sheet
			# @return [Numeric] The local starting time. Defaults to
			#  0, i.e the sheet will start playing immediately.
			#  This does not affect the actual time scaling, but instead
			#  is merely used to know when to instantiate the {SheetSequence}
			attr_accessor :start_time

			# @return [Numeric] The local ending-time. Defaults to nil, i.e.
			#  it will be auto-determined by the notes in the sheet.
			#  Affects when the sheet is torn down and stops
			#  execution!
			attr_accessor :end_time

			# @return [Numeric, nil] Tempo of the sheet. Defines the execution
			#  speed in BPM. If left nil, the execution speed of the parent
			#  sheet is used.
			attr_accessor :tempo

			# @return [nil, Proc] Block to call when setting up the {SheetSequence}.
			#  This is the main way of letting the user configure the {SheetSequence},
			#  as this block is called from the context of the sheet itself.
			#  Look at the functions of the Sheet Sequence for more details.
			#
			# @see SheetSequence#at
			# @see SheetSequence#after
			# @see SheetSequence#play
			attr_reader :setup_block
			attr_reader :teardown_block

			# Initialize a new Sheet.
			#
			# The user should configure the sheet by writing into
			# {#start_time}, {#end_time} and by supplying at least a
			# {#sequence}
			def initialize()
				@start_time = 0;
				@end_time = nil;

				@tempo = nil

				@setup_block = nil;
				@teardown_block = nil;

				yield(self) if(block_given?)
			end

			# Configure a block to call when setting up the {SheetSequence}.
			# This is the main way of letting the user configure the {SheetSequence},
			# as this block is called from the context of the sheet itself.
			# Look at the functions of the Sheet Sequence for more details.
			#
			# @see SheetSequence#at
			# @see SheetSequence#after
			# @see SheetSequence#play
			def sequence(&block)
				@setup_block = block;
			end

			# Configure the block to call when the {SheetSequence} is about to
			# be torn down. Use this to stop or delete any resources allocated
			# to the sheet.
			#
			# Guaranteed to always be called.
			def teardown(&block)
				@teardown_block = block;
			end
		end
	end
end
