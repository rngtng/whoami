require File.dirname(__FILE__) + '/../test_helper'

class TagTest < Test::Unit::TestCase
   fixtures :tags

   def test_correct_types
      Tag.types.each do |type|
         assert Tag.has_type?( type.to_s.singularize ), "Failed by: #{type.to_s}"
      end
   end

   def test_get_tag_default( name = 'test' )
      t = Tag.get( name )
      assert t, 'could not get Tag'
      assert t.is_type?( Tag.default_type ), 'wrong type'
   end

  # def test_get_tag( name = "   This SHOULD be \"' stripped and downCased ", tags = [:vague, :person ] )
  #    tags.each do |type|
  #       t = Tag.get( type => name )
  #       name = name.downcase.strip.gsub( '"', '').gsub("'", '' ).squeeze(" ")
  #       assert t, 'could not get Tag'
  #       assert_equal t.name, name, "wrong name: #{t.name}"
  #       assert t.is_type?( type ), 'wrong type'
  #       t.destroy
  #    end
  # end

 #def test_get_link #no changes in case
 #   link = " http://www.test.LINK.de/path/to/link/fil.html?parem=2&parem2=sdf+asd%20asd' "
 #   t = Tag.get( :link => link )
 #   link = link.strip.gsub( '"', '').gsub("'", '' ).squeeze(" ")
 #   assert_equal t.name, link, "wrong name: #{t.name}"
 #end
 #
 #def test_change_tag_type( type1 = :person, type2 = :link, name = 'test_p2l' )
 #   t = Tag.get( type1 => name )
 #   assert t.is_type?( type1 ), 'wrong type'
 #   t = t.change_type!( type2 )
 #   assert t.is_a?( type2.to_s.classify.constantize ), "could not change Class type from #{type1} to #{type2} -> it is #{t.type}"
 #   assert t.is_type?( type2 ), "could not change type from #{type1} to #{type2} -> it is #{t.type}"
 #   assert t.save
 #end
 #
 #def test_split_and_get_tags( type = :person, tags ="Tag1 tag2 tag3" )
 #   t = Tag.split_and_get( {type => tags}, ' ' )
 #   tags = tags.split( ' ')
 #   assert_equal t.size, 3
 #   assert_equal t.first.name, tags.first.downcase
 #   assert t.first.is_type?( type )
 #end
 #
 #def test_get_tag_with_change_default_to_person( type1 = :person, tag = 'k1' )
 #   test_get_tag_default( tag )
 #   ##now get the tag
 #   t = Tag.get( type1 => tag )
 #   assert t.id
 #   assert t.is_a?( type1.to_s.classify.constantize ), "could not change Class type from DEFAULT to #{type1} -> it is #{t.type}"
 #   assert t.is_type?( type1 )
 #   assert t.save
 #end

   def test_get_tag_location_to_geo( type1 = :location, type2 = :geo, tag = 'spain' )
      test_get_tag_default( tag )
      ##now get the tag
      t = Tag.get( type1 => tag )
      assert t.id
      assert t.is_type?( type2 )
      assert t.is_a?( type2.to_s.classify.constantize ), "could not change Class type from DEFAULT to #{type2} -> it is #{t.type}"
   end

   ###################################### should fail
  #def test_change_tag_wrongtype(type1 = :person, type2 = :this_is_not_valid, name = 'test_p2invalid' )
  #   t = Tag.get( type1 => name )
  #   assert t.is_type?( type1 ), 'wrong type'
  #   t = t.change_type!( type2 )
  #   assert t.is_a?( type1.to_s.classify.constantize ), "could not change Class type from #{type1} to #{type2} -> it is #{t.type}"
  #   assert t.is_type?( type1 ), "change to wrong type #{t.type}"
  #   assert t.save
  #end
  #
  #def test_get_tag_with_nochange_person_to_default( type1 = :person, tag = 'k1' )
  #   test_get_tag_with_change_default_to_person( type1, tag='kasd' )
  #   ##now get the tag
  #   type2 = Tag.default_type
  #   t = Tag.get( type2 => tag )
  #   assert t.id
  #   assert t.is_a?( type1.to_s.classify.constantize ), "changed Class type from #{type1} to DEFAULT"
  #   assert t.is_type?( type1 )
  #   assert t.save
  #end
  #
  #def test_
end

