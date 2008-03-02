atom_feed(:url => formatted_resources_url( :format => :atom, :username => @user.login )) do |feed|
   feed.title("Resources")
   feed.updated( Time.now.utc )

   for resource in @resources
      feed.entry(resource, :url => resource_path( :id => resource, :username => @user.login), :published => resource.time ) do |entry|
         entry.title(resource.title)
	 conent = image_tag( resource.thumbnail, :style => "border: 1px solid #{resource.color};", :align=>"left", :title => resource.title )
         entry.content( "#{conent} #{resource.text}", :type => 'html')
         entry.author do |author|
           author.name( @user.login )
         end
      end
   end
end
