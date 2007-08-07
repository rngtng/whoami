####################
#
# $LastChangedDate:2007-08-07 15:37:28 +0200 (Tue, 07 Aug 2007) $
# $Rev:94 $
# by $Author:bielohla $ 

class Annotating < ActiveRecord::Base
   belongs_to :resource
   belongs_to :annotation, :polymorphic => true
end

