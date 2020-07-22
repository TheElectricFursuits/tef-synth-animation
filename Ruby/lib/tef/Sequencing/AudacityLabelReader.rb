
module TEF
	module Sequencing
		class AudacityReader
			def initialize(file)
				@tracks = Hash.new({});

				File.open(file, 'r') do |f|
					current_track = 'default';
					@tracks['default'] = [];

					f.each do |line|
						m = /^(?<start>[\.\d]+)\s+(?<stop>[\d\.]+)\s+(?<text>\S.+)/.match line
						next unless m;

						if(m[:text] =~ /TRACK:\s*(\S.+)/)
							current_track = $1;
							@tracks[current_track] = [];
						else
							@tracks[current_track] << { start: m[:start].to_f, stop: m[:stop].to_f, text: m[:text] }
						end
					end
				end
			end

			def [](name)
				return [] if @tracks[name].nil?

				return @tracks[name]
			end
		end
	end
end
