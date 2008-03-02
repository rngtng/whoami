require File.dirname(__FILE__) + '/../test_helper'

class ExtractorTest < Test::Unit::TestCase

   # Replace this with your real tests.
   def test_truth
      assert true
   end

   def _test_extract_image()
	data ={
	 {:type => :image, :url => "http://www.test.de/path/to/image.jpg", :valid => true},
	 {:type => :image, :url =>  "www.test.de/path/to/image.gif", :valid => true},
	 {:type => :image, :url => "http://www.test.de/image.png", :valid => true},
	 {:type => :url,   :url => "http://www.test.de/image.png", :valid => false},
	 {:type => :image, :url => "/image.png", :valid => false},
	 {:type => :url, :url => "www.test.de",  :valid => true},
	}   
	   
	from =""
	
	Extractor.get_urls_and_images( from ) do |type, url|
	  assert :image, 
	
	end
   end   
	   
end

