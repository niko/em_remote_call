$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), '../lib')

require 'em_remote_call'
TEST_SOCKET = File.join( File.expand_path(File.dirname(__FILE__)), 'test_socket' )

class ServerClass
  def self.foo(&blk)
    EM.add_timer 1 do # do some work...
      blk.call 42     # then return
    end
  end
end

class ClientClass
  has_em_remote_class 'ServerClass', :socket => TEST_SOCKET
  remote_class_method :foo
end

EM.fork_reactor do
  EM::RemoteCall::Server.start_at TEST_SOCKET
  
  EM.add_timer 2 do
    puts 'stopping server'
    EM.stop
  end
end

sleep 0.1 # wait, so the server is up

EM.fork_reactor do
  ClientClass.foo do |result|
    puts "server returned #{result}"
    EM.stop
  end
end

Process.waitall
