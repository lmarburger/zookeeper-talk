# Naively acquire a lock and performing some work. The lock is not verified
# before each piece of work so it's possible for multiple workers to be running
# at any given time.
#
#   $ bundle exec ruby -I. examples/naive_locking.rb
#
# If explicit cleanup is needed, run the folling in IRB:
#
#   $ bundle exec irb -I. -rexamples/requires.rb
#   > $zk    = ZK.new('127.0.0.1:2181')
#   > locker = $zk.exclusive_locker('work')
#   > $zk.delete(locker.root_lock_path)

require 'zk'

$zk    = ZK.new('127.0.0.1:2181')
locker = $zk.exclusive_locker('work')

puts 'Attempting to acquire lock... '
i = 0

begin
  locker.with_lock do
    loop do
      print "#{i} "
      i += 1
      sleep 0.25
    end
  end

  puts ' Done.'

rescue Zookeeper::Exceptions::NotConnected
  retry
end
