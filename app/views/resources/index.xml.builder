#xml.instruct!
xml.data do
 @resources.each do |resource|
  xml.event( resource.title,  
   :start => resource.time.httpdate, 
   :title => resource.title,
   :link =>  resource_path( :id => resource, :username => @user.login ), 
   :image => resource.thumbnail,
   :thumbnail=> resource.thumbnail,
   :color => resource.color )
 end
end
