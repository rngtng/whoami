require File.dirname(__FILE__) + '/../test_helper'

class AnnotationTest < Test::Unit::TestCase
   fixtures :annotations

   def test_correct_concepts
      Annotation.concepts.each do |type|
         assert Annotation.new.has_concept?( type ), "Failed by: #{type.to_s}"
      end
   end

   def test_get_annotation_default( name = 'test_new', type = :topic )
      t = Annotation.get( name )
      assert t, 'could not get Annotation'
      assert t.is_type?( type ), 'wrong type'
   end

   def test_get_annotation_from_db()
      test_get_annotation_default( 'test1', :tag )
   end

   #def test_get_annotation( name = "   This SHOULD be \"' stripped and downCased ", annotations = [:tag, :person ] )
   #    annotations.each do |type|
   #       t = Annotation.get( type => name )
   #       name = name.downcase.strip.gsub( '"', '').gsub("'", '' ).squeeze(" ")
   #       assert t, 'could not get Annotation'
   #       assert_equal t.name, name, "wrong name: #{t.name}"
   #       assert t.is_type?( type ), 'wrong type'
   #       t.destroy
   #    end
   #end

   def test_get_url( url = " http://www.test.LINK.de/path/to/link/fil.html?parem=2&parem2=sdf+asd%20asd' " ) #no changes in case
      t = Annotation.get( :url => url )
      link = url.strip.gsub( '"', '').gsub("'", '' ).squeeze(" ")
      assert_equal t.name, url, "wrong name: #{t.name}"
   end

   def test_change_annotation_type( type1 = :tag, type2 = :url, name = 'test_p2l' )
      t = Annotation.get( type1 => name )
      assert t.is_type?( type1 ), 'wrong type'
      t = Annotation.change_type!( type2, t )
      assert t.is_a?( type2.to_s.classify.constantize ), "could not change Class type from #{type1} to #{type2} -> it is #{t.type}"
      assert t.is_type?( type2 ), "could not change type from #{type1} to #{type2} -> it is #{t.type}"
      assert t.save
   end

   def test_get_annotation_with_change_default_to_person( type1 = :person, annotation = 'k1' )
      test_get_annotation_default( annotation )
      ##now get the annotation
      t = Annotation.get( type1 => annotation )
      assert t.id
      assert t.is_a?( type1.to_s.classify.constantize ), "could not change Class type from DEFAULT to #{type1} -> it is #{t.type}"
      assert t.is_type?( type1 )
      assert t.save
   end

   # def test_get_annotation_location_to_geo( type1 = :location, type2 = :geo, annotation = 'spain' )
   #    test_get_annotation_default( annotation )
   #    ##now get the annotation
   #    t = Annotation.get( type1 => annotation )
   #    assert t.id
   #    assert t.is_type?( type2 )
   #    assert t.is_a?( type2.to_s.classify.constantize ), "could not change Class type from DEFAULT to #{type2} -> it is #{t.type}"
   # end
   #

   ###################################### should fail
   def test_change_annotation_wrongtype(type1 = :person, type2 = :this_is_not_valid, name = 'test_p2invalid' )
      t = Annotation.get( type1 => name )
      assert t.is_type?( type1 ), 'wrong type'
      assert_raise( Exception) do
         t = Annotation.change_type!( type2, t )
      end
      assert t.is_a?( type1.to_s.classify.constantize ), "could not change Class type from #{type1} to #{type2} -> it is #{t.type}"
      assert t.is_type?( type1 ), "change to wrong type #{t.type}"
      assert t.save
   end

   #
   #def test_get_annotation_with_nochange_person_to_default( type1 = :person, annotation = 'k1' )
   #   test_get_annotation_with_change_default_to_person( type1, annotation='kasd' )
   #   ##now get the annotation
   #   type2 = Annotation.default_type
   #   t = Annotation.get( type2 => annotation )
   #   assert t.id
   #   assert t.is_a?( type1.to_s.classify.constantize ), "changed Class type from #{type1} to DEFAULT"
   #   assert t.is_type?( type1 )
   #   assert t.save
   #end
end

