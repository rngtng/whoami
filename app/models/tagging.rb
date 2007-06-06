####################
#
# $LastChangedDate$
# $Rev$
# by $Author$ 

class Tagging < ActiveRecord::Base
   belongs_to :item
   belongs_to :tag, :polymorphic => true
end

