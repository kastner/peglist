class Peglist < Sinatra::Base
  enable :static, :session
  
  register Mustache::Sinatra
  
  set :views,     'templates/'
  set :mustaches, 'views/'
  
  get '/' do
    mustache :index
  end
end

Peglist.run! if $0 == __FILE__