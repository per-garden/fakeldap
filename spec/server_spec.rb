require 'spec_helper'

describe FakeLDAP::Server do
  before :all do
    @port = 1389

    @toplevel_user_dn       = "cn=toplevel_user,cn=TOPLEVEL,dc=example,dc=com"
    @toplevel_user_password = "toplevel_password"

    @regular_user_cn        = "regular_user"
    @regular_user_dn        = "cn=#{@regular_user_cn},ou=USERS,dc=example,dc=com"
    @regular_user_password  = "regular_password"

    @server = FakeLDAP::Server.new(:port => @port)
    @server.run_tcpserver
    @server.add_user(@toplevel_user_dn, @toplevel_user_password)
    @server.add_user(@regular_user_dn, @regular_user_password)
  end

  after :all do
    @server.stop
  end

  describe "when receiving a top-level bind request" do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
    end

    it "responds with Inappropriate Authentication to anonymous bind requests" do
      @client.bind.should be_false
      @client.get_operation_result.code.should == 48
    end

    it "responds with Invalid Credentials if the password is incorrect" do
      @client.auth(@toplevel_user_dn, "wrong_password")
      @client.bind.should be_false
      @client.get_operation_result.code.should == 49
    end

    it "responds with Invalid Credentials if the user does not exist" do
      @client.auth("cn=wrong_user,cn=TOPLEVEL,dc=example,dc=com", @toplevel_user_password)
      @client.bind.should be_false
      @client.get_operation_result.code.should == 49
    end

    it "responds affirmatively if the username and password are correct" do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      @client.bind.should be_true
    end
  end

  describe "when recieving a regular-level bind request" do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
    end

    it "responds with Unwilling to Perform if the search is not an equality search" do
      @client.bind_as(base: "dc=example,dc=com", filter: "(cn=#{@regular_user_cn}*)", password: @regular_user_password).should be_false
      @client.get_operation_result.code.should == 53

      @client.bind_as(base: "dc=example,dc=com", filter: "(cn=*#{@regular_user_cn})", password: @regular_user_password).should be_false
      @client.get_operation_result.code.should == 53
    end

    it "fails if the search is not on the right attribute" do
      @client.bind_as(base: "dc=example,dc=com", filter: "(foo=#{@regular_user_cn})", password: @regular_user_password).should be_false
      @client.get_operation_result.code.should == 0
    end

    it "fails if the user does not exist" do
      @client.bind_as(base: "dc=example,dc=com", filter: "(cn=wrong_user)", password: @regular_user_password).should be_false
      @client.get_operation_result.code.should == 0
    end

    it "fails if the username and password are correct but the base is incorrect" do
      @client.bind_as(base: "dc=wrongdomain,dc=com", filter: "(cn=#{@regular_user_cn})", password: @regular_user_password).should be_false
      @client.get_operation_result.code.should == 0
    end

    it "responds with Invalid Credentials if the password is incorrect" do
      @client.bind_as(base: "dc=example,dc=com", filter: "(cn=#{@regular_user_cn})", password: "wrong_password").should be_false
      @client.get_operation_result.code.should == 49
    end

    it "responds affirmatively if the username and password are correct" do
      @client.bind_as(base: "dc=example,dc=com", filter: "(cn=#{@regular_user_cn})", password: @regular_user_password).should be_true
    end
  end
end

