####################
#
# $LastChangedDate:2007-08-07 15:37:28 +0200 (Tue, 07 Aug 2007) $
# $Rev:94 $
# by $Author:bielohla $

#Module to extend an closs for instance var access. 
#Generates predefined default values and boolean 'foo?' methods
module InstanceVars

   #for other vars except boolean
   def iattr_reader( *syms )
      loop( syms ) do |sym, val|
         build( sym, val )
      end
   end

   #for boolean vars
   def iattr_reader_boolean( *syms )
      loop( syms, false ) do |sym, val|
         build( sym, val )
         build_boolean( sym, val )
      end
   end

   private
   #loops through all values. THey should have the structure : [{:key => :value, :key2 => value}]
   # if not the inside hash is created with global default value
   def loop( syms, default = nil )
      syms.each do |sym|
         sym = { sym => default } unless sym.is_a?(Hash)
         sym.each do |key, val|
            yield( key, val )
         end
      end
   end

   #generates the basic reader methods
   def build( sym, val )
      #puts "build: #{sym} - value: #{val}"
      val = "\"#{val}\"" if val.is_a?  String
      class_eval(<<-EOS, __FILE__, __LINE__)
      unless defined? @#{sym}
         @#{sym} = #{val}
      end

      def self.#{sym}
         return @#{sym} if defined? @#{sym}
	 superclass.#{sym}
      end

      def #{sym}
         self.class.#{sym} 
      end
      EOS
   end

   #generates the boolean 'foo?' methods
   def build_boolean( sym, val )
      #puts "build: #{sym} - value: #{val}"
      class_eval(<<-EOS, __FILE__, __LINE__)
      def self.#{sym}?
         return #{sym} == true
      end

      def #{sym}?
         self.class.#{sym}?
      end
      EOS
   end

end

