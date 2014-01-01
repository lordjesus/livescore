require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'json'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

class Player
	include DataMapper::Resource

	property :id, 		Serial
	property :name, 	String
end

class Match
	include DataMapper::Resource

	property :id, 			Serial
	property :name, 		String
	
	property :distance,		Integer
	property :frame,		Integer, :default => 0
	property :start_time, 	DateTime, :default => DateTime.now 

	property :p1_id,		Integer
	property :p2_id, 		Integer

	property :p1_score,		Integer, :default => 0
	property :p2_score, 	Integer, :default => 0

	has n, :results
end

class Result
	include DataMapper::Resource

	property :id,			Serial
	property :created_at, 	DateTime, :default => DateTime.now 

	property :p1_change,	Integer, :default => 0
	property :p2_change,	Integer, :default => 0

	property :is_marker,	Boolean, :default => false

	belongs_to :match
end

DataMapper.auto_upgrade!