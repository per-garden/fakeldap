$:.unshift(File.expand_path('../../vendor/ruby-ldapserver/lib', __FILE__))
require 'ldap/server'

module FakeLDAP
  class Server < LDAP::Server
    def initialize(options={})
      super(default_options.merge(options))
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
      puts "simple_bind: #{version}, #{dn}, #{password}"
      super(version, dn, password)
    end

    def search(basedn, scope, deref, filter);               raise "not implemented"; end
    def modify(dn, modification);                           raise "not implemented"; end
    def add(dn, av);                                        raise "not implemented"; end
    def del(dn);                                            raise "not implemented"; end
    def modifydn(entry, newrdn, deleteoldrdn, newSuperior); raise "not implemented"; end
    def compare(entry, attr, val);                          raise "not implemented"; end
  end
end

