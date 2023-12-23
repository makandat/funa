# Multipart/Form-Data class
require "mime"

BOUNDARY = "------------------funa_boundary"

class MultipartData
    # constructor
    def initialize(border : String = BOUNDARY)
      @border = "--" + border
      @mdata = [] of String
    end

    # add form control data
    def add_item(name : String, value : String)
      s = @border + "\r\n"
      s += %(Content-Disposition: form-data; name="#{name}"\r\n\r\n)
      s += value + "\r\n"
      @mdata.push(s)
    end

    # add file control data
    def add_file(name : String, filepath : String)
      filename = File.basename(filepath)
      s = @border + "\r\n"
      s += %(Content-Disposition: form-data; name="#{name}"; filename="#{filename}"\r\n)
      mime = MIME.from_filename?(filepath)
      if mime.nil?
         mime = "application/octet-stream"
      end
      s += %(Content-Type: #{mime}\r\n\r\n)
      fdata = File.read(filepath)
      s += fdata + "\r\n"
      @mdata.push(s)
    end

    # add blob / arrayBuffer data
    def add_blob(name : String, data : Slice(UInt8))
      s = @border + "\r\n"
      s += %(Content-Disposition: form-data; name="#{name}"\r\n)
      s += %(Content-Type: application/octed-stream\r\n\r\n)
      s += data.to_s + "\r\n"
      @mdata.push(s)
    end

    # serialize form data
    def to_s()
      body = ""
      @mdata.each do |x|
        body += x
      end
      body += "#{@border}--\r\n"
      return body
    end
 
end # of class
