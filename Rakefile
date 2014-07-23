require "bundler"
Bundler.setup

specfile='hash-params.gemspec'
gemspec = eval(File.read(specfile))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + [specfile] do
  system "gem build #{specfile}"
end
