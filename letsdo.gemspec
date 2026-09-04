# frozen_string_literal: true

require_relative "lib/letsdo/version"

Gem::Specification.new do |spec|
  spec.name    = "letsdo"
  spec.version = Letsdo::VERSION
  spec.authors = ["Sergei O. Udalov"]
  spec.email   = ["udalov.x@mail.ru"]

  spec.summary     = "A local agent worker for Backlog.md/markdown tasks"
  spec.description = "letsdo — a local agent worker for Backlog.md/markdown tasks. " \
                     "OOP structure: Letsdo::PromptStore (agents/), Letsdo::OutputStreamer " \
                     "and Letsdo::PiRunner (pi --mode json), Letsdo::Agent (one run), " \
                     "Letsdo::Loop (orchestrator loop), Letsdo::CLI. Minitest tests. " \
                     "Will later be split into a separate repository."
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.0"

  # Runtime dependencies: the interactive TUI. Required lazily inside the
  # tui classes so the plain line-stream mode (pipes/CI/tests) works with
  # zero extra gems.
  spec.add_runtime_dependency "tty-screen", "~> 0.8"
  spec.add_runtime_dependency "tty-cursor", "~> 0.7"
  spec.add_runtime_dependency "tty-reader", "~> 0.9"
  spec.add_runtime_dependency "unicode-display_width", ">= 2.0"

  # RubyGems resolves executables relative to bindir: the literal value
  # "bin/letsdo" would make gem build look for bin/bin/letsdo. The canonical
  # form: bindir="bin" + executables=["letsdo"] — the gem executable file
  # is bin/letsdo, into PATH it goes as the letsdo command.
  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.bindir        = "bin"
  spec.executables   = ["letsdo"]
  spec.require_paths = ["lib"]

  spec.metadata["rubygems_mfa_required"] = "true"
end