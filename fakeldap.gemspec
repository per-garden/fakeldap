# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'fakeldap/version'

Gem::Specification.new do |s|
  s.name        = "fakeldap"
  s.version     = FakeLDAP::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Aanand Prasad","Per Gärden"]
  s.email       = ["aanand.prasad@gmail.com","per.garden@avalonenterprise.com"]
  s.homepage    = "http://github.com/per-garden/fakeldap"
  s.summary     = "A fake LDAP server for use in testing"
  s.description = "Supports: Admin user bind operation, Regular user authentication, Create (add), read (search), update (modify), and delete operations for users and groups"

  s.add_dependency 'net-ldap', '~> 0'
  s.add_dependency 'ruby-ldapserver', '~> 0.5.0'
  s.add_development_dependency 'rspec', '~> 0'

  s.files        = Dir.glob("{lib,vendor}/**/*") + %w(LICENSE README.md)
  s.require_path = 'lib'
end

