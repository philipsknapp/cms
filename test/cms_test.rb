ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(contents_path)
  end

  def teardown
    FileUtils.rm_rf(contents_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def create_document(name, content = "", path = contents_path)
    File.open(File.join(path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<a href=\"/about.md\">about.md</a>"
    assert_includes last_response.body, "<a href=\"/changes.txt\">changes.txt</a>"
    assert_includes last_response.body, "<a href=\"/changes.txt/edit\""
    assert_includes last_response.body, "<a href=\"/new\">New Document</a>"
    assert_includes last_response.body, "<button>delete</button>"
    assert_includes last_response.body, "<a href=\"/users/signin\">Sign In</a>"
  end

  def test_txt_file
    create_document "history.txt", "Ruby 0.95 released"

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_md_file
    create_document "ruby.md", "<h1>Ruby is a ...</h1>"

    get "/ruby.md"
    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is a ...</h1>"
  end

  def test_invalid_filename
    create_document "about.md"
    create_document "changes.txt"

    get "/historyyyy.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<a href=\"/about.md\">about.md</a>"
    assert_includes last_response.body, "<a href=\"/changes.txt\">changes.txt</a>"
    assert_includes last_response.body, "does not exist"

    get "/"
    refute_includes last_response.body, "does not exist"
  end

  def test_edit_file
    create_document "test.txt"

    get "/test.txt/edit"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h2>Edit contents of test.txt</h2>"

    post "/test.txt/edit", {"file_content" => "test test test"}
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<a href=\"/test.txt\">test.txt</a>"
    assert_includes last_response.body, "test.txt has been updated."

    get "/"
    refute_includes last_response.body, "test.txt has been updated."

    get "/test.txt"
    assert_includes last_response.body, "test test test"
  end

  def test_new_file_page
    get "/new"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Add a new document:"
  end

  def test_new_file_valid
    post "/new", {"new_filename" => "test.txt"}
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<a href=\"/test.txt\">test.txt</a>"
    assert_includes last_response.body, "test.txt was created."
    assert File.exist?("#{contents_path}/test.txt")
  end

  def test_new_file_invalid
    post "/new", {"new_filename" => ""}
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "A name is required."
    assert_includes last_response.body, "Add a new document:"
  end

  def test_delete_file
    create_document "test.txt"
    post "/test.txt/delete"
    refute File.exist?("#{contents_path}/test.txt")
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been deleted."
    assert_includes last_response.body, "<a href=\"/new\">New Document</a>"
    refute_includes last_response.body, "<a href=\"/test.txt\">test.txt</a>"
  end

  def test_valid_signin
    get "/users/signin"
    assert_includes last_response.body, "<label for=\"username\">Username:</label>"
    
    post "/users/signin", {"username" => "admin", "password" => "secret"}
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Welcome!"
    assert_includes last_response.body, "Signed in as admin."
    refute_includes last_response.body, "<a href=\"/users/signin\">Sign In</a>"
    assert_includes last_response.body, "<button>Sign Out</button>"
    
    post "/users/signout"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "You have been signed out."
    refute_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "<a href=\"/users/signin\">Sign In</a>"
  end

  def test_invalid_signin
    post "/users/signin", {"username" => "admip", "password" => "secrep"}
    assert_equal 302, last_response.status
    assert_equal "Invalid Credentials", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, 
      "<input id=\"username\" type=\"text\" name=\"username\" value=\"admip\">"
  end
end
