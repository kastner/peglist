require 'sinatra/base'
require 'mustache/sinatra'

class Peglist < Sinatra::Base
  register Mustache::Sinatra
  
  # set :mustaches, "views/"
  # set :views, "templates/"
  set :views,     'templates/'
  set :mustaches, 'views/'
  
  
  get '/' do
    mustache :index
  end
end