$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), '../lib')

require 'em_remote_call'

TEST_SOCKET = File.join( File.expand_path(File.dirname(__FILE__)), 'test_socket' )

class Track
  attr_reader :title, :artist
  
  def initialize(opts)
    @title, @artist = opts[:title], opts[:artist]
    
    puts "new #{self.class}: #{title} - #{artist}"
    super
  end
  
  def id
    "#{title} - #{artist}"
  end
end

class ServerTrack < Track
  is_a_collection
  
  def play(timer=3, &callb)
    puts "Server playing: #{id} (for #{timer} seconds...)"
    
    EM.add_timer timer do
      callb.call "Server finished #{id}"
    end
  end
  def as_hash
    {:title => title, :artist => artist}
  end
  def self.all_as_hash
    all.map{|_| _.as_hash}
  end
end

class ClientTrack < Track
  has_em_remote_class 'ServerTrack', :socket => TEST_SOCKET
  
  def initialize(opts)
    super
    init_track_on_server :title => title, :artist => artist
  end
  
  extend EM::RemoteCall
  remote_method :init_track_on_server, :server_class_method => true, :calls => :new
  remote_method :play
  remote_class_method :all_as_hash
end

EM.fork_reactor do
  EM::RemoteCall::Server.start_at TEST_SOCKET
  
  EM.add_timer(8) do
    puts 'stopping server'
    EM.stop
  end
end

sleep 0.1 # wait, so the server is up

EM.fork_reactor do
  track_one = ClientTrack.new :title => 'Smells like Teen Spirit', :artist => 'Nirvana'
  track_two = ClientTrack.new :title => 'Concrete Schoolyards',    :artist => 'J5'
  
  EM.add_timer 1 do
    f = ClientTrack.all_as_hash
    f.callback{|tracks| puts "All Tracks: #{tracks}"}
    f.errback{|e| puts "error: #{e}"}
  end
  
  EM.add_timer 1 do
    track_one.play(2){|v| puts "client received: #{v}"}
  end
  
  EM.add_timer 2 do
    track_two.play{ puts "client received J5!" }
  end
  
  EM.add_timer 8 do
    puts 'stopping client'
    EM.stop
  end
end

Process.waitall
