require 'distributed_hash_table'

class SystemNotice

  # Singleton hash table for system notice.
  def self.config
    @config ||= DistributedHashTable.new($zk, '/system_notice').watch!
  end

  def self.clear
    config.clear
  end

  def self.update(message, color)
    config['message'] = message
    config['color']   = color
  end


  def message
    self.class.config['message']
  end

  def color
    self.class.config['color']
  end

  def inspect
    variables = "message=#{message.inspect}, color=#{color.inspect}"

    # #<SystemNotice message=nil, color=nil>
    '#<%s %s>' % [ self.class.name, variables ]
  end
end
