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
  has_em_remote_class 'ServerClass', :socket => TEST_SOCKET
  remote_method :foo
end

EM.fork_reactor do
  ServerClass.new 23
  EM::RemoteCall::Server.start_at TEST_SOCKET
  
  EM.add_timer 2 do
    puts 'stopping server'
    EM.stop
  end
end

sleep 0.1 # wait, so the server is up

EM.fork_reactor do
  c = ClientClass.new 23
  c.foo do |result|
    puts "server returned '#{result}'"
    EM.stop
  end
end

Process.waitall
