# Modified examples/system_notice.rb to demonstrate using zookeeper to roll out
# a new code path.
#
#   $ bundle exec ruby -I. examples/modified_system_notice.rb
#
# Send the INT signal (Ctrl+C) to print the current SystemNotice value. Send
# the QUIT signal (Ctrl+\) to quit the program.
#
# Open an IRB session from another terminal to update the SystemNotice.
#
#   $ bundle exec irb -I. -r examples/requires.rb

require 'colorize'
require 'system_notice'

# Global zookeeper connection
$zk = ZK.new('127.0.0.1:2181')

$notice = SystemNotice.new
$config = DistributedHashTable.new($zk, '/config').watch!

def print_notice
  if $config['colorized_notice']
    colorized_notice
  else
    ugly_print_notice
  end
end

def colorized_notice
  puts
  puts '-'*80
  puts Colorize.colorize($notice.color, $notice.message)
  puts '-'*80
  puts
end

def ugly_print_notice
  puts
  puts '-'*80
  puts $notice.message
  puts '-'*80
  puts
end

print_notice



# Can't use a mutex from within a signal handler.
# Use a pipe to run the printing from a Thread.

reader, writer = IO.pipe
printer = Thread.new(reader) do |reader|
  loop do
    # Block until one byte can be read from the pipe
    # and print the notice.
    reader.read(1)
    print_notice
  end
end

# Use Ctrl-C to print the current notice.
Signal.trap("INT") do
  writer.write('x')
end

# Use Ctrl-\ to quit the process
Signal.trap("QUIT") do
  puts
  exit
end


# 😴 Wait on the infinite looping thread. 😴
printer.join
