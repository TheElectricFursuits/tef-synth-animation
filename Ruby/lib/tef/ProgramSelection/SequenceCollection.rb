
require_relative '../Sequencing/SheetSequence.rb'
require_relative 'ProgramID.rb'

module TEF
	module ProgramSelection
		# Sheet Sequence collection
		#
		# This class is meant as a convenient container for
		# {Sequencing::Sheet}s. It automatically registers
		# used {ID}s with the used {Selector}, and is also
		# responsible for easily registering {ProgramSheet}s.
		class SequenceCollection
			# @return [Hash<ID, Hash>] Options to pass to
			#  specific sheets when instantiating them.
			#  Useful when re-using a {Sequencing::Sheet} for
			#  different programs.
			attr_reader :sheet_opts

			# @return [SequenceCollection] Last Collection that
			#  was instantiated. Used by {ProgramSelection} to
			#  register itself.
			def self.current_collection
				@current_collection
			end
			def self.current_collection=(n_collection)
				@current_collection = n_collection
			end

			# Initialize a collection.
			#
			# The passed {Selector} is used to register Sheet {ID}s, while
			# the passed {Sequencing::Player} is used to start
			# playing Sheets when using {#play}
			#
			# Will set {SequenceCollection#current_collection} to self
			#
			# @example
			#   sheet_collection = SequenceCollection.new(programs, player);
			#
			#   ProgramSheet.new() do |s|
			#      s.add_key 'hello', ['portal', 'turret']
			#
			#      # Write sheet contents here.
			#      # The ProgramSheet will self-register to the
			#      # created sheet collection.
			#   end
			#
			#   sheet_collection.play(programs.fetch_string('hello'));
			def initialize(program_selector, sequence_runner)
				@program_selector = program_selector
				@sequence_runner = sequence_runner

				@known_programs = {}
				@sheet_opts = {}

				self.class.current_collection = self
			end

			# @return [nil, Sequencing::Sheet, ProgramSheet] Sheet matching
			#   the given {ID}, or nil.
			def [](key)
				@known_programs[key]
			end

			# Register a given program.
			#
			# @param [ID] key {ID} to register the program under.
			#   Will be registered with the {Selector} passed to the
			#   constructor.
			# @param [Sequencing::Sheet, ProgramSheet] n_program New program
			#   to register.
			def []=(key, n_program)
				key = @program_selector.register_ID key
				@known_programs[key] = n_program
			end

			# Start playing the {Sequencing::Sheet} matching the given {ID}
			#
			# This function will instantiate a new {Sequencing::SheetSequence} if
			# the registered program was a {ProgramSheet}. It will pass the
			# {#sheet_opts} matching its ID to the SheetSequence, and will
			# additionally set the option's :program_key value to the {ID} used
			# here.
			# This allows easy re-using of sheets by passing parameters via
			# the sheet options.
			#
			# The created sheet is then passed to {Sequencing::Player#[]=}, using
			# either {ProgramSheet#program_key} or 'default' as key.
			def play(key)
				prog = @known_programs[key]
				return unless prog

				prog_key = prog.program_key if prog.is_a? ProgramSheet

				if prog.is_a? Sequencing::Sheet
					opts = @sheet_opts[key] || {}
					opts[:sheet] = prog
					opts[:program_key] = key

					prog = Sequencing::SheetSequence.new(Time.now(), 1, **opts)
				end
				prog_key ||= 'default'

				@sequence_runner[prog_key] = prog
			end
		end

		# Convenience class.
		# Mainly extends {Sequencing::Sheet} with an {#add_key} function, which
		# self-registers this program under the last created {SequenceCollection}.
		class ProgramSheet < TEF::Sequencing::Sheet

			# Optional key to use when passing to {Sequencing::Player#[]=}.
			# Different keys are necessary to not overwrite the previous running
			# program.
			attr_accessor :program_key

			def initialize()
				super()

				yield(self) if block_given?
			end
			
			# Register this sheet under a given key.
			# Syntax is the same as {Selector#register_ID}, with a default
			# variant of '.mp3' to comply with the default variant set by
			# {SoundCollection}.
			def add_key(title, groups = [], variation = '.mp3', options = nil)
				prog_collection = SequenceCollection.current_collection
				raise "No program collection was instantiated yet!" unless prog_collection

				id = ID.new(title, groups, variation)

				prog_collection[id] = self

				prog_collection.sheet_opts[id] = options if options.is_a? Hash
			end
		end
	end
end
