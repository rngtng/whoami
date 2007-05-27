Tag.destroy_all
Item.destroy_all
ItemsTag.destroy_all
#a = Account.find 2
#a.fetch_items
a = Account.find 5
a.fetch_items

require 'rubygems'
require 'flickr'
@api ||= Flickr.new( 'dummy', '4e49a06e0e815680660e1e37ae4a1a2d', '9390237b2c854292' )
@api.photos.getInfo( "46939396", "cde8f9ce94" )
