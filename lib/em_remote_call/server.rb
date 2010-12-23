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
    @argument ? @instance.__send__(@method, @argument, &callb) : @instance.__send__(@method, &callb)
  end
end

module EM::RemoteCall::Server
  include EM::JsonConnection::Server
  
  def json_parsed(hash)
    remote_call = EM::RemoteCall::Call.new hash[:instance], hash[:method].to_sym, hash[:argument]
    
    ret = remote_call.call do |result|
      send_data({:deferrable_id => hash[:deferrable_id], :success => result})
    end
    
    if ret.is_a? EM::Deferrable
      ret.callback do |result|
        send_data({:deferrable_id => hash[:deferrable_id], :success => result})
      end
      ret.errback do |result|
        send_data({:deferrable_id => hash[:deferrable_id], :error => result})
      end
    end
    
  rescue => e
    puts "#{e}: #{e.message}"
    send_data( { :deferrable_id => hash[:deferrable_id], :error => {:class => e.class.name, :message => e.message} } )
  end
end
