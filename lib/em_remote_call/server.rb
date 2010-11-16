module EM::RemoteCall; end

class EM::RemoteCall::Call
  def initialize(instance_opts, method, argument)
    klass = instance_opts[:class] or return false
    
    @method, @argument = method, argument
    
    if indentifier = instance_opts[:id]
      klass = Object.const_defined?(klass) && Object.const_get(klass) or return false
      @instance = klass.find(indentifier)
    else
      @instance = Object.const_defined?(klass) && Object.const_get(klass) or return false
    end
    
  end
  
  def valid?
    @instance && @method && @instance.respond_to?(@method)
  end
  
  def call(&callb)
    unless valid?
      puts "invalid remote call: :instance => #{@instance}, :method => #{@method}, :argument => #{@argument}"
      return false
    end
    
    if @argument
      @instance.__send__ @method, @argument, &callb
    else
      @instance.__send__ @method, &callb
    end
  end
end

module EM::RemoteCall::Server
  include EM::JsonConnection::Server
  
  def json_parsed(hash)
    remote_call = EM::RemoteCall::Call.new hash[:instance], hash[:method].to_sym, hash[:argument]
    return_value = remote_call.call do |blk_value|
      send_data({:callback_id => hash[:callback_id], :argument => blk_value}) if hash[:callback_id]
    end
    send_data({:callback_id => hash[:return_block_id], :argument => return_value}) if hash[:return_block_id]
    
  end
end
