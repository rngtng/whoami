##!/bin/sh
##echo "######################################################"
##echo "#                                                    #"
##echo "#    WELCOME TO WHOAMI INSTALLAION                   #"
##echo "#                                                    #"
##echo "######################################################"
##echo ""
##echo "You need alradey installed:"
##echo "Get Ruby+Gems >=1.8"
##echo "Get Rails >=1.2.3"
##echo "Get MySQL >= 4.xx"
##echo "Get subversion >= 1.??"
##
##./install_gems.sh
##
##echo "Get source:"
##svn co https://whoami.opendfki.de/repos/trunk whoami
##
###echo "set up database in whoami/config/database.yml"
###Run migrate:
##
##cd whoami
##rake db:migrate

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
