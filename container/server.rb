require 'adler32'
require 'json'
require 'google/cloud/storage'
require 'sinatra'
require 'uri'

set :bind, '0.0.0.0'
set :port, ENV["PORT"]

get '/' do 
  File.read(File.join('public', 'index.html'))
end

post '/slack' do 
  command = params['command']
  puts command
  full_url = command.sub('/wurly', '').strip 
  full_uri = URI.parse(url)

  return {
    text: 'Error: provided input is not a HTTP/HTTPS URL!'
  }.to_json unless ['https', 'http'].include? full_uri.scheme

  domain = ENV['DOMAIN']
  hash = Adler32.checksum full_url
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket 'urly-wurly-links'
  bucket.create_file StringIO.new(full_url), hash

  response['Content-Type'] = 'application/json'

  return {
    text: "Shortened URL: https://#{domain}/l/#{hash}",
  }.to_json
end

get '/s' do
  return {
      message: 'no url to shorten provided!',
  }.to_json unless params['url']

  full_url = params['url'].gsub(/\A"|"\Z/, '').gsub(/\A'|'\Z/, '')
  full_uri = URI.parse(full_url)

  return {
      message: 'provided input is not a HTTP/HTTPS URL!'
  }.to_json unless ['https', 'http'].include? full_uri.scheme

  domain = ENV['DOMAIN']
  hash = Adler32.checksum full_url
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket 'urly-wurly-links'
  bucket.create_file StringIO.new(full_url), hash
  return {
    shortened_url: "https://#{domain}/l/#{hash}",
    message: "url shortened!"
  }.to_json
end

get '/l/:hash' do
  hash = params[:hash]
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket 'urly-wurly-links'
  file = bucket.file hash
  return {
      message: 'unable to find link!'
  } unless file
  content = file.download
  content.rewind
  status 301
  response['Location'] = content.read
end
