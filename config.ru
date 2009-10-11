$:.unshift '../../Ruby/mustache/lib'
require 'sinatra/base'
require 'mustache/sinatra'
require 'ruby-debug'
require 'peglist'

use Rack::Lint
use Rack::ShowExceptions
use Rack::Static, :urls => %w|/images /css|, :root => "public"

require 'config/config'

run Peglist.new
