begin
  require 'rspec/core/rake_task'
rescue LoadError
  raise 'Run `gem install rspec` to be able to run specs'
else
  RSpec::Core::RakeTask.new(:spec)
end

def gemspec
  @gemspec ||= begin
    file = File.expand_path('../fakeldap.gemspec', __FILE__)
    eval(File.read(file), binding, file)
  end
end

begin
  require 'rake/gempackagetask'
rescue LoadError
  task(:gem) { $stderr.puts '`gem install rake` to package gems' }
else
  Rake::GemPackageTask.new(gemspec) do |pkg|
    pkg.gem_spec = gemspec
  end
  task :gem => :gemspec
end

desc "validate the gemspec"
task :gemspec do
  gemspec.validate
end

