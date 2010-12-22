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
      
      callback = EM::RemoteCall::Deferrable.new
      callback.callback(&callb) if callb
      
      call = {
        :argument => method_opts.first,                     # evt. other args will get dropped
        :instance => {
          :class => opts[:class_name] || self.class.to_s,   # own class name by default
          :id => opts[:find_by] && send(opts[:find_by])     # when it's nil, it's considered a class method.
        },
        :method => opts[:calls] || name,                    # same method name by default
        :deferrable_id => callback.object_id                  # store the callbacks object_id to retrieve it later
      }
      
      self.class.remote_connection.call call
      return callback
    end
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

module EM::RemoteCall::Client
  include EM::JsonConnection::Client
  
  def json_parsed(hash)
    id = hash[:deferrable_id]
    deffr = EM::RemoteCall::Deferrable.find(id)
    deffr.succeed hash[:success] if hash.has_key? :success
    deffr.fail    hash[:error]   if hash.has_key? :error
  end
  
  def call(call)
    send_data call
  end
end
