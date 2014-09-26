#!/usr/bin/ruby

require 'json'
require 'csv'
require 'faraday'

# Read configuration file
config = JSON.parse(File.read('config.json'), symbolize_names: true)

# Create conn to CitySDK LD API
conn = Faraday.new(url: "https://#{config[:endpoint][:hostname]}", ssl: {verify: false})

# Authenticate!
resp = conn.get "/session?name=#{config[:endpoint][:owner]}&password=#{config[:endpoint][:password]}"
if resp.status.between? 200, 299
  json = JSON.parse resp.body, symbolize_names: true
  if json[:type] == 'FeatureCollection' and json[:features][0] and json[:features][0][:properties][:session_key]
    conn.headers['X-Auth'] = json[:features][0][:properties][:session_key]
  else
    raise Exception.new 'Invalid credentials'
  end
else
  raise Exception.new resp.body
end

def write_objects(conn, layer, objects)
  geojson = {
    type: 'FeatureCollection',
    features: objects
  }
  resp = conn.post do |req|
    req.url "/layers/#{layer}/objects"
    req.headers['Content-Type'] = 'application/json'
    req.body = geojson.to_json
  end
  if resp.status != 201
    puts resp.inspect
  end
  resp
end

# Read CSV files in data directory
Dir.glob('data/*.csv') do |csv_file|
  basename = File.basename(csv_file, '.*')
  layer_name = "#{config[:data][:layer_prefix]}.#{basename}"

  layer = config[:layer]
  layer[:name] = layer_name
  layer[:owner] = config[:endpoint][:owner]

  # Delete existing layer
  resp = conn.delete "/layers/#{layer_name}"
  unless [204, 404].include? resp.status
    puts "Error deleting layer '#{layer_name}'"
    exit
  end

  # Create new, empty layer
  resp = conn.post do |req|
    req.url '/layers'
    req.headers['Content-Type'] = 'application/json'
    req.body = layer.to_json
  end
  if resp.status != 201
    puts "Error creating layer '#{layer_name}'"
    exit
  end

  if ARGV.length == 0 or (ARGV.length > 0 and ARGV.include? basename) then
    puts "Reading #{csv_file}..."

    objects = []
    count = 0

    CSV.foreach(csv_file, headers: true) do |row|

      # Create key/values for object's data hash
      non_data_fields = ['id', 'title', 'lat', 'lon']
      data = {}
      row.headers.each do |header|
        unless non_data_fields.include? header
          data[header] = row[header]
        end
      end

      # Create GeoJSON feature
      objects << {
        type: 'Feature',
        properties: {
          id: row['id'],
          title: row['title'],
          data: data
        },
        geometry: {
          type: 'Point',
          coordinates: [row['lon'], row['lat']]
        }
      }

      if objects.length >= config[:data][:batch_size]
        resp = write_objects conn, layer_name, objects
        count += batch_size
        objects = []
      end
    end
    write_objects conn, layer_name, objects if objects.length > 0
  end
end

puts "Done..."