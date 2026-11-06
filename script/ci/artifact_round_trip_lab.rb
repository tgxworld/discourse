require "json"
require "fileutils"
require "bundler"

source = File.expand_path("../..", __dir__)
source = ENV.fetch("ARTIFACT_PROOF_SOURCE", source)
mode = ARGV.fetch(0)
locked = Bundler::LockfileParser.new(File.read("#{source}/Gemfile.lock"))
versions = locked.specs.to_h { |spec| [spec.name, spec.version.to_s] }

if mode == "bundle"
  directory = "#{ENV.fetch('RUNNER_TEMP')}/test-selection-artifact-bundle"
  raise "Bundle workspace exists" if File.exist?(directory)
  FileUtils.mkdir_p(directory)
  names = %w[rspec gitlab-crystalball rubyzip prism json fileutils].select { |name| versions.key?(name) }
  pending = names.dup
  until pending.empty?
    name = pending.shift
    locked.specs.find { |spec| spec.name == name }.dependencies.each do |dependency|
      next if names.include?(dependency.name)
      names << dependency.name
      pending << dependency.name
    end
  end
  File.write(
    "#{directory}/Gemfile",
    "source 'https://rubygems.org'\n" + names.sort.map { |name| "gem #{name.inspect}, #{versions.fetch(name).inspect}\n" }.join,
  )
  FileUtils.cp("#{source}/Gemfile.lock", "#{directory}/Gemfile.lock")
  File.write("#{directory}/expected-versions.json", JSON.generate(versions.slice(*names)))
  exit
end

raise "Unexpected mode" unless %w[produce consume].include?(mode)
expected_versions = JSON.parse(File.read("#{ENV.fetch('RUNNER_TEMP')}/test-selection-artifact-bundle/expected-versions.json"))
Gem.loaded_specs.each do |name, spec|
  next unless expected_versions.key?(name)
  raise "Dependency differs from repository lock: #{name}" unless spec.version.to_s == expected_versions.fetch(name)
end
require "#{source}/script/ci/test_job"
require "#{source}/script/ci/test_selection"
require "#{source}/script/ci/test_mapping_download"

root = "#{ENV.fetch('RUNNER_TEMP')}/test-selection-artifact-fixture"
raise "Fixture workspace exists" if File.exist?(root)
FileUtils.mkdir_p(root)
Dir.chdir(root)
FileUtils.mkdir_p(%w[lib spec tmp])
File.symlink("#{source}/script", "script")
value_source = "module ArtifactValue\n  def self.value\n    :original\n  end\nend\n"
File.write("lib/value.rb", value_source)
%w[a b].each do |name|
  File.write("spec/#{name}_spec.rb", "require_relative '../lib/value'\nRSpec.describe #{name.inspect} do\n  it('reads the value') { expect(ArtifactValue.value).to eq(:original) }\nend\n")
end
File.write("spec/c_spec.rb", "RSpec.describe('independent') { it('passes') { expect(1).to eq(1) } }\n")
revision = ENV.fetch("GITHUB_SHA")
catalog = {
  "revision" => revision,
  "jobs" => {
    "proof" => {
      "environment" => "artifact-round-trip-fixture",
      "runner" => "rspec",
      "command" => %w[bundle exec rspec --options /dev/null --order defined],
      "inventory" => Dir["spec/*_spec.rb"].sort,
      "mapping_changes" => [],
      "verified_sources" => [],
    },
  },
}
File.write("tmp/catalog.json", JSON.generate(catalog))
input = catalog.merge("mode" => "full", "main" => true, "changes" => [], "test_changes" => [], "deleted_tests" => [])

if mode == "produce"
  raise "Producer requires an actual main push" unless ENV.fetch("GITHUB_REF") == "refs/heads/main" && ENV.fetch("GITHUB_EVENT_NAME") == "push"
  ENV["TEST_MAPPING_COLLECT"] = "1"
  File.write("tmp/full-plan.json", JSON.generate(TestSelection::Planner.new(input).plan))
  TestJob.run(plan_path: "tmp/full-plan.json", catalog_path: "tmp/catalog.json", job_name: "proof", directory: "tmp/producer")
  baseline = JSON.parse(File.read("tmp/producer/execution.json"))
  raise "Invalid baseline execution" unless baseline.fetch("success") && baseline.fetch("exact") && baseline.fetch("loaded") == baseline.fetch("executed_files") && baseline.fetch("executed_files") == catalog.fetch("jobs").fetch("proof").fetch("inventory")
  mapping = JSON.parse(File.read("tmp/test-mappings/proof.json"))
  raise "Incomplete fixture producer" unless mapping.fetch("complete") && mapping.fetch("revision") == revision && mapping.fetch("tests").keys.sort == catalog.fetch("jobs").fetch("proof").fetch("inventory")
  FileUtils.mkdir_p("tmp/incompatible-mapping")
  File.write("tmp/incompatible-mapping/proof.json", JSON.generate(mapping.merge("revision" => "f" * 40)))
  puts JSON.generate(mode: mode, revision: revision, tests: mapping.fetch("tests").keys, scope: "Three actual fixture specs, not a full Discourse inventory")
  exit
end

TestMappingDownload.fetch(directory: "tmp/downloaded", workflow: "tests")
mapping = JSON.parse(File.read("tmp/downloaded/proof.json"))
producer = JSON.parse(File.read("tmp/downloaded/producer.json"))
raise "Unexpected producer revision" unless mapping.fetch("revision") == producer.fetch("revision") && producer.fetch("revision") == revision
rejection = nil
begin
  TestMappingDownload.fetch(directory: "tmp/rejected", workflow: "migration-tests")
rescue RuntimeError => error
  rejection = error.message
end
raise "Incompatible artifact was accepted" unless rejection == "Mapping producer differs from workflow" && !File.exist?("tmp/rejected/proof.json")
ENV.update("GITHUB_EVENT_NAME" => "pull_request", "GITHUB_REF" => "refs/pull/1/merge", "TEST_MAPPING_COLLECT" => "0")
File.write("lib/value.rb", value_source.sub(":original", ":broken"))
description = mapping.fetch("source_checks").fetch("lib/value.rb")
raise "Unexpected source structure" unless RspecSourceStructure.matches?(path: "lib/value.rb", description: description)
catalog.fetch("jobs").fetch("proof").merge!("mapping" => mapping, "verified_sources" => ["lib/value.rb"], "changed_methods" => RspecSourceStructure.changed_methods(path: "lib/value.rb", description: description))
File.write("tmp/catalog.json", JSON.generate(catalog))
candidate = TestSelection::Planner.new(input.merge("mode" => "select", "main" => false, "changes" => ["lib/value.rb"])).plan
raise "Wrong selected files" unless candidate.fetch("files") == %w[spec/a_spec.rb spec/b_spec.rb]
File.write("tmp/candidate-plan.json", JSON.generate(candidate))
File.write("tmp/reference-plan.json", JSON.generate(TestSelection::Planner.new(input).plan))
%w[candidate reference].each do |name|
  begin
    TestJob.run(plan_path: "tmp/#{name}-plan.json", catalog_path: "tmp/catalog.json", job_name: "proof", directory: "tmp/#{name}")
  rescue RuntimeError
    raise unless File.file?("tmp/#{name}/execution.json")
  end
end
selected = JSON.parse(File.read("tmp/candidate/execution.json"))
reference = JSON.parse(File.read("tmp/reference/execution.json"))
raise "Execution differs from assignment" unless selected.fetch("exact") && reference.fetch("exact") && selected.fetch("loaded") == candidate.fetch("files") && selected.fetch("executed_files") == candidate.fetch("files")
raise "Unexpected execution error" if [selected, reference].any? { |record| record.fetch("non_example_failure") || record.fetch("unreported_failure") }
raise "Failure was missed" unless selected.fetch("failures").length == 2 && selected.fetch("failures") == reference.fetch("failures") && reference.fetch("executed_files").length == 3
record = {
  scope: "Actual GitHub artifact publication, shipping HTTP download and validation, then miniature fixture planning and execution. Not full Discourse collection or PR trigger verification.",
  producer: producer,
  changeset: { "lib/value.rb" => { before: value_source, after: File.read("lib/value.rb") } },
  selected: selected.fetch("executed_files"),
  selection_reasons: candidate.fetch("reasons"),
  reference: reference.fetch("executed_files"),
  candidate_failures: selected.fetch("failures"),
  reference_failures: reference.fetch("failures"),
  incompatible_artifact_rejection: rejection,
}
File.write("tmp/artifact-proof.json", JSON.pretty_generate(record))
puts JSON.generate(record)
