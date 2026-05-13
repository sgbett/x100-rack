# frozen_string_literal: true

require_relative "lib/x100/version"

Gem::Specification.new do |spec|
  spec.name = "x100-rack"
  spec.version = X100::VERSION
  spec.authors = ["Simon Bettison"]
  spec.email = ["simon@bettison.org"]

  spec.summary = "Mountable Rack wallet UI for BSV (BRC-100)"
  spec.description = "Composable Rack application providing a web UI for BSV wallet operations. " \
                     "Mount at any path alongside x402/x403 middleware in the x1xx rack stack."
  spec.homepage = "https://github.com/sgbett/x100-rack"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bsv-wallet", ">= 0.100.0"
  spec.add_dependency "bsv-wallet-postgres", ">= 0.100.0"
  spec.add_dependency "erubi", "~> 1.0"
  spec.add_dependency "logger", "~> 1.0"
  spec.add_dependency "rack", "~> 3.0"
  spec.add_dependency "roda", "~> 3.0"
  spec.add_dependency "tilt", "~> 2.0"
end
