
require_relative 'ProgramID.rb'

module TEF
	module ProgramSelection
		# Program Selector class.
		#
		# This class's purpose is to provide a central list of all known
		# programs, as well as to give the user a method of easily selecting
		# a matching program for a given situation or query.
		class Selector

			# @return [Hash<String, Numeric>] Weights of groups.
			#  Used when selecing a program via {#fetch_ID} or {#fetch_string}.
			#  Higher weights mean higher preference
			attr_accessor :group_weights

			def initialize()
				@known_programs = {} # Hash based on titles
				@known_groups = {}

				@group_weights = {}
			end

			# Register a new ID to the list of known {ID}s.
			#
			# This will ensure that the given {ID} is present in the list
			# of known IDs. It will then return either the given {ID} or an equivalent
			# ID already present in the list. Either can be used for identification.
			#
			# This function can be used in two ways, either by passing a {ID} as
			# only argument, or by passing a String as first argument and optional
			# group and variant specifiers.
			#
			# @param [ID, String] program Program {ID} OR a String to use
			#   as program title.
			# @param [Array<String>] pgroups Optional list of groups to construct
			#   a new {ID} with.
			# @param [String, nil] pvariant Optional variant specification to
			#   construct a new {ID} with.
			def register_ID(program, pgroups = [], pvariant = nil)
				if program.is_a? String
					program = ID.new(program, pgroups, pvariant)
				end

				proglist = (@known_programs[program.title] ||= [])

				if found_prog = proglist.find { |prg| prg == program }
					return found_prog
				end

				proglist << program

				program.groups.each { |group| @known_groups[group] = true }

				program
			end

			# Fetch an {ID} from the list of known IDs.
			#
			# This will fetch a specific {ID} from the list of IDs, based on
			# its title and group weights.
			# The title MUST match the given title. Then, the group scoring
			# of each matching ID will be calculated, based on {#group_weights} and
			# the given group weights. From all IDs with maximum group weight,
			# a random variant will be selected, and will be returned.
			#
			# @param [String] title Title to look for. Must exactly match the
			#  title of the {ID}.
			# @param [Hash<String, Numeric>] group_weights Group weights. Higher
			#  group score means a specific {ID} will be preferred.
			# @return [nil, ID] Either nil if no {ID} with matching title was found,
			#  or the ID with best group score.
			def fetch_ID(title, group_weights = {})
				return nil if @known_programs[title].nil?

				weights = @group_weights.merge(group_weights)

				current_best = nil;
				current_list = [];

				@known_programs[title].each do |prg|
					p_score = prg.get_scoring(weights);
					current_best ||= p_score

					next if current_best > p_score

					if current_best == p_score
						current_list << prg
					else
						current_best = p_score
						current_list = [prg]
					end
				end

				current_list.sample
			end

			# Fetch an {ID} based on a string.
			#
			# This function performs similarly to {#fetch_ID}, but is based on
			# a more human readable string.
			# The input is parsed as follows:
			# - It is split at the first ' from '
			# - The first part is taken as a title.
			# - The second part will be split through ' and '. Each resulting
			#   array element is taken as group weight with a score of 2.
			#
			# @example
			#  selector.fetch_string('hello from portal and turret')
			#   # This is equivalent to:
			#  selector.fetch_ID('hello', { 'portal' => 2, 'turret' => 2})
			def fetch_string(str)
				title, groups = str.split(" from ");
				groups ||= "";
				groups = groups.split(" and ").map { |g| [g, 2] }.to_h

				fetch_ID(title, groups)
			end

			def all_titles()
				@known_programs.keys
			end

			def all_groups()
				@known_groups.keys
			end
		end
	end
end
