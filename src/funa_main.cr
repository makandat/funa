# funa_main.cr
require "./funa.cr"

VERSION = "0.3.5"

# main
def main()
  puts "<< Funa HTTP Client " + VERSION + " >>"
  begin
    client = Funa::FunaClient.new
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

# start
main()
