require 'yajl'
require 'yajl/json_gem'
require 'zookeeper'
require 'zk'

class DistributedHashTable
  def initialize(zk, path)
    @zk        = zk
    @path      = path
    @mutex     = Mutex.new
    @callbacks = []
    @watch     = false

    reload
  end

  def close
    @mutex.synchronize do
      if @register
        @register.unregister
        @register = nil
      end

      if @on_connected
        @on_connected.unregister
        @on_connected = nil
      end

      if @hash_table
        @hash_table.clear
      end
    end
  end

  def on_change(&block)
    @mutex.synchronize do
      @callbacks << block
    end

    block.call
  end

  def fire
    callbacks = @mutex.synchronize do
      @callbacks.dup
    end

    callbacks.each do |cb|
      begin
        cb.call
      rescue => e
        Papertrail::ExceptionNotifier.notify(e)
      end
    end
  end

  def [](key)
    @mutex.synchronize do
      if @hash_table
        return @hash_table[key]
      end
    end
  end

  def []=(key, value)
    result = @mutex.synchronize do
      update do |hash_table|
        hash_table[key] = value
        hash_table
      end
    end

    fire

    return result
  end

  def has_key?(key)
    @mutex.synchronize do
      if @hash_table
        @hash_table.has_key?(key)
      end
    end
  end

  def delete(key)
    result = @mutex.synchronize do
      update do |hash_table|
        hash_table.delete(key)
        hash_table
      end
    end

    fire

    return result
  end

  def merge(other)
    result = @mutex.synchronize do
      update do |hash_table|
        hash_table.merge(other)
      end
    end

    fire

    return result
  end

  def to_h
    @mutex.synchronize do
      if @hash_table
        @hash_table.dup
      else
        {}
      end
    end
  end

  def each(&block)
    to_h.each(&block)
  end

  def length
    @mutex.synchronize do
      if @hash_table
        @hash_table.length
      else
        0
      end
    end
  end

  def empty?
    length == 0
  end
  alias_method :blank?, :empty?

  def reload
    @mutex.synchronize do
      begin
        current, _ = @zk.get(@path, :watch => @watch)
        @hash_table = Yajl::Parser.parse(current)
      rescue ZK::Exceptions::NoNode
        if @zk.exists?(@path, :watch => @watch)
          retry
        else
          @hash_table = Hash.new
        end
      end
    end

    fire
  end

  def update(&block)
    return update_exists(&block)
  rescue ZK::Exceptions::NoNode
    begin
      return update_initial(&block)
    rescue ZK::Exceptions::NodeExists
      return update_exists(&block)
    end
  end

  def clear
    @mutex.synchronize do
      begin
        @zk.delete(@path)
      rescue ZK::Exceptions::NoNode
      end

      @hash_table = Hash.new
    end
  end

  def update_exists(&block)
    begin
      current, stat = @zk.get(@path, :watch => true)
      hash_table = Yajl::Parser.parse(current)

      result = block.call(hash_table)

      @zk.set(@path, Yajl::Encoder.encode(result), :version => stat.version)
      @hash_table = result

      return result
    rescue ZK::Exceptions::BadVersion
      sleep 0.1 + rand
      retry
    end
  end

  def update_initial(&block)
    begin
      hash_table = Hash.new

      result = block.call(hash_table)

      @zk.create(@path, Yajl::Encoder.encode(result))
      @hash_table = result

      return result
    rescue ZK::Exceptions::NoNode
      @zk.mkdir_p(File.dirname(@path))
      retry
    end
  end

  def watch!
    @watch = true

    @register ||= @zk.register(@path) do
      reload
    end

    @on_connected ||= @zk.on_connected do
      reload
    end

    begin
      reload

    # Record and ignore these exceptions. We'll get the update next time.
    rescue ZK::Exceptions::OperationTimeOut
      Papertrail.librato_metriks.meter('zookeeper.error.operation_timeout').mark
    rescue ::Zookeeper::Exceptions::ContinuationTimeoutError
      Papertrail.librato_metriks.meter('zookeeper.error.continuation_timeout').mark
    rescue ::Zookeeper::Exceptions::NotConnected
      Papertrail.librato_metriks.meter('zookeeper.error.not_connected').mark
    end

    self
  end

  def inspect
    variables = instance_variables.reject do |iv|
      %w(@zk @mutex @register @on_connected @callbacks).include?(iv.to_s)
    end.map do |iv|
      "#{iv}=#{instance_variable_get(iv).inspect}"
    end.join(', ')

    '#<%s:0x%0x %s>' % [ self.class.name, object_id, variables ]
  end
end
