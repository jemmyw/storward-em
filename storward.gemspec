Gem::Specification.new do |s|
  s.name    = 'storward'
  s.version = '0.1'

  s.authors = ['Jeremy Wells']
  s.email   = 'jemmyw@gmail.com'
  s.date    = "2011-05-21"

  s.description = 'EventMachine HTTP store and forward.'
  s.homepage = 'http://github.com/jemmyw/storward'
  s.rubyforge_project = 'storward'

  s.files      = Dir['lib/**/*'] + Dir['lib/*']
  s.test_files = Dir['spec/integration/**/*']

  s.rdoc_options  = ["--charset=UTF-8"]
  s.require_paths = ["lib"]

  s.rubygems_version = '1.3.6'

  s.summary = 'An EventMachine HTTP store and forward server.'

  s.add_dependency 'addressable', ['>= 2.2.6']
  s.add_dependency 'eventmachine', ['>= 0.12.10']
  s.add_dependency 'eventmachine_httpserver', ['>= 0.2.1']
  s.add_dependency 'em-http-request', ['~> 0.3.0']
end

