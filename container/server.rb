require 'base64'
require 'digest/sha1'
require 'google/cloud/storage'
require 'google/cloud/monitoring'
require 'json'
require 'sinatra'
require 'uri'

set :bind, '0.0.0.0'
set :port, ENV['PORT']

def short_code(url)
  # Create short code key as substitute URL
  Base64.encode64(Digest::SHA1.hexdigest(url))[22..27]
end

def stackdriver_create(name, description)
  # Create Stackdriver metric descriptor
  client = Google::Cloud::Monitoring::Metric.new
  project_name = Google::Cloud::Monitoring::V3::MetricServiceClient.project_path ENV['PROJECT']

  descriptor = Google::Api::MetricDescriptor.new(
    type:        "custom.googleapis.com/#{name}",
    metric_kind: Google::Api::MetricDescriptor::MetricKind::CUMULATIVE,
    value_type:  Google::Api::MetricDescriptor::ValueType::INT64,
    description: description
  )

  result = client.create_metric_descriptor  project_name, descriptor
end

def stackdriver_increment(name)
  # Publish metric data to Stackdriver
  client = Google::Cloud::Monitoring::Metric.new
  project_name = Google::Cloud::Monitoring::V3::MetricServiceClient.project_path ENV['PROJECT']

  series = Google::Monitoring::V3::TimeSeries.new
  metric = Google::Api::Metric.new type: "custom.googleapis.com/#{name}"
  series.metric = metric

  resource = Google::Api::MonitoredResource.new type: "run_service"
  resource.labels["service_name"] = "urly-wurly"
  series.resource = resource

  point = Google::Monitoring::V3::Point.new
  point.value = Google::Monitoring::V3::TypedValue.new int64_value: 1
  now = Time.now
  end_time = Google::Protobuf::Timestamp.new seconds: now.to_i, nanos: now.usec
  point.interval = Google::Monitoring::V3::TimeInterval.new end_time: end_time
  series.points << point

  client.create_time_series project_name, [series]
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
  begin 
    stackdriver_create('shortening-invocation-web', 'some BS i made up')
  end
  stackdriver_increment('shortening-invocation-web')

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
