require 'sqlite3'

class Seeder

def self.seed!
    drop_tables
    create_tables
end

def self.db
    if @db == nil
        @db = SQLite3::Database.new('./db/db.sqlite')
        @db.results_as_hash = true
    end
    return @db
end

def self.drop_tables
    db.execute('DROP TABLE IF EXISTS people')
    db.execute('DROP TABLE IF EXISTS users')
    db.execute('DROP TABLE IF EXISTS ratings')
end

def self.create_tables
    db.execute('CREATE TABLE people(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        filepath TEXT NOT NULL
    )')
    db.execute('CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        password TEXT NOT NULL
    )')
    db.execute('CREATE TABLE ratings(
        person_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        pos_rating INTEGER NOT NULL,
        neg_rating INTEGER NOT NULL,
        avg_rating FLOAT NOT NULL,
        PRIMARY KEY (person_id, user_id)
        )')
end

end