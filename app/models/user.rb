class User < ActiveRecord::Base
        has_many :accounts,   :include => :items
	
        has_many :items,      :through => :accounts, :source => :items, :order => 'items.time DESC'  #, :extend => FindByTagAccountDate
	has_many :valid_items,:through => :accounts, :source => :items, :order => 'items.time DESC', :conditions => ['items.complete = ?',true]

        validates_presence_of     :name 
        validates_uniqueness_of   :name
        validates_confirmation_of :password
	
        attr_accessor :password_confirmation 
	
	delegate *Tag.types.push( :tags, :to => :valid_items )
        
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
	
	#first Idee how to access tags throuh custom find items:
	#def self.set_condition( assoc, cond = nil)
	#   opt = reflect_on_association(assoc).options
	#   old_cond = opt[:conditions]
	#   opt[:conditions] = self.sanitize_conditions( cond )
	#   return old_cond
	#end
	
	#def items_find( cond = nil )
	#  old_cond = User.set_condition(:_items, cond)	
	#  reload unless old_cond == cond ##force reload!
        #  _items #( reload )
	#end
	
	##################################################################
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

#module FindByTagAccountDate
#   def items2( options = {} )
#	#options.assert_valid_keys :tag, :account_id
#	opt = {}
#        opt[:joins] = ' '
#	opt[:joins] << "LEFT OUTER JOIN taggings ON taggings.item_id = items.id " if options[:tag]
#        opt[:joins] << "LEFT OUTER JOIN tags ON taggings.tag_id = tags.id " if options[:tag]
#     
#	opt[:group] = 'items.id' if options[:tag]
#     
#        cond = ["1"]
#        #cond << sanitize_sql( ['tags.name=?', options.delete(:tag) ] ) if options[:tag]
#	cond << "tags.name='#{options.delete(:tag)}'" if options[:tag]
#        #cond << 'items.account_id=?', options.delete(:account_id) ] ) if options[:account_id] 
#        #cond << sanitize_sql( ['items.time=?', ]
#        opt[:conditions] = cond.join( ' AND ' )
#	find( :all, opt )
#   end
#   
#   def tags( options = {} )
#	    scope = scope(:find)
#	    cond = ["1"]
#            cond << sanitize_sql(scope.delete(:conditions)) if scope && scope[:conditions]
#            cond << sanitize_sql(options.delete(:conditions)) unless options[:conditions].nil?
#	    cond << sanitize_sql( [ 'tags.type = ?', options.delete(:type) ] ) unless options[:type].nil?
#  
#	    join = []
#	    join << scope.delete(:joins) if scope && scope[:joins]
#	    join << "LEFT OUTER JOIN taggings ON taggings.item_id = items.id"
#	    join << "LEFT OUTER JOIN tags ON taggings.tag_id = tags.id"
#	    
#	    Tag.find( :all,
#	              :from => 'items',
#	              :select => 'tags.*, COUNT(tags.id) count',
#	              :joins => join.join( ' ' ),
#		      :conditions => cond.join( ' AND ' ),		 
#	              :group => "taggings.tag_id" )
#  end
#end
