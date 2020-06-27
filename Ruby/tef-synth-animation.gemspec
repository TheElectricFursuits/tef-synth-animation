
Gem::Specification.new do |s|
	s.name        = 'tef-animation'
	s.version     = '0.1.1-1'
	s.date        = '2020-05-19'
	s.summary     = 'TEF Animation and Sequencing code'
	s.description = 'A Ruby gem to animate and sequence the "Synth"-Line TEF modules.'
	s.authors     = ["TheSystem", "Xasin"]
	s.files       = [Dir.glob('{bin,lib}/**/*'), 'README.md'].flatten
	s.license     = 'GPL-3.0'

	s.add_runtime_dependency 'tef-furcoms', '~> 0.1'
	s.add_runtime_dependency 'xasin-logger', '~> 0.1'

	s.add_development_dependency 'rubocop', '~> 0.77.0'
end
