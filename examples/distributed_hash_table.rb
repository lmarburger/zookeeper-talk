# Spawns a thread to listen for change events on a DistributedHashTable while
# the main thread updates the 
#
#   $ bundle exec ruby -I. examples/distributed_hash_table.rb

require 'distributed_hash_table'

# Spawn a consumer thread to watch and print current time changes.
Thread.new do
  zk = ZK.new('127.0.0.1:2181')
  ht = DistributedHashTable.new(zk, '/current_time').watch!

  # Block called each time `/current_time` changes.
  puts "Attaching handler"
  ht.on_change do
    puts "Change: #{ht.to_h.inspect}"
    puts
  end

end


# Update the current time every second.
loop do
  sleep 1

  zk = ZK.new('127.0.0.1:2181')
  ht = DistributedHashTable.new(zk, '/current_time')

  time = Time.now
  puts "Update: #{time.inspect}"

  ht['time'] = time
end
