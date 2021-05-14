
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "batch_loader_active_record/version"

Gem::Specification.new do |spec|
  spec.name          = "batch-loader-active-record"
  spec.version       = BatchLoaderActiveRecord::VERSION
  spec.authors       = ["mathieul, hishammalik"]
  spec.email         = ["info@arkhitech.com"]

  spec.summary       = %q{Active record lazy association generator leveraging batch-loader to avoid N+1 DB queries.}
  spec.description   = %q{Active record lazy association generator leveraging batch-loader to avoid N+1 DB queries.}
  spec.homepage      = "https://github.com/arkhitech/batch-loader-active-record"
  spec.license       = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "batch-loader", "~> 2.0.1"
  spec.add_dependency "activerecord", ">= 4.2.0"

  spec.add_development_dependency "bundler", "~> 2.2.13"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "rspec", ">= 3.0"
  spec.add_development_dependency "pry-byebug", ">= 3.5"
  spec.add_development_dependency "sqlite3", ">= 1.3.13"
  spec.add_development_dependency "activesupport", ">= 4.2.0"
  spec.add_development_dependency "appraisal", ">= 2.2.0"
end
