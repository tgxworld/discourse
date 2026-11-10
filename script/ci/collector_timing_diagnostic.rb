# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

root = Dir.pwd
directory = File.expand_path(ARGV.shift || "tmp/producer-diagnostics/collector-timing")
FileUtils.mkdir_p(directory)
workloads = {
  "retry-set" => %w[
    ./spec/lib/html_to_markdown_spec.rb[1:32]
    ./spec/requests/markdown_endpoints_spec.rb[1:20]
    ./spec/requests/posts_controller_spec.rb[1:16:2]
  ],
  "html-only" => %w[./spec/lib/html_to_markdown_spec.rb[1:32]],
  "user-description" => %w[./spec/models/user_spec.rb[1:114:1]],
}
unless ARGV.empty?
  unknown = ARGV - workloads.keys
  raise ArgumentError, "Unknown workloads: #{unknown.join(", ")}" if unknown.any?
  workloads = workloads.slice(*ARGV)
end
record = {
  revision: ENV.fetch("GITHUB_SHA"),
  ruby: RUBY_DESCRIPTION,
  yjit_environment: ENV["RUBY_YJIT_ENABLE"],
  diagnostic_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  collector_sha256: Digest::SHA256.file("script/ci/ruby_dependencies.rb").hexdigest,
  seed: 4_018_241_148,
  scope:
    "Original example IDs and assertions, isolated processes, JSON formatter. Diagnostic only, never an eligible mapping bundle.",
  phases: [],
}

workloads.each do |name, targets|
  %w[baseline collected].each do |mode|
    folder = "#{directory}/#{name}-#{mode}"
    raise "Diagnostic output already exists: #{folder}" if File.exist?(folder)
    FileUtils.mkdir_p(folder)
    files = targets.map { |target| target.split("[", 2).first.delete_prefix("./") }.uniq.sort
    inventory = "#{folder}/inventory.json"
    File.write(inventory, JSON.generate(files.map { |file| File.realpath(file) }))
    original_rubyopt = ENV.fetch("RUBYOPT", "")
    environment = {
      "BUNDLE_GEMFILE" => "#{root}/Gemfile",
      "CI" => "1",
      "RAILS_ENV" => "test",
      "LOAD_PLUGINS" => "0",
      "COLLECT_TEST_MAPPING" => mode == "collected" ? "1" : "0",
      "COLLECT_RSPEC_MAPPING" => mode == "collected" ? "1" : "0",
      "TEST_SELECTION_ROOT" => root,
      "TEST_SELECTION_ENVIRONMENT" => "collector-diagnostic",
      "TEST_SELECTION_INVENTORY" => inventory,
      "TEST_EXECUTION_DIRECTORY" => "#{folder}/workers",
      "RSPEC_MAPPING_DIRECTORY" => "#{folder}/mapping",
      "TEST_MAPPING_PROCESS_ID" => "#{name}-#{mode}",
      "TEST_SELECTION_ORIGINAL_RUBYOPT" => original_rubyopt,
      "BUNDLER_ORIG_RUBYOPT" => ENV.fetch("BUNDLER_ORIG_RUBYOPT", original_rubyopt),
      "RUBYOPT" => [
        original_rubyopt,
        "-rbundler/setup",
        "-r#{root}/script/ci/rspec_execution.rb",
      ].join(" "),
    }
    command = [
      "bin/rspec",
      *targets,
      "--seed",
      record.fetch(:seed).to_s,
      "--format",
      "json",
      "--out",
      "#{folder}/rspec.json",
    ]
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    pid = Process.spawn(environment, *command, out: "#{folder}/process.log", err: %i[child out])
    puts JSON.generate(event: "started", workload: name, mode: mode, pid: pid)
    $stdout.flush
    _, status = Process.wait2(pid)
    report = File.file?("#{folder}/rspec.json") ? JSON.parse(File.read("#{folder}/rspec.json")) : {}
    receipts = Dir["#{folder}/workers/rspec-*.json"].map { |file| JSON.parse(File.read(file)) }
    summary = report.fetch("summary", {})
    examples = report.fetch("examples", [])
    exact =
      examples.map { |example| example.fetch("id") }.sort == targets.sort && receipts.one? &&
        receipts.first.fetch("files") == files && receipts.first.fetch("executed_files") == files
    success =
      status.success? && exact && summary["example_count"] == targets.length &&
        summary["failure_count"] == 0 && summary["errors_outside_of_examples_count"] == 0 &&
        receipts.first.fetch("description_errors").empty? &&
        !receipts.first.fetch("non_example_failure")
    phase = {
      workload: name,
      mode: mode,
      command: command,
      pid: pid,
      exit_code: status.exitstatus,
      signal: status.termsig,
      elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
      summary: summary,
      examples: examples,
      receipts: receipts,
      exact: exact,
      success: success,
    }
    record.fetch(:phases) << phase
    record[:success] = record.fetch(:phases).all? { |item| item.fetch(:success) }
    output = JSON.pretty_generate(record)
    File.write("#{directory}/result.json", output)
    puts JSON.generate(phase.reject { |key, _| %i[examples receipts].include?(key) })
    $stdout.flush
  end
end

exit(record.fetch(:success) ? 0 : 1)
