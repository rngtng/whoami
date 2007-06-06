####################
#
# $LastChangedDate$
# $Rev$
# by $Author$ 

require 'tag'
require 'digest/sha1'

class User < ActiveRecord::Base
   has_many :accounts,   :include => :items

   has_many :items,       :through => :accounts, :source => :items, :order => 'items.time DESC'  #, :extend => FindByTagAccountDate
   has_many :valid_items, :through => :accounts, :source => :items, :order => 'items.time DESC', :conditions => ['items.complete = ?',true]

   attr_accessor :password

   validates_presence_of     :login,                      :if => :not_openid?, :message => "please provide a username" #:email,
   validates_presence_of     :password,                   :if => :password_required?
   validates_presence_of     :password_confirmation,      :if => :password_required?
   validates_length_of       :password, :within => 4..40, :if => :password_required?, :message => " password to short"
   validates_confirmation_of :password,                   :if => :password_required?, :message => " not confirmed"
   validates_length_of       :login,   :within => 3..40,  :if => :not_openid?, :message => " login to short"
   #validates_length_of       :email,   :within => 3..100, :if => :not_openid?
   validates_uniqueness_of   :login,  :case_sensitive => false, :message => " already taken" #:email,

   before_save               :encrypt_password
   before_create             :make_activation_code

   delegate *Tag.types.push( :tags, :to => :valid_items )

   # Activates the user in the database.
   def activate!
      @activated = true
      self.attributes = {:activated_at => Time.now.utc, :activation_code => nil}
      save!
   end

   def activate
      begin
         activate!
      rescue
         return false
      end
   end

   def activated?
      !! activation_code.nil?
   end

   # Returns true if the user has just been activated.
   def recently_activated?
      @activated
   end

   # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
   def self.authenticate(login, password)
      u = find :first, :conditions => ['login = ? and activated_at IS NOT NULL', login] # need to get the salt
      u && u.authenticated?(password) ? u : nil
   end

   # Encrypts some data with the salt.
   def self.encrypt(password, salt)
      Digest::SHA1.hexdigest("--#{salt}--#{password}--")
   end

   # Encrypts the password with the user salt
   def encrypt(password)
      self.class.encrypt(password, salt)
   end

   def authenticated?(password)
      crypted_password == encrypt(password)
   end

   def remember_token?
      remember_token_expires_at && Time.now.utc < remember_token_expires_at
   end

   # These create and unset the fields required for remembering users between browser closes
   def remember_me
      remember_me_for 2.weeks
   end

   def remember_me_for(time)
      remember_me_until time.from_now.utc
   end

   def remember_me_until(time)
      self.remember_token_expires_at = time
      self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
      save(false)
   end

   def forget_me
      self.remember_token_expires_at = nil
      self.remember_token            = nil
      save(false)
   end

   # registration is a hash containing the valid sreg keys given above
   def assign_registration_attributes( types, registration)
      updated = false
      types.each do |model_attribute, registration_attribute|
         next if registration[registration_attribute].blank?
         res = send("#{model_attribute}" )
         next if res == registration[registration_attribute]  #test if value is already set
         send("#{model_attribute}=", registration[registration_attribute] )
         updated = true
      end
   end

   def after_destroy
      if User.count.zero?
         raise "Can't delete last user"
      end
   end

   protected
   # before filter
   def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
      self.crypted_password = encrypt(password)
   end

   def password_required?
      not_openid? && (crypted_password.blank? || !password.blank?)
   end

   def not_openid?
      identity_url.blank?
   end

   def make_activation_code
      self.activation_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
   end
end

