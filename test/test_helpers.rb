# -*- mode: ruby; compile-command: "rake test"; -*-

require 'test/unit'
require 'rubygems'
require 'temps'

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))

class Test::Unit::TestCase

  class NoTestName < ArgumentError ; end
  class OverwriteTest < ArgumentError ; end

  FIXTURES_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))

  ################
  # HELPER FUNCTIONS
  ################

  def setup_working_directory
    @original_directory = Dir.pwd
    @working_directory = Temps.mktemp(:dir => true)
    Dir.chdir(@working_directory)
  end

  def teardown_working_directory
    Dir.chdir(@original_directory)
    FileUtils.rm_r(@working_directory) if File.directory?(@working_directory)
  end

  def array_hash_test (array_of_hashes)
    # given Array of Hashes, each possessing :in and :exp key/value pairs,
    # yield value of :in to called, and assert that result matches :exp value
    array_of_hashes.each do |e|
      assert_equal(e[:exp], yield(e[:in]), "CASE: #{e[:in].inspect}")
    end
  end

  def using (*filenames)
    raise "filenames = #{filenames.inspect}" unless filenames.kind_of?(Array)
    filenames.flatten!

    pwd = Dir.pwd
    filenames.each do |x|
      fixture = File.join(FIXTURES_DIR, File.basename(x))
      FileUtils.cp(fixture, pwd, :preserve => true)
    end
  end

  public

  # Dynamically create test method with fixtures
  def self.create_test (name_stub, *fixtures, &block)
    raise NoTestName if name_stub.to_s == ""
    method_name = %Q[test_#{name_stub}].gsub(/\W+/, "_").downcase
    raise OverwriteTest if instance_methods.include?(method_name.to_sym)
    self.define_test_method(method_name, *fixtures, &block)
  end

  private

  def self.define_test_method (method_name, *fixtures, &block)
    define_method(method_name.to_sym) do
      using(fixtures) unless fixtures.empty?
      assert_block(method_name) { yield(*fixtures) }
    end
  end
end
