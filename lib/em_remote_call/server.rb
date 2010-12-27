module EM::RemoteCall; end

class EM::RemoteCall::Call
  class Error < StandardError; end
  class NoInstanceError         < Error; end
  class NoMethodGivenError      < Error; end
  class NoMethodOfInstanceError < Error; end
  
  def initialize(instance_opts, method, arguments)
    @arguments = arguments
    @method    = method                       or raise NoMethodError.new method
    @instance  = find_instance(instance_opts) or raise NoInstanceError.new instance_opts
    @instance.respond_to?(@method)            or raise NoMethodOfInstanceError.new "#{@instance}##{method}"
  end
  
  def find_instance(args)
    if args[:id]
      klass = EM::RemoteCall::Utils.constantize(args[:class])      or return false
      @instance = klass.find(args[:id])                            or return false
    else
      @instance = EM::RemoteCall::Utils.constantize(args[:class])  or return false
    end
  end
  
  def takes_block?
    method = @instance.method(@method)
    return unless method.respond_to?(:parameters)
    params = method.parameters
    params.last && params.last.first == :block
  end
  
  def call(&callb)
    @arguments.empty? ? @instance.__send__(@method, &callb) : @instance.__send__(@method, *@arguments, &callb)
  end
end

module EM::RemoteCall::Server
  include EM::JsonConnection::Server
  
  def json_parsed(hash)
    remote_call = EM::RemoteCall::Call.new hash[:instance], hash[:method].to_sym, hash[:arguments]
    puts "On Server: #{remote_call}: #{hash}" if hash[:debug]
    
    if remote_call.takes_block?
      remote_call.call{ |result| send_data :deferrable_id => hash[:deferrable_id], :method_type => :block, :success => result }
      return
    end
    
    ret = remote_call.call
    if ret.is_a? EM::Deferrable
      ret.callback{ |result| send_data :deferrable_id => hash[:deferrable_id], :debug => hash[:debug], :method_type => :deferrable, :success => result }
      ret.errback { |result| send_data :deferrable_id => hash[:deferrable_id], :debug => hash[:debug], :method_type => :deferrable, :error => result }
    else
      send_data :deferrable_id => hash[:deferrable_id], :success => ret, :method_type => :returned, :debug => hash[:debug]
    end
    
  rescue => e
    puts "#{e}: #{e.message}"
    send_data :deferrable_id => hash[:deferrable_id], :error => {:class => e.class.name, :message => e.message}, :method_type => :rescue, :debug => hash[:debug]
  end
end
