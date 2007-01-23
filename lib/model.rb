module LWT
  module AuthenticationSystem
    module Model
      
      def self.included( base )
        base.extend ClassMethods
      end

      module ClassMethods
        # Setups this model as the one which is use for authentication
        #
        # Valid options:
        # - :password_validation_message - Error message used when the passwords do not match.
        #   Default: "Passwords must match"
        # - :username_validation_message - Error message used when the username is blank.
        #   Default: "Username cannot be blank"
        # - :username_unique_validation_message - Error message used when the username is
        #   already in use. Default: "Username has already been taken"
        # - :use_salt - If true, the hash_password method will be sent a salt along with a
        #   password. The salt will be stored in database column salt. Defaults: false
        def acts_as_login_model options = {}
          include LWT::AuthenticationSystem::Model::InstanceMethods
          extend LWT::AuthenticationSystem::Model::SingletonMethods
          
          lwt_authentication_system_options = {
            :password_validation_message => "Passwords must match",
            :username_validation_message => "Username cannot be blank",
            :username_unique_validation_message => "Username has already been taken",
            :use_salt => false
          }.merge( options )
          
          hash_password do |pwd|
            require 'md5'
            MD5.hexdigest( pwd )
          end
          
          validate_password do |user, password|
            true
          end
          
          belongs_to :group
          validates_presence_of :username,
                    :message => lwt_authentication_system_options[:username_validation_message]
          validates_uniqueness_of :username,
                    :message => lwt_authentication_system_options[:username_unique_validation_message]
          validate :validate_password
        end
      end

      module SingletonMethods
        attr_accessor :current_user, :lwt_authentication_system_options

        # Attempts to find a user by the passed in attributes. The param :password will
        # be removed and will be checked against the password of the user found (if any).
        def login params
          password = params.delete( :password )
          user = self.find :first, :conditions => params, :include => { :group => :privileges }
          return nil unless user

          args = [ password ]
          args << user.salt if self.lwt_authentication_system_options[:use_salt]
          self.hash_password( *args ) == user.password_hash ? user : nil
        end

        # This method does two things:
        # - If given a block, that blocked is stored and used when hashing the users password.
        #   When the block is called, it will be given the password and the salt, if enabled.
        # - Else, the stored block is called, giving passing it all arguments
        def hash_password( *args, &blk )
          if blk
            self.lwt_authentication_system_options[:hash_password] = blk
          else
            self.lwt_authentication_system_options[:hash_password].call *args
          end
        end

        # Takes a block to be used when validating the password. The block
        # will be passed one parameter, the password.
        def validate_password( &blk )
          self.lwt_authentication_system_options[:validate_password] = blk
        end
      end

      module InstanceMethods
        attr_reader :password, :password_confirmation

        # This method determines if this user has any of the passed in privileges.
        # The the arguments are expected to be symbols.
        def has_privilege? *privs
          return false unless group
          group.privileges.each do |priv|
            return true if privs.include? priv.name.to_sym
          end
          false
        end

        # Stores the password for validation, as well as sets the password_hash method for database.
        def password=( pwd )
          return if pwd.empty?
          @password_validation ||= {}
          @password_validation[:password] = pwd
          self.password_hash = if self.class.lwt_authentication_system_options[:use_salt]
            self.class.lwt_authentication_system_options[:hash_password].call( pwd, user.salt )
          else
            self.class.lwt_authentication_system_options[:hash_password].call( pwd )
          end
        end

        # Stores the confirmation password for validation.
        def password_confirmation=( pwd )
          return if pwd.empty?
          @password_validation ||= {}
          @password_validation[:password_confirmation] = pwd
        end

      private
        # Checks to ensure that if the password was changed, the password and password_confirmation are the same.
        def validate_password
          pass = true
          if @password_validation
            pass = self.class.lwt_authentication_system_options[:validate_password].call( self, @password_validation[:password] )
            if @password_validation[:password] != @password_validation[:password_confirmation]
              errors.add :password, self.class.lwt_authentication_system_options[:password_validation_message]
              pass = false
            end
          end
          pass
        end
      end
    end
  end
end
