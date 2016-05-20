# -*- encoding: utf-8 -*-
# stub: em-ftpd 0.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "em-ftpd"
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["James Healy"]
  s.date = "2011-11-18"
  s.description = "Build a custom FTP daemon backed by a datastore of your choice"
  s.email = ["jimmy@deefa.com"]
  s.executables = ["em-ftpd"]
  s.extra_rdoc_files = ["README.markdown", "MIT-LICENSE"]
  s.files = ["MIT-LICENSE", "README.markdown", "bin/em-ftpd"]
  s.homepage = "http://github.com/yob/em-ftpd"
  s.rdoc_options = ["--title", "EM::FTPd Documentation", "--main", "README.markdown", "-q"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")
  s.rubygems_version = "2.4.5.1"
  s.summary = "An FTP daemon framework"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.6"])
      s.add_development_dependency(%q<em-redis>, [">= 0"])
      s.add_development_dependency(%q<guard>, [">= 0"])
      s.add_development_dependency(%q<guard-process>, [">= 0"])
      s.add_development_dependency(%q<guard-bundler>, [">= 0"])
      s.add_development_dependency(%q<guard-rspec>, [">= 0"])
      s.add_runtime_dependency(%q<eventmachine>, ["~> 1.0.0.beta1"])
    else
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.6"])
      s.add_dependency(%q<em-redis>, [">= 0"])
      s.add_dependency(%q<guard>, [">= 0"])
      s.add_dependency(%q<guard-process>, [">= 0"])
      s.add_dependency(%q<guard-bundler>, [">= 0"])
      s.add_dependency(%q<guard-rspec>, [">= 0"])
      s.add_dependency(%q<eventmachine>, ["~> 1.0.0.beta1"])
    end
  else
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.6"])
    s.add_dependency(%q<em-redis>, [">= 0"])
    s.add_dependency(%q<guard>, [">= 0"])
    s.add_dependency(%q<guard-process>, [">= 0"])
    s.add_dependency(%q<guard-bundler>, [">= 0"])
    s.add_dependency(%q<guard-rspec>, [">= 0"])
    s.add_dependency(%q<eventmachine>, ["~> 1.0.0.beta1"])
  end
end
