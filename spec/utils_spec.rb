$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), '../lib')

require 'em_remote_call'

module A; end
module A::B; end
module A::B::C; end

describe EM::RemoteCall::Utils do
  describe "constants" do
    it "should turn a String into a Constant" do
      EM::RemoteCall::Utils.constantize('A').should == A
    end
  end
  describe "nested modules" do
    it "should turn a String into a Constant" do
      EM::RemoteCall::Utils.constantize('A::B').should == A::B
      EM::RemoteCall::Utils.constantize('A::B::C').should == A::B::C
    end
  end
  describe "non existing constants" do
    it "should return false (this is just how we need it)" do
      EM::RemoteCall::Utils.constantize('D').should == false
    end
  end
end

