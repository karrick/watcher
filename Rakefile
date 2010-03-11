require "rubygems"
require "rake/gempackagetask"
require "rake/rdoctask"

require "rake/testtask"
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

task :default => [:test, :clean, :rdoc, :perms, :package]

# This builds the actual gem. For details of what all these options
# mean, and other ones you can add, check the documentation here:
#
#   http://rubygems.org/read/chapter/20
#
spec = Gem::Specification.new do |s|

  # Change these as appropriate
  s.name              = "watcher"
  s.version           = "1.2.4"
  s.summary           = "Abstracts and combines exception handling and program logging"
  s.author            = "Karrick McDermott"
  s.email             = "karrick@karrick.net"
  s.homepage          = "http://github.com/karrick/watcher"
  s.description       = "Watcher provides advanced integrated exception handling and logging
functionality to your Ruby programs."

  s.has_rdoc          = true
  s.extra_rdoc_files  = %w(README)
  s.rdoc_options      = %w(--main README)

  # Add any extra files to include in the gem
  s.files             = %w(HISTORY README TODO) + Dir.glob("{test,lib/**/*}")
  s.require_paths     = ["lib"]

  # If you want to depend on other gems, add them here, along with any
  # relevant versions
  # s.add_dependency("some_other_gem", "~> 0.1.0")

  # If your tests use any gems, include them here
  # s.add_development_dependency("mocha") # for example
end

# This task actually builds the gem. We also regenerate a static
# .gemspec file, which is useful if something (i.e. GitHub) will
# be automatically building a gem for this project. If you're not
# using GitHub, edit as appropriate.
#
# To publish your gem online, install the 'gemcutter' gem; Read more
# about that here: http://gemcutter.org/pages/gem_docs
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Build the gemspec file #{spec.name}.gemspec"
task :gemspec do
  file = File.dirname(__FILE__) + "/#{spec.name}.gemspec"
  File.open(file, "w") {|f| f << spec.to_ruby }
end

# If you don't want to generate the .gemspec file, just remove this line. Reasons
# why you might want to generate a gemspec:
#  - using bundler with a git source
#  - building the gem without rake (i.e. gem build blah.gemspec)
#  - maybe others?
task :package => :gemspec

# Generate documentation
Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.rdoc_files.include("README", "lib/**/*.rb")
  rd.rdoc_dir = "rdoc"
end

desc 'Clear out RDoc and generated packages'
task :clean => [:clobber_rdoc, :clobber_package] do
  %w[watcher.gemspec watcher-debug.log].each do |file|
    rm(file) if File.file?(file)
  end
end

task :perms do
  bin = File.join(File.dirname(__FILE__),'bin')
  system(%Q[find '#{File.dirname(__FILE__)}' -type d -print0 | xargs -0 -I % chmod 755 '%'])
  system(%Q[find '#{File.dirname(__FILE__)}' -type f -print0 | xargs -0 -I % chmod 644 '%'])
  system(%Q[find '#{bin}' -type f -print0 | xargs -0 -I % chmod 755 '%']) if File.directory?(bin)
end
