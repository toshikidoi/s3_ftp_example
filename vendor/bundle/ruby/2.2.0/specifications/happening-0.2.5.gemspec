# -*- encoding: utf-8 -*-
# stub: happening 0.2.5 ruby lib

Gem::Specification.new do |s|
  s.name = "happening"
  s.version = "0.2.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Jonathan Weiss"]
  s.date = "2011-08-23"
  s.description = "An EventMachine based S3 client "
  s.email = "jw@innerewut.de"
  s.extra_rdoc_files = ["LICENSE.txt", "README.md"]
  s.files = ["LICENSE.txt", "README.md"]
  s.homepage = "http://github.com/peritor/happening"
  s.licenses = ["BSD"]
  s.rubygems_version = "2.4.5.1"
  s.summary = "An EventMachine based S3 client"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<em-http-request>, [">= 0"])
      s.add_development_dependency(%q<shoulda>, [">= 0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_development_dependency(%q<mocha>, [">= 0"])
    else
      s.add_dependency(%q<em-http-request>, [">= 0"])
      s.add_dependency(%q<shoulda>, [">= 0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<mocha>, [">= 0"])
    end
  else
    s.add_dependency(%q<em-http-request>, [">= 0"])
    s.add_dependency(%q<shoulda>, [">= 0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<mocha>, [">= 0"])
  end
end
