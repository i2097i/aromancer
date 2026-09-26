desc "rake install && rspec"
task :make do
  exec "bundle graph && rake install && rspec --backtrace"
end
