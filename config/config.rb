require 'views/view_helpers'

class Peglist
  configure do
  end
  
  configure :development do
    # puts "Setting up static"
    # use Rack::Static, :urls => %w|/images /css|, :root => "/public"
  end
  
  configure :production do
  end
end