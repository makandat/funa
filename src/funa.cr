# Funa module: A HTTP Client
require "http/client"
require "http/headers"
require "uri"
require "json"

# Module Funa
module Funa
  extend self
  VERSION = "0.2.2"
  BOUNDARY = "------------------funa_boundary"
  COOKIES_FILE = "cookies.json"

  # Funa HTTP Client class
  class FunaClient
    @savePath = ""
    @conf = Hash(String, String).new
    @uri = URI.new("http", "localhost")
    
    # constructor
    def initialize()
      if ARGV.size() == 0
        STDERR.puts("Usage: funa URL [savePath] or funa @file.json [savePath]")
        exit 1
      end
      if ARGV.size > 1
        @savePath = ARGV[1]
      end
      if ARGV[0].starts_with?("@")
        @conf = readConf(ARGV[0][1..])  # ARGV[0] must be config file
        @uri = URI.new(scheme: @conf["scheme"], host: @conf["host"], port: @conf["port"].to_i32, path: @conf["path"], query: @conf["query"])
        client = HTTP::Client.new(@uri)
        case @conf["method"]
        when "GET"
          response = HTTP::Client.get(@uri, to_headers(@conf["headers"]))
        when "POST"
          postdata = get_body()
          response = HTTP::Client.post(@uri, headers: to_headers(@conf["headers"], body:postdata))
        when "HEAD"
          response = HTTP::Client.head(@uri, to_headers(@conf["headers"]))
        else
          STDERR.puts "Error: not supported."
          exit 1
        end
      else
        url = ARGV[0]  # ARGV[0] must be URL
        response = HTTP::Client.get(url)
      end
      printResponse(response)
    end
    
    # read @file.json
    def readConf(filepath) : Hash(String, String)
      s = File.read(filepath)
      h = Hash(String, String).from_json(s)
      return h
    end
    
    # Add String to Headers
    def to_headers(s : String, body : HTTP::Client::BodyType = nil) : HTTP::Headers
      headers = HTTP::Headers.new
      parts = s.split(",")
      parts.each do |x|
        y = x.split(":")
        key = y[0].strip
        value = y[1].strip
        if ! headers.has_key?(key)
          headers[key] = Array(String).new
        end
        headers[key] = value
      end
      return headers
    end
    
    # print response data
    def printResponse(response : HTTP::Client::Response)
      puts "-------------- Status ------------------------------"
      puts response.status
      puts "-------------- Response Headers    -----------------"
      response.headers.each do |key, arr|
        arr.each do |value|
          puts key + ": " + value
        end
      end
      if @savePath == ""
        puts "-------------- Response Body -----------------------"
        puts response.body
        puts "-------------- End of Body -------------------------"
      else
        File.write(@savePath, response.body)
        puts "-------------- Response Body -----------------------"
        puts "The response body was stored to the file '#{@savePath}'."
        puts "-------------- End of Body -------------------------"
      end
    end
    
    # From body to Hash(String, String)
    def from_body_to_hash(body : String) : Hash(String, String)
      hash = Hash(String, String).new
      parts = body.split(", ")
      parts.each do |s|
        parts2 = s.split("=")
        hash[parts2[0]] = parts2[1]
      end
      return hash
    end
    
    # Make body data
    def get_body() : HTTP::Client::BodyType # Alias BodyType is IO | Slice(UInt8) | String | Nil.
      if @conf["method"] != "POST" || @conf.has_key?("body") == false
        return ""
      end
      hashbody : Hash(String, String) = from_body_to_hash(@conf["body"])
      body = ""
      sb = String::Builder.new
      case @conf["content_type"]
      when "application/x-www-form-urlencoded" then
        # Normal form data
        hashbody.each do |k, v|
          sb << (k + "=" + v)
          sb << "&"
        end
        body = sb.to_s
        body = body[0 .. body.size - 1]
      when "multipart/form-data;" + BOUNDARY then
        # Multipart form data
        body = get_mpdata()
      when "application/json" then
        # JSON
        body = @conf["body"]
      when "application/xml" then
        # XML
        body = "<data>"
        hashbody.each do |k, v|
          body += %(<#{k}>)
          body += %(<#{v}>)
          body += %(</#{k}>)
        end
        body += "</data>"
      when "application/octed-stream" then
        # BLOB / ArrayBuffer
        if File.exists?(@conf["body"])
          body = File.read(@conf["body"])
        end
      else
        raise Exception.new("bad content_type.")
      end
      return body
    end

    # get multipart form data
    def get_mpdata() : String
      bodysrc = @conf["body"]
      mdata = MultipartData.new
      parts : Array(String) = bodysrc.split(", ")
      parts.each do |s|
        n = s.index("filename=")
        if !n.nil? && n.as(Int32) > 0
          parts = s.split("; ")
          parts1 = parts[0].split("=")
          if parts1[0] == "name"
            parts2 = parts1[1].split("; ")
            if parts2[0] == "filename"
              mdata.add_file(parts1[1], parts2[1])
            else
              raise Exception.new("Body has no filename.")
            end
          else
            raise Exception.new("Body has no name.")
          end
        else
          parts1 = s.split("=")
          if parts1.size == 2
            mdata.add_item(parts1[0], parts1[1])
          else
            raise Exception.new("Bad body data.")
          end
        end
      end
      return mdata.to_s
    end
        
    # Add cookies to headers (Class method)
    def self.add_cookies(headers : HTTP::Headers) : HTTP::Headers
      if File.exists?(COOKIES_FILE)
        s = File.read(COOKIES_FILE)
        cookies = Hash(String, String).from_json(s)
        cookies.each do |kv|
          cookie_name = kv[0]
          cookie_value = kv[1]
          p1 = cookie_value.index("Expires=")
          p2 = cookie_value.index("Max-Age=")
          if !p1.nil? && p1 > 0
            q = cookie_value[p1 ..].index(";")
            expire = cookie_value[p1 + "Expires=".size .. q]
            parts = expire.split(" ")
            a = parts[0]
            parts[0] = parts[1]
            parts[1] = a
            expire = parts.join(" ")
            expire_t = Time::Format::HTTP_DATE.parse(expire)
            if expire_t > Time.utc
              cookies[cookie_name] = cookie_value
            end
          elsif !p2.nil? && p2 > 0
            q = cookie_value[p2 ..].index(";")
            max_age = cookie_value[p2 + "Max-Age=".size .. q]
            max_age_n = max_age.to_i32()
            if max_age_n > 0
              cookies[cookie_name] = cookie_value
            end
          else
            cookies[cookie_name] = cookie_value
          end
        end
        headers["cookie"] = cookies.to_s()
       end
      return headers
    end
  end # of class

  # Multipart/Form-Data class
  class MultipartData
    # constructor
    def initialize(border : String = BOUNDARY)
      @border = "--" + border
      @mdata = [] of String
    end

    # add form control data
    def add_item(name : String, value : String)
      s = @border + "\n"
      s += %(Content-Disposition: form-data; name="#{name}"\n\n)
      s += value + "\n"
      @mdata.push(s)
    end

    # add file control data
    def add_file(name : String, filepath : String)
      filename = File.basename(filepath)
      s = @border + "\n"
      s += %(Content-Disposition: form-data; name="#{name}"; filename="#{filename}"\n)
      s += %(Content-Type: application/octet-stream\n\n)
      fdata = File.read(filename)
      s += fdata + "\n"
      @mdata.push(s)
    end

    # add blob / arrayBuffer data
    def add_blob(name : String, data : Slice(UInt8))
      s = @border + "\n"
      s += %(Content-Disposition: form-data; name="#{name}"\n)
      s += %(Content-Type: application/octed-stream\n\n)
      s += data.to_s + "\n"
      @mdata.push(s)
    end

    # serialize form data
    def to_s()
      s = ""
      @mdata.each do |x|
        s += x
      end
      s += @border + "--\n"
    end

  end # of class
  
  # main
  def main()
    puts "<< Funa HTTP Client " + VERSION + " >>"
    begin
      client = FunaClient.new
    rescue e
      puts e.message
    end
  end

  # Test multipart/form-data  
  def test_multipart(n = 0)
    o = MultipartData.new
    case n
    when 0
      o.add_item("text1", "TEXT1")
      o.add_item("check1", "C1")
      o.add_item("check2", "")
      p o.to_s
    when 1
      o.add_item("text1", "TEXT1")
      o.add_file("file1", "./cookies.json")
      p o.to_s
    when 2
      o.add_item("text1", "TEXT1")
      data = Slice(UInt8).new(5)
      data.fill(0x45)
      o.add_blob("blob1", data)
      p o.to_s    
    else
      o.add_item("text1", "TEXT1")
      o.add_item("text2", "TEXT2")
      o.add_item("check1", "C1")
      o.add_item("check2", "")
      p o.to_s   
    end
  end

  # Test cookies
  def test_cookie()
    headers = HTTP::Headers.new
    headers["accept"] = "text/html"
    headers = FunaClient.add_cookies(headers)
    headers.each do |kv|
      name = kv[0]
      value = kv[1]
      puts name + "=>" + value.to_s
    end
  end

end # of Module

# start
Funa.main()
#Funa.test_multipart(2)
#Funa.test_cookie()
