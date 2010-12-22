module EM::RemoteCall; end

class EM::RemoteCall::Call
  class Error < StandardError; end
  class NoInstanceError         < Error ; end
  class NoMethodGivenError      < Error; end
  class NoMethodOfInstanceError < Error; end
  
  def initialize(instance_opts, method, argument)
    @argument = argument
    @method   = method                       or raise NoMethodError.new method
    @instance = find_instance(instance_opts) or raise NoInstanceError.new instance_opts
    @instance.respond_to?(@method)           or raise NoMethodOfInstanceError.new "#{@instance}##{method}"
  end
  
  def find_instance(args)
    if args[:id]
      klass = EM::RemoteCall::Utils.constantize(args[:class])      or return false
      @instance = klass.find(args[:id])                            or return false
    else
      @instance = EM::RemoteCall::Utils.constantize(args[:class])  or return false
    end
  end
  
  def call(&callb)
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
    
    remote_call.call do |blk_value|
      send_data({:deferrable_id => hash[:deferrable_id], :success => blk_value})
    end
    
  rescue => e
    puts "#{e}: #{e.message}"
    send_data( { :deferrable_id => hash[:deferrable_id], :error => {:class => e.class.name, :message => e.message} } )
  end
end
