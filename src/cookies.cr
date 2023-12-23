# cookies.cr
require "json"
require "http/cookie"

COOKIES_FILE = "cookies.json"

# FunaCookie
class FunaCookies
  @cookies : HTTP::Cookies  # クッキーのコレクション
  @current_host : String    # ホスト
  @headers : HTTP::Headers  # レスポンスヘッダ

  # コンストラクタ (1)
  def initialize()
    # クッキーファイルからクッキーを作成する。
    @current_host = ""
    @cookies = HTTP::Cookies.new
    @headers = HTTP::Headers.new
    if File.exists?(COOKIES_FILE) # cookies.json が存在するか？
      s = File.read(COOKIES_FILE) # ファイルが存在する場合、その内容を読み取る。
      file_cookies = Hash(String, String).from_json(s) # その内容を JSON としてハッシュに変換する。
      @cookies = to_cookies(file_cookies["cookies"])
    end
  end

  # コンストラクタ (2)
  def initialize(headers : HTTP::Headers)
    @headers = headers
    @cookies = HTTP::Cookies.new
    @current_host = ""
    if File.exists?(COOKIES_FILE) # cookies.json が存在するか？
      s = File.read(COOKIES_FILE) # ファイルが存在する場合、その内容を読み取る。
      file_cookies = Hash(String, String).from_json(s) # その内容を JSON としてハッシュに変換する。
      if !@headers.has_key?("set-cookie")
        # リクエストヘッダに "set-cookie" がない場合は cookies.json のデータだけをクッキーとする。
        @cookies = to_cookies(file_cookies["cookies"])
        return
      end
      @current_host = file_cookies["host"]  # cookies.json ファイルで定義されているホストを得る。
      new_host = ""
      if !@headers["host"]?.nil?
        new_host = @headers["host"]
        # レスポンスヘッダ内の host と cookies.json の host を比較する。
        if new_host != @current_host
          # 異なる場合は、ユーザに host が異なることを知らせる。(必要ならユーザが既存の cookies.json を上書きされないようにする)
          print %("The host has changed, the file "cookies.json" will be rewriten. if you need to keep the current "cookies.json", you have to change the name of "cookies.json". > )
          gets
          # 現在のホストを新しいものにする。
          @current_host = new_host
          @cookies = HTTP::Cookies.from_client_headers(@headers) # レスポンスヘッダを元にクッキーを更新する。
        else
          # ホストが同じ場合、cookies.json の内容をクッキーとする。
          @cookies = to_cookies(file_cookies["cookies"])
        end
      else
        # レスポンスヘッダに host がない場合も cookies.json の内容をクッキーとする。
        @cookies = to_cookies(file_cookies["cookies"])
      end
    else
      @cookies = HTTP::Cookies.new  # cookies.json が存在しないときは、空の HTTP::Cookies を作成する。
    end
  end

  # cookies.json のクッキー行を HTTP::Cookies に変換する。
  def to_cookies(s : String) : HTTP::Cookies
    @cookies = HTTP::Cookies.new
    cookielist = s.split(", ")  # ", " で分割して個別クッキーに分ける。
    cookielist.each do |s|
      items = s.split("; ")  # "; " で分割して expires を取得できるようにする。
      name = ""
      value = ""
      expires = nil
      items.each_with_index do |item, i|
        parts = item.split("=")
        # "; " の前の部分なら name, value とする。
        if i == 0
          name = parts[0]
          value = parts[1]
        else
           # "; " の後の部分なら expires とする。
           if parts[0] == "expires"
             expires = Time.parse_local(parts[1], "%Y-%m-%d %H:%M:%S")
           else
             # to be defined
           end
        end
      end
      # HTTP::Cookie を作成する。
      cookie = HTTP::Cookie.new(name, value)
      if !expires.nil?
        cookie = HTTP::Cookie.new(name, value, expires: expires)
      end
      @cookies << cookie  # @cookie にクッキーを追加
    end
    # レスポンスヘッダの set-cookie に基づいて @cookies を更新する。
    @headers.each do |header|
      if header[0] == "Set-Cookie"
        header[1].each do |c|
          parts = c.split(": ")
          name = parts[0]
          parts2 = parts[1].split("; ")
          @cookies[name] = parts2[0]
          if parts2[1].starts_with?("expires=")
             expires = parts2[1].split("=").pop
             @cookies[name].expires = Time.parse_local(expires, "%Y-%m-%d %H:%M%D")
          elsif parts2[1].starts_with?("max-age=")
            # Max-Age がある場合は、値に関わらずそのクッキーを削除する。
            delete(name)
          end
        end
      end
    end
    return @cookies
  end

  # @cookies を JSON ファイルとして保存する。
  def save_cookies(host : String)
    sb = String::Builder.new("{\n")
    sb << %("host": )
    sb << %("#{host}")
    sb << ",\n"
    sb << %("cookies": ")
    sb << to_s
    sb << "\"\n}\n"
    File.write(COOKIES_FILE, sb.to_s)
  end

  # @cookies を文字列に変換する。
  def to_s() : String
    sb = String::Builder.new("")
    @cookies.each_with_index do |cookie, i|
      sb << cookie.name
      sb << "="
      sb << cookie.value
      if !cookie.expires.nil?
        sb << "; expires="
        sb << cookie.expires.to_s
      end
      if @cookies.size - 1 > i
        sb << ", "
      end
    end
    return sb.to_s
  end

  # すべてのクッキーが有効か時間をチェックする。有効でない場合はそのクッキーを削除する。
  def check_expires()
    @cookies.each do |cookie|
      current = Time.local
      if cookie.expires < current
        delete(cookie.name)
      end
      if cookie.max_age == 0
        delete(cookie.name)
      end
    end
  end

  # name で指定したクッキーを削除する。
  def delete(name : String)
    @cookies.delete(name)
  end

  # すべてのクッキーをクリアする。
  def clear()
    @cookies.clear
    content = %({"host":"#{@current_host}", \n\n})
    File.write(COOKIES_FILE, content)
  end

  # クッキーを追加または更新する。
  def add(name, value : String, expires : Time | Nil = nil)
    @cookies[name] = value
    if ! expires.nil?
      @cookies[name].expires = expires
    end
  end

  # クッキーの値を得る。
  def [](name : String)
    return @cookies[name]
  end

end # of class
