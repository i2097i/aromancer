require :listen.to_s

listener = Listen.to(*[:lib.to_s, :bin.to_s, :spec.to_s, :locale.to_s], only: /[\.rb\.yml]/) {|modified, added, removed|
  # puts modified
  # puts added
  # puts removed 
  system("exec rake make")
}
listener.start
sleep
