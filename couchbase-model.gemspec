# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "couchbase/model/version"

Gem::Specification.new do |s|
  s.name        = "couchbase-model"
  s.version     = Couchbase::Model::VERSION
  s.authors     = ["Sergey Avseyev"]
  s.email       = ["sergey.avseyev@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Declarative interface to Couchbase}
  s.description = %q{ORM-like interface allows you to persist your models to Couchbase}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'couchbase', '~> 1.0.0'

  s.add_development_dependency 'rake', '~> 0.8.7'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rdiscount'
  s.add_development_dependency 'yard'
  s.add_development_dependency RUBY_VERSION =~ /^1\.9/ ? 'ruby-debug19' : 'ruby-debug'
end
