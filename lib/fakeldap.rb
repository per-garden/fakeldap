$:.unshift(File.expand_path('../../vendor/ruby-ldapserver/lib', __FILE__))
require 'ldap/server'

module FakeLDAP
  class Server < LDAP::Server
    def initialize(options={})
      @users = {}
      super(default_options.merge(options))
    end

    def add_user(user, pass)
      @users[user] = pass
    end

    def valid_credentials?(user, pass)
      @users.has_key?(user) && @users[user] == pass
    end

    def find_users(basedn, filter)
      basedn_regex = /#{Regexp.escape(basedn)}$/
      filter_regex = /^#{filter[1]}=#{filter[3]}$/

      @users.keys.select { |dn|
        dn =~ basedn_regex && dn.split(",").grep(filter_regex).any?
      }
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

      @server.find_users(basedn, filter).each do |dn|
        send_SearchResultEntry(dn, {})
      end
    end
  end
end

