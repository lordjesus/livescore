require 'rubygems'
require 'sinatra'
require 'sinatra/cross_origin'
require 'data_mapper'
require 'json' 
require 'date'

configure :development, :test do
    set :host, 'localhost:9999'
    set :force_ssl, false
  end
  configure :staging do
    set :host, 'snookerscore.herokuapp.com'
    set :force_ssl, true
  end
  configure :production do
    set :host, 'snookerscore.herokuapp.com'
    set :force_ssl, true
  end

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

	property :active,		Integer, :default => 0

	property :video_link,	String

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

	property :turn, 		Integer, :default => 0 # 0: player 1, 1: player 2

	belongs_to :match
end

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['admin', 'hjorring_open']
  end
end

register Sinatra::CrossOrigin

configure do
	enable :cross_origin
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
	protected!
	if params[:name]
		found = Player.first(:name => params[:name])
		if found
			redirect '/players/' + found.id.to_s
		else
			player = Player.new
			player.name = params[:name]
			if player.save
				status 201
				redirect '/players/' + player.id.to_s
			else
				status 412
				redirect '/players'
			end
		end
	else
		status 400
		'Must include querystring on the form ?name=z'
	end
end
# Update a player querystring on the form ?name=z
put '/players/:id' do
	protected!
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
	protected!
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

# Get all matches, querystring ?active=true only shows active matches, 
# querystring inactive=true only shows inactive matches
# ?fresh=i only shows matches that are at most i days old
get '/matches/admin' do
	@matches = Match.all
	erb :'matches/index'
end

get '/matches' do 

	active = params[:active]
	if active && (active.downcase == "true" || active.downcase == "t")
		@matches = Match.all(:active => 1)
	else
		inactive = params[:inactive]
		if inactive && (inactive.downcase == "true" || inactive.downcase == "t")
			@matches = Match.all(:active => 0)
		else
			@matches = Match.all
		end
	end
	fresh = params[:fresh]
	if fresh && (fresh.downcase == "true" || fresh.downcase == "t")
		fresh = fresh.to_i
		deadline = DateTime.now - fresh
		@matches = Match.all(:start_time.gt => deadline)
	end
	latest = params[:latest]
	if latest
		@matches = Match.all.last
	end

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

# Get specific match score: p1_score, p2_score, p1_frames, p2_frames
get '/matches/:id/score' do
	@match = Match.get(params[:id])
	if @match
		score = { :p1_score => @match.p1_score, :p2_score => @match.p2_score,
				  :p1_frames => @match.p1_frames, :p2_frames => @match.p2_frames,
				  :turn => -1 }

		if @match.results
			score[:turn] = @match.results.last.turn
		end

		content_type :json
		score.to_json
	else
		status 404
		'not found'
	end
end

# Get results of match, optional querystring ?latest=true only gets latest result
# ?break=true get results of latest break
get '/matches/:id/results' do
	@match = Match.get(params[:id])
	if @match
		latest = params[:latest]
		if latest && (latest.downcase == "true" || latest.downcase == "t")
			@results = @match.results.last 
		else
		#	br = params[:break]
		#	if br && (br.downcase == "true" || br.downcase == "t")
		#		r = @match.results.reverse
		#		if r.first.is_marker > 0 
		#			turn = r.first.turn
		#			@results = Array.new

		#	end
			@results = @match.results
		end
		content_type :json
		@results.to_json
	else
		status 404
		'match not found'
	end
end

get '/matches/latest' do
	@match = Match.all.last

	content_type :json
	@match.to_json
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
	protected!
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
	protected!
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

# Ends match. Optional querystring adjust=true to update frames to match with distance
post '/matches/:id/end' do
	protected!
	@match = Match.get(params[:id])
	if @match
		adjust = params[:adjust]
		if adjust && (adjust.downcase == "true" || adjust.downcase == "t")
			if @match.distance % 2 != 0
				win = @match.distance / 2 + 1
				if @match.p1_frames < win && @match.p2_frames < win
					# Only update if none has the required amount of frames
					if @match.p1_score > @match.p2_score
						@match.p1_frames = @match.p1_frames + 1
					else
						@match.p2_frames = @match.p2_frames + 1
					end
				end
			else
				# It's a group game, distance is even
				if @match.p1_frames < @match.distance && @match.p2_frames < @match.distance && 
					(@match.p1_frames + @match.p2_frames) < @match.distance
					# Only update if none has the required amount of frames
					if @match.p1_score > @match.p2_score
						@match.p1_frames = @match.p1_frames + 1
					else
						@match.p2_frames = @match.p2_frames + 1
					end
				end
			end
		end
		@match.active = 0
		@match.save

		status 200
		redirect "/matches/#{params[:id]}"
	else
		status 404
		'not found'
	end
end

# Add result to match with querystring ?p1_change=x&p2_change=y&is_marker=n&turn=t&frame=i
post '/matches/:id/results' do
	protected!
	@match = Match.get(params[:id])
	if @match
		p1 = 0
		p2 = 0
		marker = 0
		turn = 0;
		frame = 0;
		if params[:p1_change]
			p1 = params[:p1_change]
		end
		if params[:p2_change]
			p2 = params[:p2_change]
		end
		if params[:is_marker]
			marker = params[:is_marker]
		end
		if params[:turn]
			turn = params[:turn]
		end
		if params[:frame]
			frame = params[:frame]
		end

		@result = Result.new
		@result.p1_change = p1
		@result.p2_change = p2
		@result.is_marker = marker
		@result.turn = turn
		@result.frame = frame
		@result.match = @match

		if @result.save
			@match.active = 1
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

# Create new match with querystring ?p1=x&p2=y&distance=n&name=z&p1_score=x&p2_score=y&p1_frames=x&p2_frames=y 
# optional: &video_link=link
post '/matches/create' do
	protected!
	if (!params[:p1] || !params[:p2])
		status 400
		'Must include querystring on the form ?p1=x&p2=y&distance=n&name=z'
	else
		match = Match.new
		if params[:name]
			match.name = params[:name]
		end 
		if params[:video_link]
			match.video_link = params[:video_link]
		end
		
		match.p1_id = params[:p1]
		match.p2_id = params[:p2]
		match.start_time = DateTime.now

		if params[:distance]
			match.distance = params[:distance]
		end
		if params[:p1_score]
			match.p1_score = params[:p1_score]
		end
		if params[:p2_score]
			match.p2_score = params[:p2_score]
		end
		if params[:p1_frames]
			match.p1_frames = params[:p1_frames]
		end
		if params[:p2_frames]
			match.p2_frames = params[:p2_frames]
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
	protected!
	@match = Match.get(params[:id])
	if @match
		@results = @match.results
		@results.each do |r|
			r.destroy
		end
		@match.destroy
		redirect '/matches'
	else
		status 404
		'match not found'
	end
end

DataMapper.auto_upgrade!