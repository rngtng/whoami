
class ActiveRecord::Base #:nodoc:

  # These extensions make models taggable. This file is automatically generated and required by your app if you run the tagging generator included with has_many_polymorphs.
  module TaggingExtensions
    
    # Add tags to <tt>self</tt>. Accepts a string of tagnames, an array of tagnames, an array of ids, or an array of Tags.
    #
    # We need to avoid name conflicts with the built-in ActiveRecord association methods, thus the underscores.
    def _add_tags incoming
      taggable?(true)
      tag_cast_to_string(incoming).each do |tag_name|
        begin
          tag = Tag.find_or_create_by_name(tag_name)
          raise Tag::Error, "tag could not be saved: #{tag_name}" if tag.new_record?
          tag.taggables << self
        rescue ActiveRecord::StatementInvalid => e
          raise unless e.to_s =~ /duplicate/i
        end
      end
    end
  
    # Removes tags from <tt>self</tt>. Accepts a string of tagnames, an array of tagnames, an array of ids, or an array of Tags.  
    def _remove_tags outgoing
      taggable?(true)
      outgoing = tag_cast_to_string(outgoing)
  <% if options[:self_referential] %>  
      # because of http://dev.rubyonrails.org/ticket/6466
      taggings.destroy(*(taggings.find(:all, :include => :<%= parent_association_name -%>).select do |tagging| 
        outgoing.include? tagging.<%= parent_association_name -%>.name
      end))
  <% else -%>   
      <%= parent_association_name -%>s.delete(*(<%= parent_association_name -%>s.select do |tag|
        outgoing.include? tag.name    
      end))
  <% end -%>
    end

   # Returns the tags on <tt>self</tt> as a string.
    def tag_list
      # Redefined later to avoid an RDoc parse error.
    end
  
    # Replace the existing tags on <tt>self</tt>. Accepts a string of tagnames, an array of tagnames, an array of ids, or an array of Tags.
    def tag_with list    
      #:stopdoc:
      taggable?(true)
      list = tag_cast_to_string(list)
             
      # Transactions may not be ideal for you here; be aware.
      Tag.transaction do 
        current = <%= parent_association_name -%>s.map(&:name)
        _add_tags(list - current)
        _remove_tags(current - list)
      end
      
      self
      #:startdoc:
    end

   # Returns the tags on <tt>self</tt> as a string.
    def tag_list #:nodoc:
      #:stopdoc:
      taggable?(true)
      <%= parent_association_name -%>s.reload
      <%= parent_association_name -%>s.to_s
      #:startdoc:
    end
    
    private 
    
    def tag_cast_to_string obj #:nodoc:
      case obj
        when Array
          obj.map! do |item|
            case item
              when /^\d+$/, Fixnum then Tag.find(item).name # This will be slow if you use ids a lot.
              when Tag then item.name
              when String then item
              else
                raise "Invalid type"
            end
          end              
        when String
          obj = obj.split(Tag::DELIMITER).map do |tag_name| 
            tag_name.strip.squeeze(" ")
          end
        else
          raise "Invalid object of class #{obj.class} as tagging method parameter"
      end.flatten.compact.map(&:downcase).uniq
    end 
  
    # Check if a model is in the :taggables target list. The alternative to this check is to explicitly include a TaggingMethods module (which you would create) in each target model.  
    def taggable?(should_raise = false) #:nodoc:
      unless flag = respond_to?(:<%= parent_association_name -%>s)
        raise "#{self.class} is not a taggable model" if should_raise
      end
      flag
    end

  end
  
  module TaggingFinders
    # 
    # Find all the objects tagged with the supplied list of tags
    # 
    # Usage : Model.tagged_with("ruby")
    #         Model.tagged_with("hello", "world")
    #         Model.tagged_with("hello", "world", :limit => 10)
    #
    def tagged_with(*tag_list)
      options = tag_list.last.is_a?(Hash) ? tag_list.pop : {}
      tag_list = parse_tags(tag_list)
      
      scope = scope(:find)
      options[:select] ||= "#{table_name}.*"
      options[:from] ||= "#{table_name}, tags, taggings"
      
      sql  = "SELECT #{(scope && scope[:select]) || options[:select]} "
      sql << "FROM #{(scope && scope[:from]) || options[:from]} "

      add_joins!(sql, options, scope)
      
      sql << "WHERE #{table_name}.#{primary_key} = taggings.taggable_id "
      sql << "AND taggings.taggable_type = '#{ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s}' "
      sql << "AND taggings.tag_id = tags.id "
      
      tag_list_condition = tag_list.map {|name| "'#{name}'"}.join(", ")
      
      sql << "AND (tags.name IN (#{sanitize_sql(tag_list_condition)})) "
      sql << "AND #{sanitize_sql(options[:conditions])} " if options[:conditions]
      
      columns = column_names.map do |column| 
        "#{table_name}.#{column}"
      end.join(", ")
      
      sql << "GROUP BY #{columns} "
      sql << "HAVING COUNT(taggings.tag_id) = #{tag_list.size}"
      
      add_order!(sql, options[:order], scope)
      add_limit!(sql, options, scope)
      add_lock!(sql, options, scope)
      
      find_by_sql(sql)
    end
    
    def parse_tags(tags)
      return [] if tags.blank?
      tags = Array(tags).first
      tags = tags.respond_to?(:flatten) ? tags.flatten : tags.split(Tag::DELIMITER)
      tags.map { |tag| tag.strip.squeeze(" ") }.flatten.compact.map(&:downcase).uniq
    end
    
  end

  include TaggingExtensions
  extend  TaggingFinders
end
