# frozen_string_literal: true

require_relative "lib/letsdo/version"

Gem::Specification.new do |spec|
  spec.name    = "letsdo"
  spec.version = Letsdo::VERSION
  spec.authors = ["Sergei O. Udalov"]
  spec.email   = ["udalov.x@mail.ru"]

  spec.summary     = "A local agent worker for Backlog.md/markdown tasks"
  spec.description = "letsdo turns a plain markdown backlog into a team of " \
                     "autonomous local agents. Each agent is just a prompt " \
                     "file in agents/; run `letsdo <name>` and it works " \
                     "through every open task assigned to that agent, one " \
                     "task per run, and stops cleanly on Ctrl+C. No " \
                     "framework, no hosted platform — the backlog folder is " \
                     "the single source of truth and task data never leaves " \
                     "your machine."
  spec.license = "MIT"

  # Supported Ruby floor matches what CI actually tests (3.3 and 4.0).
  # Ruby 3.0/3.1/3.2 are end-of-life, so claiming support for them while
  # never testing them would be dishonest packaging.
  spec.required_ruby_version = ">= 3.3"

  # Runtime dependencies: the interactive TUI. Required lazily inside the
  # tui classes so the plain line-stream mode (pipes/CI/tests) works with
  # zero extra gems.
  spec.add_runtime_dependency "tty-screen", "~> 0.8"
  spec.add_runtime_dependency "tty-cursor", "~> 0.7"
  spec.add_runtime_dependency "tty-reader", "~> 0.9"
  spec.add_runtime_dependency "unicode-display_width", ">= 2.0"

  # Development dependency: style checks (default RuboCop config, enforced
  # in CI). Not installed by the CI workflow via bundler — the workflow
  # installs the same constraint with `gem install` on a clean Ruby.
  spec.add_development_dependency "rubocop", "~> 1.77.0"

  # The AI backend is the external `pi` CLI (default, overridable via
  # LETSDO_PI_COMMAND) — a runtime *requirement*, not a rubygem, so it is
  # documented in the README rather than declared as a dependency.
  # User-facing guides live in docs/ and are linked from the README, so
  # they must ship inside the gem for installed copies to be self-contained.
  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE",
                           "CHANGELOG.md", "docs/**/*.md", "letsdo.gemspec"]
  spec.bindir        = "bin"
  spec.executables   = ["letsdo"]
  spec.require_paths = ["lib"]

  spec.homepage = "https://github.com/sergio-fry/letsdo"

  # source_code_uri shares the homepage URL on purpose (the source *is* the
  # project home); homepage_uri is deliberately not duplicated in metadata
  # because an identical homepage_uri + source_code_uri pair makes
  # `gem build` warn.
  spec.metadata["source_code_uri"]       = "https://github.com/sergio-fry/letsdo"
  spec.metadata["bug_tracker_uri"]       = "https://github.com/sergio-fry/letsdo/issues"
  spec.metadata["changelog_uri"]         = "https://github.com/sergio-fry/letsdo/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"]     = "https://github.com/sergio-fry/letsdo/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"]     = "https://rubygems.org"
end
