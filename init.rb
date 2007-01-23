dir = File.join( File.dirname( __FILE__ ), 'lib' )

unless( Group rescue nil )
  class ::Group < ActiveRecord::Base
  end
end

unless( Privilege rescue nil )
  class ::Privilege < ActiveRecord::Base
  end
end

unless( GroupPrivilege rescue nil )
  class ::GroupPrivilege < ActiveRecord::Base
  end
end

Group.class_eval do
  has_many :users
  has_many :privileges, :through => :group_privileges
  has_many :group_privileges, :dependent => :destroy

  validates_presence_of :name
end

Privilege.class_eval do
  has_many :groups, :through => :group_privileges
  has_many :group_privileges, :dependent => :destroy
  
  validates_presence_of :name
end

GroupPrivilege.class_eval do
  set_table_name "groups_privileges"
  
  belongs_to :group
  belongs_to :privilege
end

require File.join( dir, 'model' )
require File.join( dir, 'controller' )
require File.join( dir, 'login_controller' )
ActiveRecord::Base.send :include, LWT::AuthenticationSystem::Model
ActionController::Base.send :include, LWT::AuthenticationSystem::Controller
ActionController::Base.send :include, LWT::AuthenticationSystem::LoginController
