# funa

A HTTP client

## Installation

TODO: Write installation instructions here

## Usage

### run
* ./bin/funa URL
* ./bin/funa @request.json

### request.json
* method: string = "GET"
* hostname: string = "localhost"
* port: uint16 = 80
* path: string = ""
* query: string = ""
* content_type: string = ""
* content_length: uint32 = null
* version: string = "1.1"
* headers: array(string) = null
* cookies: array(string) = null
* body: string = ""
* multipart: bool = false

## Development

### build
  Enter "shards build" at funa folder .

## Contributing

1. Fork it (<https://github.com/makandat/funa/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [your-name-here](https://github.com/your-github-user) - creator and maintainer
