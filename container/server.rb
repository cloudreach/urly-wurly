require 'sinatra'

set :bind, '0.0.0.0'
set :port, ENV["PORT"]

get '/' do
  "I am running on Cloud Run!"
end
