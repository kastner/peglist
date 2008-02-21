#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + "/../../lib"
$:.unshift File.dirname(__FILE__)
require 'rubygems'
gem 'activerecord', '<2.0'
%w|rubygems mongrel camping mongrel/camping camping/session openid face redcloth open-uri|.each{|lib| require lib}

Camping.goes :Peglist

# ActiveRecord::Base.logger = Logger.new(STDOUT)

module Peglist
  include Camping::Session
end

module Peglist::Helpers
  def HURL(*args)
    url = URL(*args)
    url.scheme = "http"
    if `hostname`.match(/i-am-a-Mac/)
      url.host = "peglist.metaatem.net"
      url.port = nil
    end
    url
  end
  
  def escape_javascript(javascript)
    (javascript || '').gsub('\\','\0\0').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
  end
end

module Peglist::Models
  class Peg < Base
    belongs_to :user
    validates_format_of :number, :with => /^[0-9]+$/
    validates_uniqueness_of :number, :scope => :user_id
  end
  
  class User < Base
    validates_uniqueness_of :username
    has_many :pegs
    
    def ordered_pegs
      zeros, rest = pegs.find(:all).partition {|i| i.number.match(/^0/)}
      zeros.sort! {|a,b| a.number <=> b.number}
      rest.sort! {|a,b| a.number.to_i <=> b.number.to_i}
      [zeros, rest].flatten
    end
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
      @user = User.find(@state.user_id) if @state.user_id
      render :index
    end
  end
  
  class Users
    def get
      @users = User.find(:all, :order => "created_at DESC")
      render :users
    end
  end
  
  class K
    def get
      User.find(@state.user_id).pegs.destroy_all
    end
  end
  
  class FillUp < R '/f'
    def get
      @user = User.find(@state.user_id) if @state.user_id
      if !@user.pegs or @user.pegs.empty?
        User.find(1).ordered_pegs[0..19].each do |peg|
          @user.pegs.create(peg.attributes.merge({
            :id => nil,
            :created_at => nil
          }))
        end
      end
      redirect HURL(Index).to_s
    end
  end
  
  class What
    def get
      @body_id = "what"
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
        @form_id = "peg" + Time.new.to_f.to_s
        render :many_new
      else
        render :user_error
      end
    end
  end
  
  class UpdatePeg < R '/update/(.+)'
    def post(id)
      @user = User.find_by_id(@state.user_id)
      @peg = @user.pegs.find_by_id(id)
      if @peg
        @peg.phrase = input.phrase
        @peg.image_url = input.image_url
        @peg.image_link = input.image_link
        @peg.notes = input.notes
        @peg.save
        # make sure it IS an XHR TODO
        @headers["Content-Type"] = "text/javascript"
        <<-HTML
        $('peg_#{id}').replace("#{escape_javascript(_peg_box)}")
        // new Effect.Highlight('peg_#{id}')
        HTML
      end
    end
  end
  
  class PopupPeg < R '/popup_peg/(.+)'
    def get(id)
      @headers["Content-Type"] = "text/javascript"
      @peg = Peg.find_by_id(id)
      if @peg
        <<-HTML
        var lbox = new Lightbox("#{escape_javascript(_peg_form)}")
        Event.observe('new_peg_submit', 'click', function(e) {
          Event.stop(e);
          new Ajax.Request('/update/#{id}', {
            parameters: Form.serialize('new_peg'),
            onSuccess: function() {
              lbox.deactivate()
            }
          })
        })
        Event.observe('new_peg_cancel', 'click', function() {
          lbox.deactivate()
        })
        HTML
      else
      end
    end
  end
  
  class AddQuickPeg < R '/add_quick_peg'
    def post
      @user = User.find_by_id(@state.user_id)
      # puts input.number
      @peg = @user.pegs.create(:number => input.number, :phrase => input.phrase)
      @form_id = Time.new.to_f.to_s
      @headers["Content-Type"] = "text/javascript"
      unless @peg.errors.empty?
        <<-HTML
        alert("Errors? #{@peg.errors.full_messages}")
        HTML
      else
        <<-HTML
        new Insertion.Bottom('pegs', "#{escape_javascript(_quick_peg_form)}");
        HTML
      end
      
    end    
  end
  
  class AddPeg < R '/add_peg'
    def post
      @user = User.find_by_id(@state.user_id)
      @peg = @user.pegs.create(:number => input.number, :phrase => input.phrase)
      if @peg.save
        redirect HURL(Index).to_s
      else
        render :new
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
  
  class Search < R '/search/(.+)'
    def post(service)
      if service =~ /flickr/
        method = "flickr.photos.search"
        api_key = "16fb5e4b6048568754eb7c4b401fd45c"
        url = "http://api.flickr.com/services/rest/?method=#{method}&api_key=#{api_key}&format=json&sort=interestingness-desc&text=#{Camping.escape(input.q)}&nojsoncallback=1"
        open(url).read
      end
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
  
  class Flash
    def get
      if @state.user_id
        @user = User.find_by_id(@state.user_id) if @state.user_id
        if input.start and input.end
          @pegs = @user.pegs.find(1,2,3,4)
          @pegs = @user.pegs.find(:all, :conditions => ["number IN (#{(input.start.to_i..input.end.to_i).to_a.join(",")})"])
        else
          @pegs = @user.pegs.find(:all)
        end
      end
      render :flash
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
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/lightbox.css'
        link :rel => 'shortcut icon', :type => 'image/png', :href => '/static/favicon.png'
        link :rel => 'icon', :type => 'image/png', :href => '/static/favicon.png'
        script :type => 'text/javascript', :src => '/static/prototype.js'
        script :type => 'text/javascript', :src => '/static/lightbox.js'
        script :type => 'text/javascript', :src => '/static/image_panel.js'
      end
      body :id => (@body_id || "home") do
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
  
  def flash
    div.flash_card! do
    end
    script :type => 'text/javascript', :src => '/static/quiz.js'
    text <<-HTML
    <script type="text/javascript" charset="utf-8">
      new Quiz(#{@pegs.to_json}, 'flash_card');
    </script>
    HTML
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
    textalize <<-HTML
    h2. This isn't finished. For now, "add many":/manynew and edit the pictures from the homepage
    HTML
    errors_for @peg
    # form.new_peg :id => "new_peg", :action => "add_peg", :method => "post" do
    #   # images TODO
    #   label "Number:"
    #   input :type => "text", :name => "number", :value => @peg.number
    #   label "Peg:"
    #   input :type => "text", :name => "phrase", :value => @peg.phrase
    #   input :type => "submit", :id => "new_peg_submit", :value => "Save"
    # end    
  end
  
  def users
    ul.users! do
      @users.each do |user|
        text <<-HTML
        <li>
          <img src="#{user.avatar_url}">
          #{user.pegs.size} pegs
          #{user.username} (#{user.openid}) #{user.created_at}
        </li>
        HTML
      end
    end
  end
  
  def many_new
    h1 "Add multiple pegs"
    div.pegs! do
      _quick_peg_form
    end
  end
    
  def _quick_peg_form
    form.new_peg :action => "/add_quick_peg", :method => "post", :id => @form_id do
      label "Number:", :for => @form_id + "_number"
      input :type => "text", :name => "number", :size => 5, :id => @form_id + "_number"
      label "Peg:", :for => @form_id + "_phrase"
      input :type => "text", :name => "phrase", :id => @form_id + "_phrase"
      input :type => "submit", :value => "Add"
    end
    text <<-HTML
    <script type="text/javascript" charset="utf-8">
      $("#{@form_id + "_number"}").focus();
      Event.observe("#{@form_id}", 'submit', function(e) {
        Event.stop(e);
        new Ajax.Request($("#{@form_id}").action, { parameters: Form.serialize("#{@form_id}")})
      })
    </script>
    HTML
  end
  
  def _peg_form
    form.new_peg :id => "new_peg" do
      # Delete, change phrase, images
      h3 "Editing peg for number #{@peg.number}"
      
      div.peg_image! do
        text %Q{<a href="#{@peg.image_link}"><img src="#{@peg.image_url}"/></a>}
      end
      
      input :type => "hidden", :name => "number", :value => @peg.number
      label "Peg:"
      
      input.phrase! :type => "text", :name => "phrase", :value => @peg.phrase

      label "Notes:"      
      textarea :name => "notes" do
        @peg.notes
      end
      
      input :type => "hidden", :id => "new_peg_image_url", :name => "image_url", :value => @peg.image_url
      input :type => "hidden", :id => "new_peg_image_link", :name => "image_link", :value => @peg.image_link
      
      label "Find an image for this peg:"
      input :type => "text", :id => "new_peg_image_search", :value => @peg.phrase
      input :type => "button", :id => "new_peg_image_button", :value => "search"

      label ""
      
      div.image_wrap! do
        div.image_down! :class => "image_button" do; "<" end
        div.image_area! :class => "image_list" do
        end
        div.image_up! :class => "image_button" do; ">" end
      end
      
      # do flickr and yahoo
      
      br
      
      input :type => "submit", :id => "new_peg_submit", :value => "Save"
      input :type => "button", :id => "new_peg_cancel", :value => "Cancel"
      
      text <<-HTML
      <script type="text/javascript" charset="utf-8">
        Event.observe('phrase', 'blur', function() {
          $('new_peg_image_search').value = $F('phrase')
        })
        
        Event.observe('new_peg_image_button', 'click', function() {
          new Ajax.Request('/search/flickr/', {
            parameters: "q=" + $F('new_peg_image_search'),
            onSuccess: function(req) {
              var p = eval("(" + req.responseText + ")")
              new ImagePanel(p.photos.photo, 'image_wrap', {src: "new_peg_image_url", link: "new_peg_image_link", image_show: "peg_image"})
            }
          })
        })
      </script>
      HTML
    end
  end
  
  def user_error
    h1 "You must be logged in to do that. Log in above by using an OpenID address."
  end

  def _peg_box
    li.peg :id => "peg_#{@peg.id}" do
      img :src => (@peg.image_url || "/static/empty.gif")
      span "#{@peg.number}: #{@peg.phrase}"
    end
    text <<-HTML
    <script type="text/javascript" charset="utf-8">
      Event.observe('peg_#{@peg.id}', 'click', function() {
        new Ajax.Request('/popup_peg/#{@peg.id}', {method: 'get'})
      })
    </script>
    HTML
    
  end
  
  def _logged_in_home
    h1 do
      img :src => @user.avatar_url if @user.avatar_url?
      text "#{@user.username}'s Peg list"
    end
    # a "Add a peg", :href => R(New)
    # text " or "
    a "Add pegs", :href => R(Manynew)
    
    unless @user.ordered_pegs.empty?
      br
      input.flash_me! :type => "button", :value => "Show me flash cards"
      text <<-HTML
      <script type="text/javascript" charset="utf-8">
        Event.observe('flash_me', 'click', function() {window.location = '/flash'})
      </script>
      HTML
      ul.peg_list! do
        @user.ordered_pegs.each do |peg|
          @peg = peg
          _peg_box
        end
      end
      # div.peg_popup_wrap! :style => "display: none;" do
      #   div.peg_popup!
      # end
    else
      br
      input.fill_up! :type => "button", :value => "I'm too lazy for this. Do it for me."
      text <<-HTML
      <script type="text/javascript" charset="utf-8">
        Event.observe('fill_up', 'click', function() {window.location = '/f'})
      </script>
      HTML
      img :src => '/static/blank_slate.jpg'
    end
  end
  
  def _new_home
    textalize <<-HTML
    h1. Welcome to Peg list from Meta | ateM
    
    A peg list is a memory device that has been used for thousands of years.
    
    For more information on peg lists and why they are useful for anyone, <a href="/what">read "What is a peg list"</a>.
    
    Peg list from Meta | ateM will let you record your peg list, and associate each peg with an image to help strengthen the association -- peg lists work best when your form pictures in your mind.
    
    If you're ready to get started -- log in at the top of the page with any "OpenID":http://en.wikipedia.org/wiki/OpenID address.
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
        text <<-HTML
          <script type="text/javascript" charset="utf-8">
          Event.observe('signup_username', 'keyup', function() {
            $('flickr_username').value = $('signup_username').value
            $('twitter_username').value = $('signup_username').value
          })            
          </script>
        HTML
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
              new Ajax.Request(url, {
                method: 'get',
                onSuccess: function(req) {
                  $('signup_avatar').value = req.responseText;
                  $('avatar_preview').src = req.responseText;
                }
              })
            }
          })
        </script>
        HTML
      end
      
      p do
        label 'Avatar url:', :for => 'signup_avatar'
        input :name => 'avatar_url', :type => 'text', :id => 'signup_avatar', :value => @new_user.avatar_url
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
            Event.observe(window, 'load', function() { if ($('login_openid').value != '') {$('login_openid').setStyle('zIndex', 3) }})
            Event.observe('login_openid_label', 'click', function() { $('login_openid').focus(); })
            Event.observe('login_openid', 'focus', function() { $('login_openid').setStyle({zIndex: 3}) })
            Event.observe('login_openid', 'blur', function() { if ($('login_openid').value == '') $('login_openid').setStyle({zIndex: 1}) })
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

if __FILE__ == $0
  Peglist::Models::Base.establish_connection :adapter => "sqlite3", :database => "/Users/kastner/.camping.db"
  Peglist::Models::Base.threaded_connections = false
  Mongrel::Camping::start("0.0.0.0",3301,"/",Peglist).run.join
end