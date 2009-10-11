class Peglist < Sinatra::Base
  register Mustache::Sinatra
  
  set :views,     'templates/'
  set :mustaches, 'views/'
  
  get '/' do
    mustache :index
  end
  
  post '/login' do
    authenticate_unless_openid_response
    
    response = request.env["rack.openid.response"]
    return "Error: #{response.status}" unless response.status == :success
    
    if user = find_user_for_openid(response.identity_url)
      session["user"] = user
      redirect "/"
    else
      signup_with(response)
    end
  end
  
  get '/signup' do
    locals = {
      :openid => session["openid_response"].identity_url,
      :has_avatar_url => false
    }
    
    mustache :signup, {}, locals
  end
  
  post '/signup' do
    attribs = params.merge(:openid => session["openid_response"].identity_url)
    
    @user = User.new(attribs)
    if @user.save
      session[:user] = @user
      session[:openid_response] = nil
      redirect '/'
    else
      locals = { :has_avatar_url => false }.merge(params)
      mustache :signup, {}, locals
    end
  end
  
  def authenticate_unless_openid_response
    return if request.env["rack.openid.response"]
    headers 'WWW-Authenticate' => Rack::OpenID.build_header(
      :identifier => params["openid_url"]
    )
    throw :halt, [401, 'got openid?']
    return
  end
  
  def signup_with(response)
    session["openid_response"] = response
    redirect '/signup'
  end
  
  def find_user_for_openid(identity_url)
    User.find_by_openid(identity_url)
  end
end

Peglist.run! if $0 == __FILE__