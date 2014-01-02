require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'json' 

DataMapper.setup(:default, ENV['DATABASE_URL']) # || "sqlite3://#{Dir.pwd}/development.db")

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

	property :p1_frames,	Integer, :default => 0
	property :p2_frames, 	Integer, :default => 0

	has n, :results
end

class Result
	include DataMapper::Resource

	property :id,			Serial
	property :created_at, 	DateTime, :default => DateTime.now 

	property :p1_change,	Integer, :default => 0
	property :p2_change,	Integer, :default => 0

	property :is_marker,	Integer, :default => 0 # Used as boolean
	property :frame, 		Integer, :default => 0

	belongs_to :match
end

##############################################
############## P L A Y E R S #################
##############################################

# Get all players
get '/players' do
	@players = Player.all
	content_type :json
	@players.to_json
end

# Get specific player
get '/players/:id' do
	@player = Player.get(params[:id])
	content_type :json
	if @player
		content_type :json
		@player.to_json
	else
		status 404
		'not found'
	end
end

# Create player
post '/players/create' do
	if params[:name]
		player = Player.new
		player.name = params[:name]
		if player.save
			status 201
			redirect '/players/' + player.id.to_s
		else
			status 412
			redirect '/players'
		end
	else
		status 400
		'Must include querystring on the form ?name=z'
	end
end
# Update a player querystring on the form ?name=z
put '/players/:id' do
	if Player.get(params[:id])
		p = Player.get(params[:id])
		p.name = params[:name]
		if p.save
			status 201
			redirect '/players/' + p.id.to_s
		else
			status 412
			redirect '/players'
		end
	else
		status 404
		'not found'
	end
end

# Delete a player
delete '/players/:id' do
	if Player.get(params[:id])
		Player.get(params[:id]).destroy
		redirect '/players'
	else
		status 404
		'not found'
	end
end

##############################################
############## M A T C H E S #################
##############################################

# Get all matches
get '/matches' do 
	@matches = Match.all
	content_type :json
	@matches.to_json
end

# Get specific match
get '/matches/:id' do
	@match = Match.get(params[:id])
	if @match
		content_type :json
		@match.to_json
	else
		status 404
		'not found'
	end
end

# Get results of match
get '/matches/:id/results' do
	@match = Match.get(params[:id])
	if @match
		@results = @match.results
		content_type :json
		@results.to_json
	else
		status 404
		'match not found'
	end
end

get '/test/:id/t/:id2' do
	content_type :json
		params.to_json
end

get '/matches/:m_id/results/:r_id' do
	@match = Match.get(params[:m_id])
	if @match
		@result = Result.get(params[:r_id])
		if @result
			content_type :json
			@result.to_json
		else
			status 404
			'result not found'
		end
	else
		status 404
		'match not found'
	end
end

delete '/matches/:m_id/results/:r_id' do
	@match = Match.get(params[:m_id])
	if @match
		@result = Result.get(params[:r_id])
		if @result
			@result.destroy
			redirect "/matches/#{params[:id]}/results"
		end
	else
		status 404
		'match not found'
	end
end

# Starts new frame. Winner is highest score. Optional win parameter ?winner=[p1|p2]
post '/matches/:id/newframe' do
	@match = Match.get(params[:id])
	if @match
		winner = 'p1';
		if (params[:winner] && (params[:winner] == 'p1' || params[:winner] == 'p2'))
			if params[:winner] == 'p1'
				@match.p1_frames = @match.p1_frames + 1
			else
				@match.p2_frames = @match.p2_frames + 1
				winner = 'p2'
			end
		else
			if @match.p1_score > @match.p2_score
				@match.p1_frames = @match.p1_frames + 1
			else
				@match.p2_frames = @match.p2_frames + 1
				winner = 'p2'
			end
		end
		@match.p1_score = 0
		@match.p2_score = 0
		@match.save

		"Winner of frame is #{winner}"
	else
		status 404
		'not found'
	end
end

# Add result to match with querystring ?p1_change=x&p2_change=y&is_marker=n
post '/matches/:id/results' do
	@match = Match.get(params[:id])
	if @match
		p1 = 0
		p2 = 0
		marker = 0
		if params[:p1_change]
			p1 = params[:p1_change]
		end
		if params[:p2_change]
			p2 = params[:p2_change]
		end
		if params[:is_marker]
			marker = params[:is_marker]
		end

		@result = Result.new
		@result.p1_change = p1
		@result.p2_change = p2
		@result.is_marker = marker
		@result.match = @match

		if @result.save
			@match.p1_score = @match.p1_score + p1.to_i
			@match.p2_score = @match.p2_score + p2.to_i
			@match.save

			status 201
			redirect "/matches/#{params[:id]}/results/" + @result.id.to_s
		else 
			status 412
			redirect "/matches/#{params[:id]}/results"
		end		
	else
		status 404
		'not found'
	end
end

# Create new match with querystring ?p1=x&p2=y&distance=n&name=z
post '/matches/create' do
	if (!params[:p1] || !params[:p2])
		status 400
		'Must include querystring on the form ?p1=x&p2=y&distance=n&name=z'
	else
		match = Match.new
		if (params[:name])
			match.name = params[:name]
		end
		
		match.p1_id = params[:p1]
		match.p2_id = params[:p2]

		if (params[:distance])
			match.distance = params[:distance]
		end

		if match.save
			status 201
			redirect '/matches/' + match.id.to_s
		else
			status 412
			redirect '/matches'
		end
	end
end

# Delete a match and all it's results
delete '/matches/:id' do
	@match = Match.get(params[:id])
	if @match
		@results = @match.results
		@results.each do |r|
			r.destroy
		end
		@match.destroy
		'destroyed'
	else
		status 404
		'match not found'
	end
end

DataMapper.auto_upgrade!