module EM::RemoteCall
  def remote_method(name, opts={})
    unless respond_to? :remote_connection
      class << self
        define_method(:remote_connection=){ |conn| @remote_connection = conn }
        define_method(:remote_connection) {        @remote_connection        }
      end
    end
    
    define_method name do |*method_opts, &callb|
      return unless self.class.remote_connection
      
      if !callb && method_opts.last.is_a?(Proc)
        callb = method_opts.pop
      end
      if method_opts.last.is_a? Proc
        return_block = method_opts.pop
      end
      argument = method_opts.shift
      
      remote_method = opts[:calls] || name
      klass         = opts[:class_name] || self.class.to_s
      id            = opts[:find_by] && send(opts[:find_by]) # when it's nil, it's considered a class method.
      
      call = {:argument => argument, :instance => {:class => klass, :id => id}, :method => remote_method}
      self.class.remote_connection.call(call, callb, return_block)
    end
  end
end

class EM::RemoteCall::Callback
  is_a_collection :object_id
  
  def initialize(&callb)
    @callback = callb
    super
  end
  
  def call(arg)
    @callback.call arg
    remove_from_collection
  end
end

module EM::RemoteCall::Client
  include EM::JsonConnection::Client
  
  def json_parsed(hash)
    if id = hash[:callback_id]
      if callb = EM::RemoteCall::Callback.find(id)
        callb.call hash[:argument]
      end
    end
  end
  
  def call(call, callb, return_block)
    if callb
      callb = EM::RemoteCall::Callback.new(&callb)
      call.merge!({ :callback_id => callb.object_id })
    end
    if return_block
      return_block = EM::RemoteCall::Callback.new(&return_block)
      call.merge!({ :return_block_id => return_block.object_id })
    end
    send_data call
  end
end
