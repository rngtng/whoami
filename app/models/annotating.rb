####################
#
# $LastChangedDate:2007-08-07 15:37:28 +0200 (Tue, 07 Aug 2007) $
# $Rev:94 $
# by $Author:bielohla $

class Annotating < ActiveRecord::Base
   belongs_to :resource
   belongs_to :annotation, :polymorphic => true

   # This callback makes sure that an orphaned <tt>Tag</tt> is deleted if it no longer tags anything.
   def before_destroy
     # annotation.destroy_without_callbacks if annotation and annotation.taggings.count == 1
   end
end

