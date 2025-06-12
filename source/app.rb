require 'sinatra'
require 'sinatra/flash'
require 'sqlite3'
require 'fileutils'
require 'bcrypt'
require 'zip'
require 'fileutils'
require_relative 'db/seed'

class App < Sinatra::Base
  enable :sessions
  register Sinatra::Flash

  # --- Utility Functions
  def db
    @db ||= SQLite3::Database.new('./db/db.sqlite').tap do |db|
      db.results_as_hash = true
    end
  end

  def next_id
    result = db.execute('SELECT id FROM people ORDER BY id DESC LIMIT 1').first
    result ? result['id'] + 1 : 1
  end

  def table_exists?(table_name)
    result = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", [table_name])
    !result.empty?
  end

  # --- Routes for managing people ---

  get '/manage' do
    if session[:user_id].nil?
        redirect '/login/login'
    end

    if !table_exists?('people')
      @db_content = "empty"
    else
        @db_content = db.execute("SELECT * FROM people")
    end
    erb :manage
  end

  get '/manager/default' do
    $type = "default"
    load './db/default.rb'
    flash[:success] = 'Database defaulted successfully'
    redirect '/manage'
  end

  get '/manager/delete-all' do
    $type = "delete"
    load './db/default.rb'
    redirect '/manage'
  end
  
   
  post '/manage/add-person' do

    uploadDir = './public/img/'
    if params['fileupload'] && params['fileupload']['tempfile'] && params['fileupload']['filename']
      file = params['fileupload']
      filename = "#{next_id}.png"
      tempfile = file['tempfile']
      name = params['name']

      filepath = File.join(uploadDir, filename)
      relpath = "/img/#{filename}"

      FileUtils.cp(tempfile.path, filepath)

      db.execute('INSERT INTO people (name, filepath) VALUES (?, ?)', [name, relpath])
      flash[:success] = "File uploaded successfully as #{filename}"
      redirect '/manage'
    else
      flash[:notice] = 'Failed to upload file: No file found'
      redirect '/manage'
    end
  end

  post '/manage/remove-person' do
    person_id = params['number']
    
    if person_id.nil? || person_id.empty?
      flash[:notice] = "Person ID is required."
      redirect '/manage'
    end
  
    person = db.execute('SELECT * FROM people WHERE id = ?', person_id).first
  
    if person
      filepath = File.join('public', person['filepath'])
      
      FileUtils.rm(filepath) if File.exist?(filepath)
      
      db.execute('DELETE FROM people WHERE id = ?', person_id)
      
      flash[:success] = "Person with ID #{person_id} successfully removed"
    else
      flash[:notice] = "Person with ID #{person_id} not found."
    end
  
    redirect '/manage'
  end
  


  post '/manage/upload' do

    print("\n\nZip bulk upload from user #{session[:user_id]} begun\n\n")
  
    if params[:zip_file].nil?
      flash[:notice] = "No file found"
      redirect '/manage'
    end
  
    if File.extname(params[:zip_file][:filename]) != '.zip'
      flash[:notice] = "Uploaded file is not a ZIP file"
      redirect '/manage'
    end
  
    temp_zip = params[:zip_file][:tempfile]
    print "Temporary ZIP file path: #{temp_zip.path}\n"
    print "Uploaded ZIP file details: #{params[:zip_file]}\n"
  
    upload_dir = 'public/uploads'
    extraction_dir = File.join(upload_dir, 'extracted')
    print "Upload directory: #{upload_dir}\n"
    print "Extraction directory: #{extraction_dir}\n"
  
    unzip_command = "unzip -o #{temp_zip.path} -d #{extraction_dir}"
    print "Running command: #{unzip_command}\n"
    system(unzip_command)
  
    if $?.exitstatus != 0
      flash[:notice] = "An error occurred while processing the ZIP file."
      redirect '/manage'
    end
  
    img_dir = 'public/img'
    current_id = next_id
    print "Starting ID for new entries: #{current_id}\n"
  
    Dir.glob(File.join(extraction_dir, '**', '*')).each do |file|
      next unless File.file?(file) # Skip directories and other non-file entries
  
      print "Processing file: #{file}\n"
      
      original_filename = File.basename(file, File.extname(file))
      extension = File.extname(file)
      new_filename = "#{current_id}#{extension}"
      relpath = "/img/#{new_filename}"
      filepath = File.join(img_dir, new_filename)
      
      print "Original filename: #{original_filename}\n"
      print "New filename: #{new_filename}\n"
      print "Saving file to: #{filepath}\n"
  
      FileUtils.mv(file, filepath)
      print "File moved and renamed to #{filepath}\n"
  
      db.execute("INSERT INTO people (name, filepath) VALUES (?, ?)", [original_filename, relpath])
      print "Database entry created for: Name #{original_filename}, Filepath #{relpath}\n"
  
      current_id += 1
    end
  
    print "ZIP file extraction and processing completed\n"
  
    redirect '/manage'
  end  
  
  # --- Routes for user authentication ---

  get '/login' do
    redirect '/login/login'
  end

  get '/logout' do
    session.clear
    
    flash[:success] = 'You have been logged out successfully'
    redirect '/login/login'
  end
  

  get '/login/:type' do |type|
    if session[:user_id]
      redirect("/")
    end
    @login = type
    erb :login
  end

  post '/login' do
    case params['user-value']
    when 'login'
      handle_login
    when 'register'
      handle_registration
    else
      flash[:notice] = 'Invalid action'
      redirect '/login/login'
    end
  end

  def handle_login
    user = db.execute('SELECT * FROM users WHERE username = ?', params['username']).first
    print("User is #{user}")
    if user.nil?
      flash[:notice] = 'Username not found'
      redirect '/login/login'
    end

    pass_encrpt = BCrypt::Password.new(user['password'])
    print("Comparing #{params['password']} to #{pass_encrpt}")
    if pass_encrpt == params['password'] 
        flash[:success] = "Logged in Successfully"
      session[:user_id] = user['id']
      redirect '/'
    else
      flash[:notice] = 'Password Incorrect'
      redirect '/login/login'
    end
  end

  def handle_registration
    if params['password'] != params['password-check']
      flash[:notice] = 'Password mismatch'
      redirect '/login/signup'
    end

    hashed_password = BCrypt::Password.create(params['password'])
    db.execute('INSERT INTO users (username, password) VALUES (?, ?)', [params['username'], hashed_password])
    redirect '/login/login'
  end

  # --- Routes for game functionality ---

  get '/game/:id' do |id|
    if session[:user_id].nil?
      redirect '/login/login'
    end
    if table_exists?('people')
      @people_db = db.execute('SELECT * FROM people')
      @game_id = id
      erb :game
    else
      redirect '/manage'
    end
  end

  post '/game' do
    game_id = params["game_id"]
    ansr = params['answer']
    imgid = params['img_id']
    user_id = session[:user_id]

    correct = db.execute('SELECT name FROM people WHERE id = ?', imgid).first['name']

    if ansr == correct
        flash[:notice] = 'Correct'
        adjust_rating(imgid, user_id, true)
    else
        flash[:notice] = "Incorrect, it should be #{correct}"
        adjust_rating(imgid, user_id, false)  
    end    

    redirect "/game/#{game_id}"
  end

  def adjust_rating(person_id, user_id, is_correct)
    
    existing_rating = db.execute('SELECT pos_rating, neg_rating FROM ratings WHERE person_id = ? AND user_id = ?', [person_id, user_id]).first

    if existing_rating
        pos_rating = existing_rating['pos_rating']
        neg_rating = existing_rating['neg_rating']

        if is_correct
        pos_rating += 1
        else
        neg_rating += 1
        end

        total_attempts = pos_rating + neg_rating
        avg_rating = ((pos_rating.to_f / total_attempts) * 10).round(1)

        print("Updated rating: Positive - #{pos_rating}, Negative - #{neg_rating}, Average - #{avg_rating}\n")
        db.execute('UPDATE ratings SET pos_rating = ?, neg_rating = ?, avg_rating = ? WHERE person_id = ? AND user_id = ?', [pos_rating, neg_rating, avg_rating, person_id, user_id])
    else
        pos_rating = is_correct ? 1 : 0
        neg_rating = is_correct ? 0 : 1
        avg_rating = is_correct ? 10.0 : 0.0

        print("Created new rating: Positive - #{pos_rating}, Negative - #{neg_rating}, Average - #{avg_rating}\n")
        db.execute('INSERT INTO ratings (person_id, user_id, pos_rating, neg_rating, avg_rating) VALUES (?, ?, ?, ?, ?)', [person_id, user_id, pos_rating, neg_rating, avg_rating])
    end
  end
  # --- Routes for profile management
  get '/profile' do
    if session[:user_id].nil?
      flash[:notice] = 'Please log in before accessing this page'
      redirect '/login/login'
    end

    if table_exists?("ratings")
      @people_rated = db.execute('SELECT * FROM ratings INNER JOIN people ON people.id = ratings.person_id WHERE user_id = ?', session[:user_id])
      erb :profile
    else
      flash[:notice] = "Database not found. Please default the database or contact administrator"
      redirect '/manage'
    end
  end

  post '/change-password' do
    current_password = params["current_password"]
    new_password = params["new_password"]
    new_password_confirm = params["confirm_password"]
    
    if current_password.nil? || new_password.nil? || new_password_confirm.nil?
      flash[:notice] = "All fields are required. Currently there is #{current_password}(Current), #{new_password}(New), #{new_password_confirm}(Confirm)"
      redirect '/profile'
    end

    if new_password != new_password_confirm
      flash[:notice] = 'New passwords do not match'
      redirect '/profile'
    end

    user = db.execute('SELECT * FROM users WHERE id = ?', session[:user_id]).first

    if user.nil?
      flash[:notice] = 'User not found with this ID. Contact admin'
      redirect '/'
    end

    pass_encrpt = BCrypt::Password.new(user['password'])
    if pass_encrpt != current_password
      flash[:notice] = 'Current password is incorrect'
      redirect '/profile'
    end

    hashed_password = BCrypt::Password.create(new_password)
    db.execute('UPDATE users SET password = ? WHERE id = ?', [hashed_password, session[:user_id]])

    flash[:success] = 'Password changed successfully'
    redirect '/profile'
  end

  # --- Miscellaneous ---

  get '/' do
    redirect session[:user_id] ? '/index' : '/login/login'
  end

  get '/index' do
    redirect '/login/login' if session[:user_id].nil?
    erb :index
  end

end