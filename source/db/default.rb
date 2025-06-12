require 'sqlite3'
require 'bundler'
Bundler.require
require_relative 'seed'

class Defaulter

  def self.db
      if @db == nil
          @db = SQLite3::Database.new('./db/db.sqlite')
          @db.results_as_hash = true
      end
      return @db
  end


  # FOR DEVELOPMENT
  def self.default
    print "DEFAULTING DATABASE...\n"
    self.remove
    self.create()
    print("DATABASE DEFAULTED\n")
  end

  def self.remove
    print "DELETING DATABASE\n"
    path = "./public/img"
    imgs = Dir.glob("#{path}/*.jpeg")
    imgs += Dir.glob("#{path}/*.png")
    imgs += Dir.glob("#{path}/*.jpg")
    print "IDENTIFIED #{imgs.length} IMAGES TO DELETE\n These are: #{imgs}\n"
    imgs.each do |img|
      FileUtils.rm(img)
    end
    db.execute("DROP TABLE IF EXISTS people")
    db.execute("DROP TABLE IF EXISTS ratings")
    print "DELETED FILES AND CLEARED DATABASE\n"
  end

  def self.create
    print "GENERATING DEFAULT SET\n"
    Seeder.seed!
    path = "./public/img/defaults"
    imgs = Dir.glob("#{path}/*.jpeg")
    print "IDENTIFIED #{imgs.length} DEFAULTS\n\n"
    people = []
    imgs.each do |img|
      name = File.basename(img, '.jpeg')
      FileUtils.cp(img, "./public/img/#{imgs.index(img)}.jpeg")
      people.append({name: "#{name}", filepath: "/img/#{imgs.index(img)}.jpeg"})
      print "Loaded #{name} as #{imgs.index(img)}\n"
    end

    people.each do |people|
        db.execute('INSERT INTO people (name, filepath) VALUES (?,?)', [people[:name], people[:filepath]])
    end
  end
end

if $type == "default"
  Defaulter.default
elsif $type == "delete"
  Defaulter.remove
end