# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "puppet_facts/version"

Gem::Specification.new do |s|
  s.name        = "puppet_facts"
  s.version     = PuppetFacts::Version::STRING
  s.authors     = ["Puppet Labs"]
  s.email       = ["modules-dept@puppetlabs.com"]
  s.homepage    = "http://github.com/puppetlabs/puppet_facts"
  s.summary     = "Standard facts fixtures for PE and POSS platforms"
  s.description = "Contains facts from many PE and POSS systems"
  s.licenses    = 'Apache-2.0'

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  # Runtime dependencies, but also probably dependencies of requiring projects
  #s.add_runtime_dependency 'rspec'
end
