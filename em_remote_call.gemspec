# encoding: utf-8

$:.unshift File.expand_path('../lib', __FILE__)
require 'em_remote_call/version'

Gem::Specification.new do |s|
  s.name         = "em_remote_call"
  s.version      = EmRemoteCall::VERSION
  s.authors      = ["Niko Dittmann"]
  s.email        = "mail+git@niko-dittmann.com"
  s.homepage     = "http://github.com/niko/em_remote_call"
  s.summary      = "Provides an Eventmachine server/client couple which allows the client to call methods within the server process, including local client-callbacks."
  s.description  = s.summary
  
  s.add_dependency "eventmachine"
  s.add_dependency "is_a_collection"
  s.add_dependency "em_json_connection"
  
  s.files        = Dir['lib/**/*.rb']
  s.test_files   = Dir['spec/**/*_spec.rb']
  
  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rubyforge_project = '[none]'
end
