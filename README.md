# citysdk-ld-csv-import-script

Simple Ruby script to import a directory with CSV files, and write each file's contents to a new layer in the CitySDK LD API.

The script will read the contents of all the CSV files in the `data` directory, create a new, empty layer names `<layer_prefix>.<filename_without_extension` (e.g. `lampposts.amsterdam`).

The script requires that you install the `faraday` gem:

    $ gem install faraday

## CSV files

Required fields per file:

- `id` - ID, must be unique per CSV file
- `title` - Title
- `lat` - Latitude
- `lon` - Longitude

Any other fields will be stored in the object's key/value data.

## Configuration

First, copy the contents of `config.example.json` to a new file `config.json`.

    endpoint:
      hostname: <hostname of CitySDK LD server>
      owner:    <owner, with permissions to create layers in layer_prefix domain>
      password: <password>
    data:
      layer_prefix: <for each file in data dir, new layer will be created with name layer_prefix.filename>
      batch_size:   <amount of rows from CVS file written to CitySDK LD API per request>
    layer: <CitySDK Layer object, to be used to layer creation>

## Usage

Import all CSV files in the `data` directory :

    $ ./import.rb

Import a subset of the CSV files in the `data` directory, `a.csv`, `b.csv`, `c.csv`, ...:

    $ ./import.rb [a, b, c, ...]