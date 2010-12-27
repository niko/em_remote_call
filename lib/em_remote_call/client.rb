class Class
  def has_em_remote_class(remote_class_name, opts)
    extend EM::RemoteCall
    class << self
      attr_accessor :remote_connection
      extend EM::RemoteCall
    end
    
    opts[:name] ||= :default
    opts[:remote_class_name] = remote_class_name
    self.remote_connection = EM::RemoteCall::Client.find(opts[:name]) || EM::RemoteCall::Client.new(opts)
  end
end

module EM::RemoteCall
  def remote_method(method_name, opts={})
    define_method method_name do |*method_args, &callb|
      return unless remote_connection =                                                                                                                                                     
        (self.class.respond_to?(:remote_connection) && self.class.remote_connection) ||                                                                                       
        (self.respond_to?(:remote_connection)       && self.remote_connection)                                                                                                
      
      callback = EM::RemoteCall::Deferrable.new
      callback.callback(&callb) if callb
      
      call = {
        :deferrable_id => callback.object_id,          # store the callbacks object_id to retrieve it later
        :debug         => opts[:debug],                # debugging on client and server
        :method        => opts[:calls] || method_name, # same method name by default
        :arguments     => [*method_args],              # all the args
        :instance      => {
          :class => remote_connection.remote_class_name || self.class.to_s,                # own class name by default
          :id    => !opts[:server_class_method] && send(remote_connection.instance_finder) # when it's nil, it's considered a class method.
      }}
      
      puts "On Client: #{call}" if opts[:debug]
      remote_connection.call call
      return callback
    end
  end
  
  # a convinience wrapper for class methods:
  def remote_class_method(method_name, opts={})
    (class << self; self; end).remote_method method_name, opts.merge({:server_class_method => true})
  end
end

class EM::RemoteCall::Deferrable
  include EventMachine::Deferrable
  is_a_collection :object_id
  
  def set_deferred_status status, *args
    remove_from_collection
    super
  end
end

module EM::RemoteCall::ClientConnection
  include EM::JsonConnection::Client
  
  def json_parsed(hash)
    puts "From server: #{hash}" if hash[:debug]
    
    deffr = EM::RemoteCall::Deferrable.find hash[:deferrable_id]
    deffr.succeed hash[:success] if hash.has_key? :success
    deffr.fail    hash[:error]   if hash.has_key? :error
  end
end

class EM::RemoteCall::Client
  attr_reader :name, :remote_class_name, :instance_finder
  is_a_collection :name
  
  def initialize(opts)
    @name               = opts[:name] ||= :default
    @remote_class_name  = opts[:remote_class_name]
    @socket             = opts[:socket]
    @port               = opts[:port]
    @instance_finder    = opts[:instance_finder] ||= :id
  end
  
  def call(call)
    unless @connection && @connection.connected?
      @connection = EM::RemoteCall::ClientConnection.connect_to *[@socket, @port].compact
    end
    
    @connection.send_data call
  end
  
end
