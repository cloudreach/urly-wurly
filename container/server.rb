require 'adler32'
require 'json'
require 'google/cloud/storage'
require 'sinatra'

set :bind, '0.0.0.0'
set :port, ENV["PORT"]

get '/' do 
  File.read(File.join('public', 'index.html'))
end

get '/s' do
  return "no url to shorten supplied!" unless params['url']
  domain = ENV['DOMAIN']
  full_url = params['url'].gsub(/\A"|"\Z/, '').gsub(/\A'|'\Z/, '')
  hash = Adler32.checksum full_url
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket 'urly-wurly-links'
  bucket.create_file StringIO.new(full_url), hash
  {
    shortened_url: "https://#{domain}/l/#{hash}"
  }.to_json 
end

get '/l/:hash' do
  hash = params[:hash]
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket 'urly-wurly-links'
  file = bucket.file hash
  return "link not found!" unless file
  content = file.download
  content.rewind
  status 301
  response['Location'] = content.read
end
