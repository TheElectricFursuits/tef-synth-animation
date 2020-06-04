


# TheElectricFursuits module.
# @see https://github.com/TheElectricFursuits
module TEF
	# Program Selection related module
	#
	# This module is meant to wrap around the functions that define and help with
	# program selection.
	# Its main purpose is to provide an easy to use identification and selection
	# system for the various animations and effects of a fursuit. Often, different
	# effects can have the same name (such as a 'hello' animation), and
	# even within a certain type of animation (a group), variations of the same
	# animaton can occour.
	#
	# The code here thusly provides a {ProgramSelection::ID} for identification,
	# as well as a {ProgramSelection::Selector} that eases selection of a fitting
	# program in certain situations.
	module ProgramSelection
		# Program ID class.
		#
		# This class is meant to uniquely identify a specific program.
		# It also provides a {#hash} and {#==} operator, allowing the use
		# as hash key.
		class ID
			# @return [String] Main title of the program.
			#  Often defines the action the program will execute, i.e. 'hello'
			#  or 'red alert'
			attr_reader :title
			# @return [Array<String>] List of groups this program belongs to.
			#  Further defines the program by providing a bit of context, such as
			#  'portal', 'glad os', etc.
			attr_reader :groups

			# @return [String] The variant of this program.
			#  Its main purpose is to separate different variations of the same
			#  general program, such as when there are different 'hello's from
			#  the same groups. Has no effect on the actual selection.
			attr_reader :variant

			# @return [Numeric] The hash key of this ID. Allows
			#  identification and comparison of keys in a Hash. Two keys match if
			#  they have the same groups, title and are of the same variant.
			attr_reader :hash

			def initialize(title, groups, variant)
				@title = title;
				@groups = groups.sort
				@variant = variant

				@hash = @title.hash ^ @groups.hash ^ @variant.hash
			end

			# @return [true, false] Two keys match if
			#  they have the same groups, title and are of the same variant.
			def ==(other)
				if other.is_a? String
					@title == other
				elsif other.is_a? ID
					return false if @title != other.title
					return false if @variant != other.variant
					return false if @groups != other.groups

					true
				end
			end
			alias eql? ==

			# @return [-1..1] Sorting operator, sorts alphabetically by title,
			#  then group, then variant.
			def <=>(other)
				tsort = (@title <=> other.title)
				return tsort unless tsort.zero?

				gsort = (@groups <=> other.groups)
				return gsort unless gsort.zero?

				@variant <=> other.variant
			end

			# Compute the selection score for this ID.
			# Used in {Selector} to determine the best-matching program ID
			# for a given group scoring.
			#
			# @param [Hash<String, Numeric>] Hash of group weights. Any group
			#  of this ID that has a weight will be added to the score.
			# @return [Numeric] Sum of the selected group weights.
			def get_scoring(group_weights)
				score = 0;

				@groups.each do |g|
					if weight = group_weights[g]
						score += weight
					end
				end

				score
			end
		end
	end
end
