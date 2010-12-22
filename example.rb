$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), 'lib')

require 'em_remote_call'

class Track
  attr_reader :title, :artist
  
  def initialize(opts)
    @title, @artist = opts[:title], opts[:artist]
    
    puts "new track: #{title} - #{artist} (#{self.class})"
    super
  end
  
  def id
    "#{title} - #{artist}"
  end
end

class ServerTrack < Track
  is_a_collection
  
  def play(timer=3, &callb)
    puts "playing: #{id} (for #{timer} seconds...)"
    
    EM.add_timer timer do
      callb.call "finished #{id}"
    end
  end
  
  def self.foo(&block)
    p 'foo'
    block.call
  end
end

class ClientTrack < Track
  def initialize(opts)
    super
    init_track_on_server :title => title, :artist => artist
  end
  
  extend EM::RemoteCall
  remote_method :init_track_on_server, :class_name => 'ServerTrack', :calls => :new
  remote_method :play,                 :class_name => 'ServerTrack', :find_by => :id
  
  class << self
    extend EM::RemoteCall
    remote_method :foo, :class_name => 'ServerTrack'
  end
end

socket = File.join( File.expand_path(File.dirname(__FILE__)), 'test_socket' )

EM.fork_reactor do
  EM::RemoteCall::Server.start_at socket
  
  EM.add_timer(8) do
    puts 'stopping server'
    EM.stop
  end
end

sleep 0.1 # wait, so the server is up

EM.fork_reactor do
  ClientTrack.remote_connection = EM::RemoteCall::Client.connect_to socket
  
  track_one = ClientTrack.new :title => 'Smells like Teen Spirit', :artist => 'Nirvana'
  track_two = ClientTrack.new :title => 'Concrete Schoolyards',    :artist => 'J5'
  
  f = ClientTrack.foo
  f.callback{p 'food'}
  f.errback{|e| p e}
  
  EM.add_timer 1 do
    track_one.play(2){|v| puts "finished: #{v}"}
  end
  
  EM.add_timer 2 do
    track_two.play{ puts "finished J5!" }
  end
  
  EM.add_timer(8) do
    puts 'stopping client'
    EM.stop
  end
end

Process.waitall
