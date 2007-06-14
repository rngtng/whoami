# parses model files and builds DOT file that visualizes class tree
# to be called from <</script>> as: 
# ruby -I ../app/models diagram.rb /path/to/output/file [-s | m | o | b | t ]
# options:
# s - sql mode (table names and foreign key fields); other options become irrelevant
# m - display :has_many associations only
# o - display :has_one associations only
# b - display :belongs_to associations only
# t - display :has_and_belongs_to only
# m, o, b, t options can be mixed - their output is combined, e.g. -mb will show :has_many and :belongs_to
# default: no options means -mobt


require "rubygems" 
require 'yaml'
require_gem "activerecord"
include Inflector

def associations(klass)
  instance_eval(klass).reflect_on_all_associations
end

connection_ = YAML.load(File.open("../config/database.yml","r"))['development']
ActiveRecord::Base.establish_connection connection_
errcode = 0

#parse parameters from command line
path_to_output = ARGV[0]
is_sql = is_has_many = is_has_one = is_belongs_to = is_hbtm = false 
if ARGV[1]
  is_sql = ARGV[1] =~ /^-.*s/
  is_has_many = ARGV[1] =~ /^-.*m/
  is_has_one = ARGV[1] =~ /^-.*o/
  is_belongs_to = ARGV[1] =~ /^-.*b/
  is_hbtm = ARGV[1] =~ /^-.*t/
else
  is_has_many = is_has_one = is_belongs_to = is_hbtm = true
end
is_hbtm = is_hbtm || is_sql

#try to open app/models directory
dir = nil
path_to_models = '../app/models/'
begin
  dir = Dir.open(path_to_models)
rescue
  puts( "Could not read directory #{path_to_models} #{$!}")
  errcode = 4
end

#read app/models directory and select all files that belong to ActiveRecord::Base class
unless dir.nil?
  models = []
  belong_to_associations = []
  dir.each do |fname|
    begin
      if fname =~ /\.rb$/ 
        file_model_name = camelize(fname.gsub(/\.rb$/, ''))
        models << file_model_name if instance_eval(file_model_name).new.kind_of?(ActiveRecord::Base)
      end
    rescue 
      puts( "Not a model file: #{fname}")
      errcode = 1
    end
  end
  
  #build hash of associations for each member of models array
  for m in models
    for assoc in associations(m)
        belong_to_associations << {'Model' => m, 'Belongs' => assoc.class_name, 'Type' => assoc.macro, 'Name' => assoc.name, 'Key' => assoc.primary_key_name, 'JoinTable' => (assoc.options.empty? ? nil : assoc.options[:join_table])}
    end
  end
  
  unless path_to_output.nil? || errcode > 1
    begin
      #start building DOT file
      output = File.new(path_to_output, File::CREAT|File::TRUNC|File::WRONLY)
      output.write "digraph structs {\n"
      #list of nodes (model names)
      for m in models
        if is_sql
          output.write m.tableize + ";\n"
        else
          output.write m + ";\n"
        end
      end
      #arrows for belongs_to associations
      if is_sql || is_belongs_to
        for m in models
          for a in belong_to_associations
            if a['Model'] == m && a['Type'] == :belongs_to
              if is_sql
                output.write m.tableize + ' -> ' + a['Belongs'].tableize + " [label = \"#{a['Key']}\"]" + ";\n"
              else
                output.write m + ' -> ' + a['Belongs'] + " [label = \"#{a['Name']}\"]" + ";\n"
              end
            end
          end
        end
      end
      unless is_sql
        #arrows for has_many associations
        if is_has_many
          for m in models
            for a in belong_to_associations
              if a['Model'] == m && a['Type'] == :has_many
                output.write m + ' -> ' + a['Belongs'] + " [label = \"#{a['Name']}\", color=blue, fontcolor=blue]" + ";\n"
              end
            end
          end
        end
        #arrows for has_one associations
        if is_has_one
          for m in models
            for a in belong_to_associations
              if a['Model'] == m && a['Type'] == :has_one
                output.write m + ' -> ' + a['Belongs'] + " [label = \"#{a['Name']}\", color=red, fontcolor=red]" + ";\n"
              end
            end
          end
        end
      end
        
      #hbtm associations
      if is_hbtm
        for m in models
          for a in belong_to_associations
            if a['Model'] == m && a['Type'] == :has_and_belongs_to_many
              if is_sql
                output.write "node [shape=diamond,style=filled,color=magenta] " + a['JoinTable'] + ";\n"
                output.write m.tableize + ' -> ' + a['JoinTable'] + " [label = \"#{a['Key']}\", color=magenta, fontcolor=magenta]" + ";\n"
              else
                output.write "node [shape=diamond,style=filled,color=magenta,label=\"\"] " + a['JoinTable'] + ";\n"
                output.write m + ' -> ' + a['JoinTable'] + " [label = \"#{a['Name']}\", color=magenta, fontcolor=magenta]" + ";\n"
              end
            end
          end
        end
      end
      
      #write end of DOT file
      output.write 'label = "black :belongs_to\n'
      output.write 'blue :has_many \n'
      output.write 'red :has_one \n'
      output.write 'magenta :has_and_belongs_to "'
      output.write "\n}"
      output.close
    rescue
      puts( "Could not write output file #{$!}")
      errcode = 2
    end
  else
    puts( "Missing argument: output file #{$!}")
    errcode = 3
  end

end
  

