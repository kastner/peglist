$:.unshift '../../Ruby/mustache/lib'
require 'sinatra/base'
require 'mustache/sinatra'
require 'ruby-debug'
require 'views/view_helpers'
require 'peglist'

peglist = Peglist.new

use Rack::Lint
use Rack::ShowExceptions

require 'config/config'
use Rack::Static, :urls => %w|/images /css|, :root => "public"

run peglist
