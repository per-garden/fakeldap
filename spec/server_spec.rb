require 'spec_helper'

describe FakeLDAP::Server do
  before :all do
    @port = 1389

    @domain                 = "dc=example,dc=com"
    @toplevel_user_dn       = "cn=toplevel_user,cn=TOPLEVEL,#{@domain}"
    @toplevel_user_password = "toplevel_password"

    @regular_user_cn        = "regular_user"
    @regular_user_dn        = "cn=#{@regular_user_cn},ou=USERS,#{@domain}"
    @regular_user_password  = "regular_password"
    @regular_user_email     = "#{@regular_user_cn}@example.com"
    @addable_user_cn        = "addable_user"
    @addable_user_dn        = "cn=#{@addable_user_cn},ou=USERS,#{@domain}"
    @addable_user_password  = "addable_password"
    @addable_user_email     = "#{@addable_user_cn}@example.com"

    @server = FakeLDAP::Server.new(:port => @port)
    @server.run_tcpserver
    @server.add_user(@toplevel_user_dn, @toplevel_user_password)
    @server.add_user(@regular_user_dn, @regular_user_password, @regular_user_email)
  end

  after :all do
    @server.stop
  end

  describe "when receiving a top-level bind request it" do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
    end

    it "responds with Inappropriate Authentication to anonymous bind requests" do
      @client.bind.should be_falsey
      @client.get_operation_result.code.should == 48
    end

    it "responds with Invalid Credentials if the password is incorrect" do
      @client.auth(@toplevel_user_dn, "wrong_password")
      @client.bind.should be_falsey
      @client.get_operation_result.code.should == 49
    end

    it "responds with Invalid Credentials if the user does not exist" do
      @client.auth("cn=wrong_user,cn=TOPLEVEL,#{@domain}", @toplevel_user_password)
      @client.bind.should be_falsey
      @client.get_operation_result.code.should == 49
    end

    it "responds affirmatively if the username and password are correct" do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      @client.bind.should be_truthy
    end
  end

  describe "when recieving a regular-level bind request it" do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
    end

    it "responds with Unwilling to Perform if the search is not an equality search" do
      @client.bind_as(base: "#{@domain}", filter: "(cn=#{@regular_user_cn}*)", password: @regular_user_password).should be_falsey
      @client.get_operation_result.code.should == 53

      @client.bind_as(base: "#{@domain}", filter: "(cn=*#{@regular_user_cn})", password: @regular_user_password).should be_falsey
      @client.get_operation_result.code.should == 53
    end

    it "fails if the search is not on the right attribute" do
      @client.bind_as(base: "#{@domain}", filter: "(foo=#{@regular_user_cn})", password: @regular_user_password).should be_falsey
      @client.get_operation_result.code.should == 0
    end

    it "fails if the user does not exist" do
      @client.bind_as(base: "#{@domain}", filter: "(cn=wrong_user)", password: @regular_user_password).should be_falsey
      @client.get_operation_result.code.should == 0
    end

    it "fails if the username and password are correct but the base is incorrect" do
      @client.bind_as(base: "dc=wrongdomain,dc=com", filter: "(cn=#{@regular_user_cn})", password: @regular_user_password).should be_falsey
      @client.get_operation_result.code.should == 0
    end

    it "responds with Invalid Credentials if the password is incorrect" do
      @client.bind_as(base: "#{@domain}", filter: "(cn=#{@regular_user_cn})", password: "wrong_password").should be_falsey
      @client.get_operation_result.code.should == 49
    end

    it "responds affirmatively if the username and password are correct" do
      @client.bind_as(base: "#{@domain}", filter: "(cn=#{@regular_user_cn})", password: @regular_user_password).should be_truthy
    end
  end

  describe "when searching for user it" do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
    end

    it 'finds existing user based on cn' do
      expect(@client.search(base: "#{@domain}", filter: "(cn=#{@regular_user_cn})")).not_to be_empty
    end

    it 'does not find non-existing user based on cn' do
      expect(@client.search(base: "#{@domain}", filter: "(cn=not_#{@regular_user_cn})")).to be_empty
    end

    it 'finds existing user based on mail' do
      expect(@client.search(base: "#{@domain}", filter: "(mail=#{@regular_user_email})")).not_to be_empty
    end

    it 'does not find non-existing user based on mail' do
      result = @client.search(base: "#{@domain}", filter: "(mail=not_#{@regular_user_email})")
      expect(@client.search(base: "#{@domain}", filter: "(mail=not_#{@regular_user_email})")).to be_empty
    end
  end

  describe "when managing users it" do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
    end

    it 'adds user' do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      oc = 'inetOrgPerson'
      dn = "#{@addable_user_dn}"
      attr = {cn: @addable_user_cn, objectclass: oc, mail: @addable_user_email, sn: @addable_user_cn, userPassword: @addable_user_password}
      @client.add(dn: dn, attributes: attr)
      expect(@client.search(base: "#{@domain}", filter: "(cn=#{@addable_user_cn})")).not_to be_empty
    end

    it 'modifies user' do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      dn = "#{@regular_user_dn}"
      new_email = "new_#{@regular_user_email}"
      ops = [[:replace, :mail, [new_email]]]
      @client.modify(dn: dn, operations: ops)
      expect(@client.search(base: "#{@domain}", filter: "(mail=#{new_email})")).not_to be_empty
    end

    it 'deletes user' do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      dn = "#{@regular_user_dn}"
      @client.delete(dn: dn)
      expect(@client.search(base: "#{@domain}", filter: "(cn=#{@regular_user_cn})")).to be_empty
    end
  end

  describe 'when managing groups it' do
    before :each do
      @client = Net::LDAP.new
      @client.port = @port
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
    end

    before do
      @group_ou = "ou=GROUPS,#{@domain}"
      @regular_group_cn = "regular_group"
      @addable_group_cn = "addable_group"
      @server.add_to_group("cn=#{@regular_group_cn},ou=GROUPS,#{@domain}", @regular_user_dn)
      @server.add_user(@addable_user_dn, @addable_user_password, @addable_user_email)
      @deletable_user_cn        = "deletable_user"
      @deletable_user_dn        = "cn=#{@deletable_user_cn},ou=USERS,#{@domain}"
      @deletable_user_password  = "deletable_password"
      @deletable_user_email  = "#{@deletable_user_cn}@example.com"
      @server.add_to_group("cn=#{@regular_group_cn},ou=GROUPS,#{@domain}", @deletable_user_dn)
    end  

    it 'adds a group' do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      oc = 'groupofnames'
      dn = "cn=#{@addable_group_cn},#{@group_ou}"
      attr = {cn: @addable_group_cn, objectclass: oc, member: @regular_user_dn}
      @client.add(dn: dn, attributes: attr)
      base = "cn=#{@addable_group_cn},ou=GROUPS,#{@domain}"
      expect(@client.search(base: base, filter: "(cn=#{@addable_group_cn})")).not_to be_empty
    end

    it 'adds a user to a group' do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      dn = "cn=#{@regular_group_cn},#{@group_ou}"
      member = "#{@addable_user_dn}"
      ops = [[:add, :member, [member]]]
      @client.modify(dn: dn, operations: ops)
      base = "cn=#{@regular_group_cn},ou=GROUPS,#{@domain}"
      expect(@client.search(base: base, filter: "(member=#{member})")).not_to be_empty
    end

    it 'deletes a group' do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      dn = "cn=#{@regular_group_cn},#{@group_ou}"
      @client.delete(dn: dn)
      expect(@client.search(base: "ou=GROUPS,#{@domain}", filter: "(cn=#{@regular_group_cn})")).to be_empty
    end

    it 'deletes a user from a group' do
      @client.auth(@toplevel_user_dn, @toplevel_user_password)
      dn = "cn=#{@regular_group_cn},#{@group_ou}"
      member = "#{@deletable_user_dn}"
      ops = [[:delete, :member, [member]]]
      @client.modify(dn: dn, operations: ops)
      base = "cn=#{@regular_group_cn},ou=GROUPS,#{@domain}"
      expect(@client.search(base: base, filter: "(member=#{member})")).to be_empty
    end
  end

end
