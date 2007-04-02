#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + "/../../lib"
%w|camping camping/session openid face redcloth|.each{|lib| require lib}

Camping.goes :Peglist

module Peglist
  include Camping::Session
end

module Peglist::Helpers
  def HURL(*args)
    url = URL(*args)
    url.scheme = "http"
    if `hostname`.match(/i-am-a-Mac/)
      url.host = "camping.metaatem.net"
      url.port = nil
    end
    url
  end
end

module Peglist::Models
  class Peg < Base
    belongs_to :user
    validates_format_of :number, :with => /^[0-9]+$/
  end
  
  class User < Base
    validates_uniqueness_of :username
    has_many :pegs
  end
  
  class CreateTheBasics < V 1.0
    def self.up
      create_table :peglist_pegs do |t|
        t.column :id, :integer, :null => false
        t.column :user_id, :integer, :null => false
        t.column :number, :string, :null => false
        t.column :phrase, :string
        t.column :image_url, :string
        t.column :image_link, :string
        t.column :notes, :text
        t.column :created_at, :datetime
      end
      
      create_table :peglist_users do |t|
        t.column :id, :integer, :null => false
        t.column :username, :string, :null => false
        t.column :openid, :string
        t.column :avatar_url, :string
        t.column :created_at, :datetime
      end
    end
  end
end

module Peglist::Controllers
  class Index < R '/'
    def get
      # raise @state.to_s
      @user = User.find_by_id(@state.user_id, :include => :pegs) if @state.user_id
      render :index
    end
  end
  
  class What
    def get
      render :what
    end
  end
  
  class New
    def get
      if @state.user_id
        @peg = Peg.new
        @peg.user_id = @state.user_id
        render :new
      else
        render :user_error
      end
    end
  end
  
  class Manynew
    def get
      if @state.user_id
        render :many_new
      else
        render :user_error
      end
    end
  end
  
  class Signup
    def get
      if !@state.openid
        @error = "You must sign in with OpenID before you sign up"
        render :index
      else
        @new_user = User.new
        render :signup
      end
    end
    
    def post
      @username = input.username
      @avatar_url = input.avatar_url
      
      @new_user = User.create(:openid => @state.openid, :username => @username, :avatar_url => @avatar_url)
      if @new_user.save
        @state.user_id = @new_user.id
        @state.username = @new_user.username
        redirect HURL(Index).to_s
      else
        render :signup
      end
    end
  end
  
  class Login
    def open_id_consumer
      OpenID::Consumer.new(@state, OpenID::FilesystemStore.new("/tmp/openids"))
    end
    
    def normalize_url(url)
      url = url.downcase

      case url
      when %r{^https?://[^/]+/[^/]*}
        url # already normalized
      when %r{^https?://[^/]+$}
        url + "/"
      when %r{^[.\d\w]+/.*$}
        "http://" + url
      when %r{^[.\d\w]+$}
        "http://" + url + "/"
      else
        raise "Unable to normalize: #{url}"
      end
    end

    def get
      response = open_id_consumer.complete(input)
      identity_url = normalize_url(response.identity_url) if response.identity_url
      
      case response.status
      when OpenID::CANCEL
        @a = "Canceled"
      when OpenID::FAILURE
        @a = "OpenID authentication failed: #{response.msg}"
      when OpenID::SUCCESS
        @state.openid = identity_url
        @user = User.find_by_openid(identity_url)
        if @user
          @state.user_id = @user.id
          @state.username = @user.username
          redirect HURL(Index).to_s
        else
          redirect HURL(Signup).to_s
        end
      end
    end
    
    def post
      openid_url = normalize_url(input.openid_url)
      response = open_id_consumer.begin(openid_url)

      case response.status
      when OpenID::FAILURE
        @a = "Failure with that OpenID url. Check it and try again please."
      when OpenID::SUCCESS
        redirect response.redirect_url(self.HURL.to_s, self.HURL(Login).to_s)
      end      
    end
  end

  class Logout
    def get
      @state.keys.each{|key| @state.delete(key)}
      @message = "You have been logged out"
      render :index
    end
  end
  
  class Static < R '/static/(.+)'         
    MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript', 
                  '.jpg' => 'image/jpeg'}
    PATH = File.expand_path(File.dirname(__FILE__))

    def get(path)
      @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
      unless path.include? ".." # prevent directory traversal attacks
        @headers['X-Sendfile'] = "#{PATH}/static/#{path}"
      else
        @status = "403"
        "403 - Invalid path"
      end
    end
  end
  
  class Favicon < R '/favicon.ico'
    def get
      @headers['Content-Type'] = 'image/vnd.microsoft.icon'
      @header['X-Sendfile'] = "#{PATH}/static/favicon.ico"
    end
  end
  
  class AvatarSearch < R '/avatar/(.+)/(.+)'
    def get(service, username)
      case service
      when "twitter"
        TwitterFace.url(username)
      when "flickr"
        FlickrFace.url(username)
      end
    end
  end
end

module Peglist::Views
  def amp
    span.amp "&"
  end
  
  def textalize(str)
    text RedCloth.new(str).to_html
  end
  
  def layout
    xhtml_strict do
      head do
        title "Peglist from Meta | ateM"
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/style.css'
        script :type => 'text/javascript', :src => '/static/mootools.js'
      end
      body.home! do
        div.page! do
          div.header! do
            h2.logo! do
              text %Q{<a href="/" title='Peg list at Meta | ateM'><img src="/static/logo.png" alt="Peg list at Meta | ateM"/></a>}
            end
            div.wrap do
              hr
              if !@new_user
                _login
              end
              hr
              ul.nav! do
                li.home { text %Q{<a href="/">Home #{amp} Peg list</a>} }
                li.what { a "What is a Peg list?", :href => R(What) }
              end
            end
          end
          div.content! do
            self << yield  
          end
          div.footer! do

          end          
        end
      end
    end
  end
  
  def index
    if @state.username
      _logged_in_home
    else
      _new_home
    end
  end
  
  def new
    h1 "Add a peg"
  end
  
  def many_new
    h1 "Add multiple pegs"
    
  end
  
  def user_error
    h1 "You must be logged in to do that. Log in above by using an OpenID address."
  end
  
  def _logged_in_home
    h1 do
      img :src => @user.avatar_url if @user.avatar_url?
      text "#{@user.username}'s Peg list"
    end
    a "Add a peg", :href => R(New)
    text " or "
    a "Add many pegs", :href => R(Manynew)
  end
  
  def _new_home
    textalize <<-HTML
    h1. Welcome to Peg list from Meta | ateM
    
    A peg list is a memory device that has been used for thousands of years.
    
    For more information on peg lists and why they are useful for anyone, <a href="/what">read "What is a peg list"</a>.
    
    Pet list from Meta | ateM will let you record your peg list, and associate each peg with an image to help strengthen the association -- peg lists work best when your form pictures in your mind.
    
    If you're ready to get started -- log in at the top of the page with any "OpenID":http://http://en.wikipedia.org/wiki/OpenID address.
    HTML
  end
  
  def what
    textalize <<-HTML
    h1. What is a Peg list?
    
    A peg system is a mnemonic technique for memorizing lists. It works by pre-memorizing a list of words that are easy to associate with the numbers they represent(1 to 10, 1-100, 1-1000, etc). Those objects form the "pegs" of the system. Then in the future, to rapidly memorize a list of arbitrary objects, each one is associated with the appropriate peg. Generally, a peglist only has to be memorized one time, and can then be used over and over every time a list of items needs to be memorized.
    
    taken from "http://en.wikipedia.org/wiki/Mnemonic_peg_system":Wikipedia
    
    The short version: you spend time in the beginning learning a list of words that you later use as anchors for memorizing OTHER things. By working on this memory skill, not only are you able to memorize lists in day-to-day life (like grocerys), it helps you with your normal memory as well.
    
    Here's an example. Let's pretend your peg list has these items as it's first five:
    
    # gun
    # shoe
    # tree
    # door
    # hive
    
    and the list you need to memorize is:
    
    # tomatos
    # milk
    # bread
    # toothpaste
    # toilet paper
    
    You'd go through the list and form the silliest pictures you can relating one to the other.
    For example: 
    
    !http://farm1.static.flickr.com/36/78546217_ab4d8a0387_m.jpg(Bullet against tomato on Flickr)!:http://www.flickr.com/photos/fotofrog/78546217/
    
    and so on (stepping on a jug of milk, a tree with loaves of bread hanging from it, etc.)
    
    
    HTML
  end
  
  def signup
    h1 "Pick your username and an avatar if you have one"
    h2 "You will use the OpenID #{@state.openid} to log in"
    
    errors_for @new_user
    
    form :action => R(Signup), :method => :post do
      p do
        label 'Username:', :for => 'signup_username'
        input :name => 'username', :type => 'text', :id => 'signup_username', :value => @new_user.username
      end
      
      fieldset do
        legend "Find my avatar:"
        p do
          label 'Flickr username:', :for => 'flickr_username'
          input :name => 'flickr_username', :type => 'text', :class => 'avatar_search', :id => 'flickr_username'
          input :type => 'button', :value => "Lookup", :id => 'flickr_button', :class => 'avatar_button'
        end
        p do
          label 'Twitter username:', :for => 'twitter_username'
          input :name => 'twitter_username', :type => 'text', :class => 'avatar_search', :id => 'twitter_username'
          input :type => 'button', :value => "Lookup", :id => 'twitter_button', :class => 'avatar_button'
        end
        text <<-HTML
        <script type="text/javascript" charset="utf-8">
          document.getElementsByClassName('avatar_button').forEach(function(button) {
            button.onclick = function() {
              var type = button.id.split("_")[0]
              var url = '/avatar/' + type + '/' + $(type+'_username').value
              new Ajax(url, {
                method: 'get',
                onComplete: function(req) {
                  $('signup_avatar').value = req;
                  $('avatar_preview').src = req;
                }
              }).request()
              
            }
          })
        </script>
        HTML
      end
      
      p do
        label 'Avatar url:', :for => 'signup_avatar'
        input :name => 'avatar_url', :type => 'text', :id => 'signup_avatar', :value => @user.avatar_url
        img :id => 'avatar_preview', :width => 45, :src => @avatar_url
      end
      
      p do
        input :type => 'submit', :value => "Sign up"
      end
    end
  end
  
  def login
    p "Login"
  end
  
  def _login
    if !@state.username or @state.username.empty?
      form :action => R(Login), :method => :post do
        div do
          label 'your OpenID address', :for => 'login_openid', :id => 'login_openid_label'
          input :name => 'openid_url', :type => 'text', :id => 'login_openid'
        
          input :type => 'submit', :value => 'login'
          text <<-HTML
          <script type="text/javascript" charset="utf-8">
            window.addEvent('domready', function() { if ($('login_openid').value != '') {$('login_openid').setStyle('zIndex', 3) }})
            $('login_openid_label').addEvent('click', function() { $('login_openid').focus(); })
            $('login_openid').addEvent('focus', function() { $('login_openid').setStyle('zIndex', 3) })
            $('login_openid').addEvent('blur', function() { if ($('login_openid').value == '') $('login_openid').setStyle('zIndex', 1) })
          </script>
          HTML
        end      
      end
    else
      form :action => R(Logout), :method => :get do
        div do
          div "Logged in as #{@state.username} (#{@state.openid})"
          a "Log out?", :href => R(Logout)
        end
      end
    end
  end
end

def Peglist.create
  Camping::Models::Session.create_schema
  Peglist::Models.create_schema :assume => (Peglist::Models::Peg.table_exists? ? 1.0 : 0.0)
end