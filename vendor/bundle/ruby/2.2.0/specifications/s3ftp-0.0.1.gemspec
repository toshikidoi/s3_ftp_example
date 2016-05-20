# -*- encoding: utf-8 -*-
# stub: s3ftp 0.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "s3ftp"
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["James Healy"]
  s.date = "2011-11-18"
  s.description = "Run an FTP server that persists all data to an Amazon S3 bucket"
  s.email = ["jimmy@deefa.com"]
  s.extra_rdoc_files = ["README.markdown", "MIT-LICENSE"]
  s.files = ["MIT-LICENSE", "README.markdown"]
  s.homepage = "http://github.com/yob/s3ftp"
  s.rdoc_options = ["--title", "S3-FTP Documentation", "--main", "README.markdown", "-q"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")
  s.rubygems_version = "2.4.5.1"
  s.summary = "An FTP proxy in front of an Amazon S3 bucket"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.6"])
      s.add_runtime_dependency(%q<em-ftpd>, [">= 0"])
      s.add_runtime_dependency(%q<happening>, [">= 0"])
      s.add_runtime_dependency(%q<nokogiri>, [">= 0"])
    else
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.6"])
      s.add_dependency(%q<em-ftpd>, [">= 0"])
      s.add_dependency(%q<happening>, [">= 0"])
      s.add_dependency(%q<nokogiri>, [">= 0"])
    end
  else
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.6"])
    s.add_dependency(%q<em-ftpd>, [">= 0"])
    s.add_dependency(%q<happening>, [">= 0"])
    s.add_dependency(%q<nokogiri>, [">= 0"])
  end
end
