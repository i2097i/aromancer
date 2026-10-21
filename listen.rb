require :listen.to_s

listener = Listen.to(*[:lib.to_s, :bin.to_s, :spec.to_s, :locale.to_s], only: /[\.rb\.yml]/) {|modified, added, removed|
  system("exec rake install")
}
listener.start
sleep
