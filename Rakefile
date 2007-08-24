####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

f = File.join(File.dirname(__FILE__), 'config', 'boot')
require( f ) if File.exist?( "#{f}.rb" )

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails' if defined?( RAILS_ROOT )
