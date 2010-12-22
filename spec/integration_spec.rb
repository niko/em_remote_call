$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), '../lib')

require 'em_remote_call'

class Track
  attr_reader :title, :artist
  
  def initialize(opts)
    @title, @artist = opts[:title], opts[:artist]
    super
  end
  
  def id
    "#{title} - #{artist}"
  end
end

class ServerTrack < Track
  is_a_collection
  
  def initialize(opts, &callb)
    callb.call
    super
  end
  
  def play(&callb)
    callb.call "finished #{id}"
    "started #{id}"
  end
end

class ClientTrack < Track
  extend EM::RemoteCall
  remote_method :init_track_on_server, :class_name => 'ServerTrack', :calls => :new
  remote_method :play,                 :class_name => 'ServerTrack', :find_by => :id
end

class EMController
  extend EM::RemoteCall
  remote_method :stop, :class_name => 'EM', :calls => :stop
end

def test_on_client
  socket = File.join( File.expand_path(File.dirname(__FILE__)), 'test_socket' )
  
  server_pid = EM.fork_reactor do
    EM::RemoteCall::Server.start_at socket
  end
  sleep 0.1
  EM.run do
    ClientTrack.remote_connection = EM::RemoteCall::Client.connect_to socket
    yield
    EM.add_timer 0.1 do
      Process.kill 'HUP', server_pid
      EM.stop
    end
  end
end

describe EM::RemoteCall do
  describe "class method callbacks" do
    it "should be called" do
      test_on_client do
        callb = mock(:callb)
        callb.should_receive(:foo)
        ClientTrack.new({}).init_track_on_server({}){callb.foo}
      end
    end
  end
  describe "instance method callbacks" do
    it "should be called" do
      test_on_client do
        callb = mock(:callb)
        callb.should_receive(:foo).with('finished a - b')
        c = ClientTrack.new(:title => 'a', :artist => 'b')
        c.init_track_on_server(:title => 'a', :artist => 'b')
        c.play{|a| callb.foo a}
      end
    end
  end
  describe "return values" do
    describe "with two procs" do
      it "should be passed to the first proc" do
        test_on_client do
          callb = mock(:callb)
          callb.should_receive(:bar).with('started a - b')
          c = ClientTrack.new(:title => 'a', :artist => 'b')
          c.init_track_on_server(:title => 'a', :artist => 'b')
          c.play proc{|a| callb.bar a}, proc{}
        end
      end
    end
    describe "with a proc and a block" do
      it "should be passed to the proc" do
        test_on_client do
          callb = mock(:callb)
          callb.should_receive(:bar).with('started a - b')
          c = ClientTrack.new(:title => 'a', :artist => 'b')
          c.init_track_on_server(:title => 'a', :artist => 'b')
          c.play proc{|a| callb.bar a} {}
        end
      end
    end
  end
end

