require 'digest/sha1'
require 'base64'
require 'json'
require 'google/cloud/storage'
require 'sinatra'
require 'uri'

set :bind, '0.0.0.0'
set :port, ENV["PORT"]

def short_code(url)
  return Base64.encode64(Digest::SHA1.hexdigest(url))[22..27]
end

def gcs_write(key, content)
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket 'urly-wurly-links'
  bucket.create_file StringIO.new(content), key
end

def gcs_read(key)
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket 'urly-wurly-links'
  bucket.file hash
end

get '/' do 
  File.read(File.join('public', 'index.html'))
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

  hash = short_code(full_url)
  gcs_write(hash, full_url)

  domain = ENV['DOMAIN']

  return {
    shortened_url: "https://#{domain}/l/#{hash}",
    message: "url shortened!"
  }.to_json
end

get '/l/:hash' do
  file = gcs_read(params['hash'])

  return {
      message: 'unable to find link!'
  } unless file

  content = file.download.rewind
  status 301
  response['Location'] = content.read
end

post '/slack' do 
  full_url = params['text'].strip
  full_uri = URI.parse(url)

  return {
    text: 'Error: provided input is not a HTTP/HTTPS URL!'
  }.to_json unless ['https', 'http'].include? full_uri.scheme

  hash = short_code full_url
  gcs_write(hash, full_url)

  domain = ENV['DOMAIN']
  response['Content-Type'] = 'application/json'

  return {
    text: "Shortened URL: https://#{domain}/l/#{hash}",
  }.to_json
end

