# Funa module: A HTTP Client
require "http/client"
require "http/headers"
require "uri"
require "json"
require "./multipart"
require "./cookies"

# Module Funa
module Funa
  extend self

  # Funa HTTP Client class
  class FunaClient
    @savePath = ""
    @conf = Hash(String, String).new
    @uri = URI.new("http", "localhost")
    @cookies = FunaCookies.new

    # コンストラクタ
    def initialize()
      # コマンド引数がないときはヘルプを表示して終了。
      if ARGV.size() == 0
        STDERR.puts("Usage: funa URL [savePath] or funa @file.json [savePath]")
        exit 1
      end
      # 第二コマンド引数があれば、保存先ファイルとみなす。
      if ARGV.size > 1
        @savePath = ARGV[1]
      end
      # 第一コマンド引数の先頭が @ ならリクエストファイルとみなす。
      if ARGV[0].starts_with?("@")
        @conf = readConf(ARGV[0][1..])  # ARGV[0] はリクエストファイル
        # リクエストファイルの情報から URI を作成する。
        @uri = URI.new(scheme: @conf["scheme"], host: @conf["host"], port: @conf["port"].to_i32, path: @conf["path"], query: @conf["query"])
        # リクエストファイルの情報からクライアントからサーバへ送るリクエストヘッダを作成する。
        request_headers = to_headers(@conf["headers"], @conf["content_type"])
        # HTTP クライアントを作成する。
        client = HTTP::Client.new(@uri)
        # メソッド別の処理
        case @conf["method"]
        when "GET"
          response = HTTP::Client.get(@uri, request_headers)  # GET リクエスト
        when "POST"
          postdata = get_body()  # ポストする body データを作成する。
          content_type = @conf["content_type"]
          if @conf["content_type"].starts_with?("multipart") # マルチパートフォームの場合は境界を追加する。
            content_type += "; boundary=#{BOUNDARY}"
            request_headers["content-type"] = content_type
          end
          #p! request_headers
          response = HTTP::Client.post(@uri, request_headers, postdata)  # POST リクエスト
        when "HEAD"
          response = HTTP::Client.head(@uri, request_headers)  # HEAD リクエスト
        else
          STDERR.puts "Error: not supported."
          exit 1
        end
      else
        # 第一コマンド引数の先頭が @ でない場合は URL とみなして GET リクエストを行う。
        url = ARGV[0]  # ARGV[0] must be URL
        response = HTTP::Client.get(url)
      end
      # クッキーがあれば、cookies.json を更新する。
      updateCookies(response)
      # レスポンスを表示する。
      printResponse(response)
    end

    # リクエストファイル @file.json を読む。
    def readConf(filepath) : Hash(String, String)
      s = File.read(filepath)
      h = Hash(String, String).from_json(s)
      return h
    end

    # クッキーがあれば、cookies.json を更新する。
    def updateCookies(response)
      response.headers.each do |header|
        hkey = header[0]
        hval = header[1][0]
        if hkey == "Set-Cookie"  # ヘッダ行の名前が Set-Cookie なら
           name = hval[0 .. hval.index("=").as(Int32) - 1]
           value = hval[hval.index("=").as(Int32) + 1 ..]
           parts = value.split("; ")
           value = parts[0]
           if parts.size > 1
             parts2 = parts[1].split("=")
             expires = parts2[1]
             @cookies.add(name, value, Time.parse_local(expires, "%a, %d %b %Y %H:%M:%S %Z"))
           else
             value = parts[1]
             @cookies.add(name, value)
           end
        end
        @cookies.save_cookies(@conf["host"])
      end
    end

    # リクエストファイル (file.json) の headers とcontent_type 行を HTTP::Headers に変換する。
    def to_headers(srcline : String, content_type : String) : HTTP::Headers
      headers = HTTP::Headers.new
      headers["content-type"] = content_type  # content-type を HTTP::Headers に追加
      # リクエストファイルの headers 行をカンマで分解する。
      parts = srcline.split(", ")
      # リクエストファイルの headers 行の各部分を = で分割して、それをキーと値みなして HTTP::Headers に追加する。
      parts.each do |x|
        y = x.split("=")
        key = y[0].strip
        value = y[1].strip
        if ! headers.has_key?(key)  # キー が HTTP::Headers に含まれていない場合は値として空の配列を用意する。
          headers[key] = Array(String).new
        end
        headers[key] = value
      end
      # cookie.json ファイルからクッキー情報を追加する。
      headers["cookie"] = @cookies.to_s
      return headers
    end

    # サーバから受信したレスポンス情報を表示する。
    def printResponse(response : HTTP::Client::Response)
      puts "-------------- Status ------------------------------"
      puts response.status  # ステータス (HTTP::Status)
      puts "-------------- Response Headers    -----------------"
      # レスポンスヘッダ
      response.headers.each do |key, arr|
        arr.each do |value|
          puts key + ": " + value
        end
      end
      # レスポンス本体
      if @savePath == ""
        puts "-------------- Response Body -----------------------"
        puts response.body
        puts "-------------- End of Body -------------------------"
      else
        # コマンドの第二引数がある場合、それを保存先のファイルとしてレスポンス本体をファイル保存する。
        File.write(@savePath, response.body)
        puts "-------------- Response Body -----------------------"
        puts "The response body was stored to the file '#{@savePath}'."
        puts "-------------- End of Body -------------------------"
      end
    end

    # リクエストファイルの body 行の内容をハッシュに変換する。
    def from_body_to_hash(body : String) : Hash(String, String)
      hash = Hash(String, String).new
      parts = body.split(", ") # body 行を ", " で分割する。
      if parts.size >= 2
        # 分割された各部分について送り返す。
        parts.each do |s|
          # その各部分を = で分割してキーと値としてハッシュに格納する。
          parts2 = s.split("=")
          name = parts2[0].strip
          value = parts2[1].strip
          hash[name] = value
        end
      else
        # カンマが含まれないとき
        parts3 = body.split("=")  # = で body 全体を分割する。
        if parts.size < 2
          # = が含まれないとき
          hash["body"] = body
        else
          hash[parts3[0].strip] = parts3[1].strip  # 分割後の２つの値をキーと値としてハッシュに格納する。
        end
      end
      return hash
    end

    # クライアント側のリクエストボディ本体を作成する。
    def get_body() : HTTP::Client::BodyType # Alias BodyType is IO | Slice(UInt8) | String | Nil.
      if @conf["method"] != "POST" || @conf.has_key?("body") == false
        return ""
      end
     # リクエストファイルの body 行の内容をハッシュに変換する。
      hashbody : Hash(String, String) = from_body_to_hash(@conf["body"])
      body = ""
      sb = String::Builder.new
      # content-type 別の処理
      case @conf["content_type"]
      when "application/x-www-form-urlencoded" then
        # 普通のフォームデータ
        i = 0
        hashbody.each do |k, v|
          sb << (k + "=" + v)
          if i < hashbody.size - 1
            sb << "&"
          end
          i += 1
        end
        body = sb.to_s
        body = body[0 .. body.size - 1]
      when "multipart/form-data" then
        # マルチパートフォームデータ
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
        body = @conf["body"]
        # body 内容がファイルパスならファイル内容を body とする。(そうでない場合は、body をデータ内容としてそのまま使う)
        if File.exists?(body)
          body = File.read(body)
        end
      else
        raise Exception.new("bad content_type.")
      end
      return body
    end

    # リクエストファイルの body 内容をマルチパートフォームデータに変換する。
    def get_mpdata() : String
      bodysrc = @conf["body"]
      # MultipartData クラスをインスタンス化する。
      mdata = MultipartData.new
      # リクエストファイルの body 内容を ", " で分割する。
      parts = bodysrc.split(", ")
      # その分割した部分ごとに処理する。
      parts.each do |s|
        # その部分に "filename=" が含まれる場合、type="file" コントロールとみなす。
        n = s.index("filename=")
        if !n.nil? && n.as(Int32) > 0
          parts = s.split("; ")  # "; "で分割する。
          parts1 = parts[0].strip.split("=")
          if parts1[0] == "name"
            # name=... の場合
            name = parts1[1]
            parts2 = parts[1].split("=")
            if parts2[0] == "filename"  # "; " で分割した２番目の部分の先頭が "filename=" である場合
              filepath = parts2[1]
              mdata.add_file(name, filepath)  # file=...の値がファイルパスとして name とともに mdata に追加する。
            else
              # "filename=" 以外である場合、エラーとする。
              raise Exception.new("Body has no filename.")
            end
          else
            # "name=" がない場合はエラー
            raise Exception.new("Body has no name.")
          end
        else
          # type="file" コントロール でない場合
          parts2 = s.split("=")
          name = parts2[0]
          value = parts2[1]
          mdata.add_item(name, value)  # mdata に name と value を追加する。
        end
      end
      return mdata.to_s  # mdata を文字列に変換して関数値として返す。
    end

  end # of class
end # of module
