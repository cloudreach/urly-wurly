require 'base64'
require 'digest/sha1'
require 'google/cloud/storage'
require 'json'
require 'sinatra'
require 'uri'

set :bind, '0.0.0.0'
set :port, ENV['PORT']

def short_code(url)
  # Create short code key as substitute URL
  Base64.encode64(Digest::SHA1.hexdigest(url))[22..27]
end

def gcs_write(key, content)
  # Write string content to GCS object identified by key
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket ENV['BUCKET']
  bucket.create_file StringIO.new(content), key
end

def gcs_read(key)
  # Read object from GCS, identified by key
  storage = Google::Cloud::Storage.new project_id: ENV['PROJECT']
  bucket = storage.bucket ENV['BUCKET']
  bucket.file key
end

get '/' do
  # Root path, serving out static SPA
  File.read(File.join('public', 'index.html'))
end

get '/s' do
  # Endpoint to shorten a longer URL
  return {
    message: 'no url to shorten provided!'
  }.to_json unless params['url']

  # Trim ' and " chars from URL parameter
  full_url = params['url'].gsub(/\A"|"\Z/, '').gsub(/\A'|'\Z/, '')

  # Try parsing out required URL schemes
  full_uri = nil
  begin
    full_uri = URI.parse full_url
  rescue
    return {
      message: 'unable to parse URI. was it encoded?'
    }.to_json
  end
  return {
    message: 'provided input is not a HTTP/HTTPS URL!'
  }.to_json unless %w[https http].include? full_uri.scheme

  # Compute short code and persist
  shortcode = short_code full_url
  gcs_write(shortcode, full_url)

  # Construct new URL and respond
  domain = ENV['DOMAIN']
  response['Access-Control-Allow-Origin'] = '*'
  response['Content-Type'] = 'application/json'
  {
    shortened_url: "https://#{domain}/l/#{shortcode}",
    message: 'url shortened!'
  }.to_json
end

get '/l/:shortcode' do
  # Endpoint to reverse shortening
  file = gcs_read(params['shortcode'])

  # Unable to find persisted long URL for given code
  return { message: 'unable to find URL!' } unless file

  # Read object and reset scanner index
  content = file.download
  content.rewind

  # Set HTTP redirect
  status 301
  response['Location'] = content.read
end

post '/slack' do
  # Shorten URL via Slack
  return {
    message: 'no url to shorten provided!'
  }.to_json unless params['text']

  full_url = params['text'].strip

  # Try parsing out required URL schemes
  full_uri = nil
  begin
    full_uri = URI.parse full_url
  rescue
    return {
      message: 'unable to parse URI. was it encoded?'
    }.to_json
  end
  return {
    message: 'provided input is not a HTTP/HTTPS URL!'
  }.to_json unless %w[https http].include? full_uri.scheme

  # Compute short code and persist
  shortcode = short_code full_url
  gcs_write(shortcode, full_url)

  # Construct new URL and respond
  domain = ENV['DOMAIN']
  response['Content-Type'] = 'application/json'
  {
    text: "Shortened URL: https://#{domain}/l/#{shortcode}"
  }.to_json
end
