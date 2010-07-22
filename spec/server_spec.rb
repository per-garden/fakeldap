require 'spec_helper'

describe FakeLDAP::Server do
  before :all do
    @port = rand(1000) + 1000

    @server = FakeLDAP::Server.new(:port => @port)
    @server.run_tcpserver

    @client = Net::LDAP.new
    @client.port = @port
  end

  after :all do
    @server.stop
  end

  it "responds to bind requests" do
    @client.auth("user", "pass")
    @client.bind
  end
end

