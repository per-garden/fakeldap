require 'spec_helper'

describe FakeLDAP::Server do
  before :all do
    @port = 1389

    @server = FakeLDAP::Server.new(:port => @port)
    @server.run_tcpserver
    @server.add_user("user", "pass")
  end

  after :all do
    @server.stop
  end

  describe "when receiving a bind request" do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
    end

    it "responds with Inappropriate Authentication to anonymous bind requests" do
      @client.bind.should be_false
      @client.get_operation_result.code.should == 48
    end

    it "responds with Invalid Credentials if the password is incorrect" do
      @client.auth("user", "wrongpass")
      @client.bind.should be_false
      @client.get_operation_result.code.should == 49
    end

    it "responds with Invalid Credentials if the user does not exist" do
      @client.auth("wronguser", "pass")
      @client.bind.should be_false
      @client.get_operation_result.code.should == 49
    end

    it "responds affirmatively if the username and password are correct" do
      @client.auth("user", "pass")
      @client.bind.should be_true
    end
  end
end

