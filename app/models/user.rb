class User < ActiveRecord::Base
        has_many :accounts,    :include => :items
        has_many :items,       :through => :accounts, :source => :items, :order => 'items.time DESC'
	has_many :valid_items, :through => :accounts, :source => :items, :order => 'items.time DESC', :conditions => [ 'items.complete = ?', true ]

        validates_presence_of     :name 
        validates_uniqueness_of   :name
        validates_confirmation_of :password
	
        attr_accessor :password_confirmation 
        
        def validate 
          errors.add_to_base("Missing password") if hashed_password.blank? 
        end 
        
        def self.authenticate(name, password) 
          user = self.find_by_name(name)
          if user 
            expected_password = encrypted_password(password, user.salt) 
            if user.hashed_password != expected_password 
              user = nil 
            end 
          end 
          user 
        end 
        
        # 'password' is a virtual attribute 
        def password 
          @password 
        end 
        
        def password=(pwd) 
          @password = pwd 
          return if pwd.blank? 
          create_new_salt 
          self.hashed_password = User.encrypted_password(self.password, self.salt) 
        end 
        
        def after_destroy 
          if User.count.zero? 
            raise "Can't delete last user" 
          end 
        end 
        
        private 
        def create_new_salt 
          self.salt = self.object_id.to_s + rand.to_s 
        end
        
        def self.encrypted_password(password, salt) 
          string_to_hash = password + "wibble" + salt 
          Digest::SHA1.hexdigest(string_to_hash) 
        end 
end
