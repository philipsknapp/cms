require "bundler/setup"
require "sinatra"
require "sinatra/reloader"
# require "sinatra/content_for" -> not sure we need this yet
require "tilt/erubis"
require "redcarpet"

before do
  @contents = retrieve_files(contents_path)
end

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

get "/" do
  erb :index, layout: :layout
end

get "/new" do
  erb :new, layout: :layout
end

get "/users/signin" do
  erb :sign_in, layout: :layout
end

get "/:filename" do
  @filename = params[:filename]
  if existing_file?(@filename)
    file_path = File.join(contents_path, @filename)
    extension = file_path.split(".").last
      case extension
      when "txt"
        file_text = File.read(file_path)
        headers["Content-Type"] = "text/plain"
        file_text
      when "md"
        markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
        file_html = markdown.render(File.read(file_path))
        headers["Content-Type"] = "text/html"
        erb file_html, layout: :layout
      end
  else
    session[:message] = "#{@filename} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  @filename = params[:filename]
  if existing_file?(@filename)
    file_path = File.join(contents_path, @filename)
    extension = file_path.split(".").last
      case extension
      when "txt"
        @file_text = File.read(file_path)
      when "md"
        @file_text = File.read(file_path)
      end
    erb :edit, layout: :layout
  else
    session[:message] = "#{@filename} does not exist."
    redirect "/"
  end
end

post "/new" do
  if valid_filename?(params[:new_filename])
    @filename = params[:new_filename]
    file_path = File.join(contents_path, @filename)
    File.new(file_path, "w")
    session[:message] = "#{@filename} was created."
    redirect "/"
  else
    session[:message] = "A name is required."
    redirect "/new"
  end
end

post "/users/signin" do
  username = params[:username]
  password = params[:password]
  if valid_login?(username, password)
    session[:message] = "Welcome!"
    session[:user] = username
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    session[:invalid_username] = username
    redirect "/users/signin"
  end
end

post "/users/signout" do
  session[:user] = nil
  session[:message] = "You have been signed out."
  redirect "/"
end

post "/:filename/delete" do
  @filename = params[:filename]
  file_path = File.join(contents_path, @filename)
  File.delete(file_path)
  session[:message] = "#{@filename} has been deleted."
  redirect "/"
end

post "/:filename/edit" do
  @filename = params[:filename]
  file_path = File.join(contents_path, @filename)
  File.write(file_path, params[:file_content])
  session[:message] = "#{@filename} has been updated."
  redirect "/"
end

def contents_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/contents", __FILE__)
  else
    File.expand_path("../contents", __FILE__)
  end
end

def retrieve_files(filepath)
  Dir.entries(filepath).select { |filename| filename.match?(/\w/) }
end

def existing_file?(filename)
  @contents.include?(filename)
end

def valid_filename?(filename)
  filename.strip != ""
end

def valid_login?(username, password)
  username == "admin" && password == "secret"
end
