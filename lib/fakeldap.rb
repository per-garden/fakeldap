require 'ldap/server'

module FakeLDAP
  class Server < LDAP::Server

    def initialize(options={})
      @users = {}
      @groups = {}
      super(default_options.merge(options))
    end

    def add_user(user, pass, mail = nil)
      @users[user] = [pass, mail]
    end

    def add_to_group(dn, member)
      # Member array keyed on dn
      @groups[dn] = [] unless @groups[dn]
      @groups[dn] << member unless @groups[dn].include?(member)
    end

    def modify_entry(dn, key, action, value)
      e = @users[dn]
      # Didn't find user => maybe it's a group
      e = @groups[dn] unless e && e[0]
      if e
        # FIXME: Annoying! Proper hash, not just array. Or hide in private method.
        case key
          when 'password'
            e[0] = value
          when 'mail'
            e[1] = value
          when 'member'
            case action
              when :add
                e << value unless e.include?(value)
              when :delete
                e.delete(value)
            end
        end
      end
    end

    def delete_entry(dn)
      @users.delete(dn[0]) || @groups.delete(dn[0])
    end

    def valid_credentials?(user, pass)
      @users.has_key?(user) && @users[user][0] == pass
    end

    def find_users(basedn, filter)
      result = []
      basedn_regex = /#{Regexp.escape(basedn)}$/
      filter_regex = /^#{filter[1]}=#{filter[3]}$/

      case filter[1]
      when 'objectClass'
        result = @users.keys if filter[3] == 'inetOrgPerson'
      when 'cn'
        @users.keys.select { |dn|
          dn =~ basedn_regex && dn.split(",").grep(filter_regex).any?
        }
      when 'mail'
        @users.keys.each do |dn|
          # Keyed on full cn=...,dn...
          if @users[dn][1] == filter[3]
            result << dn
          end
        end
        result
      else
        result
      end
    end

    def user_attributes(dn)
      # Create attribute hash here
      if @users[dn]
        {'cn' => ["#{dn}"], 'regular_password' => ["#{ @users[dn][0]}"], 'mail' => ["#{ @users[dn][1]}"], 'disclaimer' => 'Test data - not for operational use'}
      else
        {}
      end
    end

    def find_groups(basedn, filter)
      # Expected result - array of strings
      result = []
      group = "#{basedn}"
      case filter[1]
      when 'objectClass'
        result = @groups.keys if filter[3] == 'groupOfNames'
      when 'cn'
        result = @groups[group] || []
      when 'member'
        result = [filter[3]] if @groups[group] && @groups[group].include?(filter[3])
        result = @groups.keys if filter[3] == 'groupOfNames'
      end
      result
    end

    def group_attributes(cn)
      if @groups[cn]
        { 'cn' => ["#{cn}"], 'member' => @groups["#{cn}"] }
      else
        {}
      end
    end

    def default_options
      {
        :operation_class => ::FakeLDAP::Operation,
        :operation_args  => [self]
      }
    end

  end

  class Operation < LDAP::Server::Operation
    def initialize(connection, messageID, server)
      super(connection, messageID)
      @server = server
    end

    def simple_bind(version, dn, password)
      unless dn
        raise LDAP::ResultError::InappropriateAuthentication,
          "This server does not support anonymous bind"
      end

      unless @server.valid_credentials?(dn, password)
        raise LDAP::ResultError::InvalidCredentials,
          "Invalid credentials"
      end
    end

    def search(basedn, scope, deref, filter, attrs=nil)
      unless filter.first == :eq
        raise LDAP::ResultError::UnwillingToPerform,
          "Only equality matches are supported"
      end

      users = @server.find_users(basedn, filter)
      groups = @server.find_groups(basedn, filter)
      if users
        users.each do |dn|
          attributes = @server.user_attributes("#{dn}") || {}
          send_SearchResultEntry(dn, attributes)
        end
      end
      if groups
        groups.each do |dn|
          attributes = @server.group_attributes("#{dn}") || {}
          send_SearchResultEntry(dn, attributes)
        end
      end
    end

    def add(dn, attr)
      # Barring rocket-science. Always, only one single add
      case attr['objectclass'][0]
      when 'inetOrgPerson'
        @server.add_user(dn, attr[:userPassword], attr[:mail])
      when 'groupofnames'
        @server.add_to_group(dn, attr['member'][0])
      end
    end

    def modify(*args)
      # A hash able to contain an array of arrays... LDAP nuttiness!
      dn = args[0]
      key = args[1].keys.first
      action = args[1][key][0]
      value = args[1][key][1]
      # Barring rocket-science. Always, only one single action.
      @server.modify_entry(dn, key, action, value)
    end

    # Some silly clients call delete del...
    def del(*args)
      delete(args)
    end

    def delete(*args)
      dn = args[0]
      @server.delete_entry(dn)
    end
  end
end
