$:.unshift '../../Ruby/mustache/lib'
$:.unshift 'lib/rack-openid/lib'
require 'sinatra/base'
require 'mustache/sinatra'
require 'ruby-debug'
require 'rack/openid'
require 'activerecord'
require 'peglist'

Dir["models/*"].each {|model| require model}

use Rack::Lint
use Rack::ShowExceptions
use Rack::Static, :urls => %w|/images /css|, :root => "public"
use Rack::Session::Cookie
use Rack::OpenID

require 'config/config'

run Peglist.new
