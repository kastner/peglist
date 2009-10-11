require 'views/view_helpers'

class Peglist
  configure do
  end
  
  configure :development do
    use Rack::Reloader
    
    ActiveRecord::Base.establish_connection({
      :adapter => "sqlite3",
      :database => "peglist.sqlite3"
    })
  end
  
  configure :production do
  end
end