$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), '../lib')

require 'em_remote_call'
TEST_SOCKET = File.join( File.expand_path(File.dirname(__FILE__)), 'test_socket' )

class CommmonClass
  attr_reader :id
  def initialize(id)
    @id = id
  end
end

class ServerClass < CommmonClass
  is_a_collection
  
  def foo(&blk)
    EM.add_timer 1 do           # do some work...
      blk.call "#{id} says 42"  # then return
    end
  end
end

class ClientClass < CommmonClass
  def initialize(id)
    new_on_server id
    super
  end
  
  has_em_remote_class 'ServerClass', :socket => TEST_SOCKET
  remote_method :new_on_server, :calls => :new, :server_class_method => true#, :debug => true
  remote_method :foo#, :debug => true
end

EM.fork_reactor do
  EM::RemoteCall::Server.start_at TEST_SOCKET
  
  EM.add_timer 3 do
    puts 'stopping server'
    EM.stop
  end
end

sleep 0.1 # wait, so the server is up

EM.fork_reactor do
  c = ClientClass.new 23
  EM.add_timer 1 do
    c.foo do |result|
      puts "server returned '#{result}'"
      EM.stop
    end
  end
end

Process.waitall
