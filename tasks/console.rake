desc "run irb console with aromancer and autocomplete"
task :console do
  require :irb.to_s
  require :"irb/completion".to_s
  require :aromancer.to_s
  ARGV.clear
  IRB.start(__FILE__)
end
