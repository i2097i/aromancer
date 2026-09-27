desc "bundle graph && rake install && rspec --backtrace"
task :make do
  exec "bundle graph && rake install && rspec --backtrace"
end
