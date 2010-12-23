$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), '../lib')

require 'em_remote_call'

class Track
  attr_reader :title, :artist
  
  def initialize(opts={})
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
  def raise_hell
    raise 'foobar'
  end
  def with_deferrable(outcome = 'succeed') # does not take a block
    d = EventMachine::DefaultDeferrable.new
    d.send outcome
    return d
  end
  
  def self.some_class_meth
    yield
  end
end

class ClientTrack < Track
  extend EM::RemoteCall
  remote_method :init_track_on_server, :class_name => 'ServerTrack', :calls => :new
  remote_method :play,                 :class_name => 'ServerTrack', :find_by => :id
  remote_method :raise_hell,           :class_name => 'ServerTrack', :find_by => :id
  remote_method :with_deferrable,      :class_name => 'ServerTrack', :find_by => :id
  
  class << self
    extend EM::RemoteCall
    remote_method :some_class_meth, :class_name => 'ServerTrack'
  end
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
        ClientTrack.new.init_track_on_server({}){callb.foo}
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
  describe "errbacks" do
    it "should take an errback method" do
      test_on_client do
        callb = mock(:callb)
        callb.should_receive(:foo).with({:class=>"RuntimeError", :message=>"foobar"})
        c = ClientTrack.new(:title => 'a', :artist => 'b')
        c.init_track_on_server(:title => 'a', :artist => 'b')
        play_call = c.raise_hell
        play_call.errback{|a| callb.foo a}
      end
    end
  end
  describe "client side class method" do
    it "should work :)" do
      test_on_client do
        callb = mock(:callb)
        callb.should_receive(:foo)
        ClientTrack.some_class_meth{callb.foo}
      end
    end
  end
  describe "with a deferrable" do
    describe "on success" do
      describe "with a block" do
        it "should use the block as callback" do
          test_on_client do
            callb = mock(:callb)
            callb.should_receive(:foo).with()
            c = ClientTrack.new
            c.init_track_on_server({})
            c.with_deferrable(:succeed){ callb.foo }
          end
        end
      end
      describe "with callback" do
        it "should use callback" do
          test_on_client do
            callb = mock(:callb)
            callb.should_receive(:foo).with()
            c = ClientTrack.new
            c.init_track_on_server({})
            play_call = c.with_deferrable(:succeed)
            play_call.callback{ callb.foo }
          end
        end
      end
    end
    describe "on error" do
      it "should use errback" do
        test_on_client do
          callb = mock(:callb)
          callb.should_receive(:foo).with()
          c = ClientTrack.new
          c.init_track_on_server({})
          play_call = c.with_deferrable(:fail)
          play_call.errback{ callb.foo }
        end
      end
    end
  end
end
