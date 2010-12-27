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

TEST_SOCKET = File.join( File.expand_path(File.dirname(__FILE__)), 'test_socket' )

class ServerTrack < Track
  is_a_collection
  
  def initialize(opts={}, &callb)
    callb.call if callb
    super
  end
  
  # takes a block:
  def play(&callb)
    callb.call "finished #{id}"
    "started #{id}"
  end
  
  # raises:
  def raise_hell
    raise 'foobar'
  end
  
  # returns a deferrable:
  def with_deferrable(outcome = 'succeed') # does not take a block
    d = EventMachine::DefaultDeferrable.new
    d.send outcome
    return d
  end
  
  # doesn't take a block, just returns a hash:
  def as_hash
    {:title => title, :artist => artist}
  end
  
  # a class method:
  def self.some_class_meth(&blk)
    blk.call
  end
end

class ClientTrack < Track
  has_em_remote_class 'ServerTrack', :socket => TEST_SOCKET
  
  remote_method :init_track_on_server, :calls => :new, :server_class_method => true
  remote_method :play
  remote_method :raise_hell
  remote_method :with_deferrable
  remote_method :as_hash
  remote_class_method :some_class_meth
end

class EMController
  extend EM::RemoteCall
  remote_method :stop, :class_name => 'EM', :calls => :stop
end

def test_on_client
  server_pid = EM.fork_reactor do
    EM::RemoteCall::Server.start_at TEST_SOCKET
  end
  sleep 0.1
  EM.run do
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
        ClientTrack.new.init_track_on_server{callb.foo}
      end
    end
  end
  describe "class method callbacks too" do
    it "should work twice" do
      test_on_client do
        callb = mock(:callb)
        callb.should_receive(:foo).twice
        ClientTrack.new.init_track_on_server{callb.foo}
        ClientTrack.new.init_track_on_server{callb.foo}
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
  describe "without block or deferrable" do
    it "should return just the return value" do
      test_on_client do
        callb = mock(:callb)
        properties = {:artist => 'a', :title => 't'}
        callb.should_receive(:foo).with(properties)
        c = ClientTrack.new properties
        c.init_track_on_server properties do
          c.as_hash{|r| callb.foo(r)}
        end
      end
    end
  end
  describe "with a deferrable" do
    describe "on success" do
      describe "with a block" do
        it "should use the block as callback" do
          test_on_client do
            callb = mock(:callb)
            callb.should_receive(:foo)
            c = ClientTrack.new
            c.init_track_on_server
            c.with_deferrable(:succeed){ callb.foo }
          end
        end
      end
      describe "with callback" do
        it "should use callback" do
          test_on_client do
            callb = mock(:callb)
            callb.should_receive(:foo)
            c = ClientTrack.new
            c.init_track_on_server
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
          callb.should_receive(:foo)
          c = ClientTrack.new
          c.init_track_on_server
          play_call = c.with_deferrable(:fail)
          play_call.errback{ callb.foo }
        end
      end
    end
  end
end
