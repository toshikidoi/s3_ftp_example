# coding: utf-8

require 'tempfile'

module S3FTP
  class Driver

    USER  = 0
    PASS  = 1
    ADMIN = 2

    PUBLISH_DATA_CSV_PATH = 'publish_data.csv'
    PUBLISH_IMAGES_CSV_PATH = 'publish_images.csv'
    IMAGES_DIR_NAME = 'image'

    def initialize(key, secret, bucket)
      @aws_key, @aws_secret, @aws_bucket = key, secret, bucket
    end

    def change_dir(path, &block)
      prefix = scoped_path(path)
      unless prefix.match(/(^#{@user}\/?$)|(^#{@user}\/[^\/]+\/?$)|(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/?$)/)
        write_log('change_dir', false)
        yield false
        return
      end

      item = Happening::S3::Bucket.new(@aws_bucket, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        result = contains_directory?(response.response, prefix)
        write_log('change_dir', result)
        yield result
      end
    end

    def dir_contents(path, &block)
      prefix = scoped_path_with_trailing_slash(path)
      unless prefix.match(/(^#{@user}\/?$)|(^#{@user}\/[^\/]+\/?$)|(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/?$)|(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/\*\/$)/)
        write_log('dir_contents', [])
        yield []
        return
      end

      if prefix.match(/(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/\*\/$)/)
        prefix = prefix.match(/(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/)/)[0]
      end

      item = Happening::S3::Bucket.new(@aws_bucket, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        case prefix
        when "#{@user}/"
          dir_condition = Proc.new{|name| name.match(/(^#{@user}\/[^\/]+\/$)/)}
          result = parse_bucket_list(response.response, Proc.new{ false }, dir_condition)
          write_log('dir_contents', result)
          yield result
        when /(^#{@user}\/[^\/]+\/?$)/
          file_condition = Proc.new{|name| name.match(/(^#{@user}\/[^\/]+\/#{PUBLISH_DATA_CSV_PATH}$)/)}
          dir_condition = Proc.new{|name| name.match(/(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/$)/)}
          result = parse_bucket_list(response.response, file_condition, dir_condition)
          write_log('dir_contents', result)
          yield result
        when /(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/?$)/
          # imageディレクトリへのアクセスなら画像リストcsvから画像ファイル一覧を取得し返す
          list = parse_bucket_list(response.response, Proc.new{ true }, Proc.new{ true })
          download_publish_data_csv(prefix) do |publish_data_list|
            data_list = publish_data_list.split("\n")
            list = list.map do |item|
              data = data_list.find{|data| data.split(',')[2] == "#{prefix}#{item.name}"}
              item.name = data ? data.split(',')[0] : nil
              item
            end.select(&:name)
            write_log('dir_contents', list)
            yield list
          end
        else
          write_log('dir_contents', [])
          yield []
        end
      end
    end

    def authenticate(user, pass, &block)
      download_passwd_file do |passwd|
        @users = extract_users(passwd)

        if @users[user] && @users[user][:pass] == pass
          @user = user
          yield true
        else
          yield false
        end
      end
    end

    def bytes(path, &block)
      key = scoped_path(path)
      unless key.match(/(^#{@user}\/[^\/]+\/#{PUBLISH_DATA_CSV_PATH}$)|(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/[^\/]+$)/)
        write_log('bytes', false)
        yield false
        return
      end

      # imageディレクトリへのアクセスなら画像リストcsvから画像ファイルのバケットとキーを取得し返す
      if key.match(/(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/[^\/]+$)/)
        download_publish_data_csv(key) do |publish_data_list|
          list = publish_data_list.split("\n").map{|data| data.split(',')}
          bucket, key = list.find{|data| data.first == key.split('/')[3]}[1..2]
          get_bytes(bucket, key, &block)
        end
        return
      end
      get_bytes(@aws_bucket, key, &block)
    end

    def get_file(path, &block)
      key = scoped_path(path)
      unless key.match(/(^#{@user}\/[^\/]+\/#{PUBLISH_DATA_CSV_PATH}$)|(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/[^\/]+$)/)
        write_log('get_file', false)
        yield false
        return
      end

      # imageディレクトリへのアクセスなら画像リストcsvから画像ファイルのバケットとキーを取得し返す
      if key.match(/(^#{@user}\/[^\/]+\/#{IMAGES_DIR_NAME}\/[^\/]+$)/)
        download_publish_data_csv(key) do |publish_data_list|
          list = publish_data_list.split("\n").map{|data| data.split(',')}
          bucket, key = list.find{|data| data.first == key.split('/')[3]}[1..2]
          download_file(bucket, key, &block)
        end
        return
      end
      download_file(@aws_bucket, key, &block)
    end

    def put_file(path, tmp_path, &block)
      yield false
    end

    def delete_file(path, &block)
      yield false
    end

    def delete_dir(path, &block)
      yield false
    end

    def rename(from, to, &block)
      yield false
    end

    def make_dir(path, &block)
      yield false
    end

    private

    def write_log(method_name, result)
      Log.info("#{method_name}: #{result}, user: #{@user}")
    end

    def extract_users(passwd)
      users  = {}
      CSV.parse(passwd).each { |row|
        users[row[USER]] = {
          :pass  => row[PASS],
          :admin => row[ADMIN].to_s.upcase == "Y"
        }
      }
      users
    end

    def download_passwd_file(&block)
      on_error = Proc.new { |response|
        yield false
      }
      on_success = Proc.new { |response|
        yield response.response
      }
      item = Happening::S3::Item.new(@aws_bucket, 'passwd', :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.get(:on_success => on_success, :on_error => on_error)
    end

    def admin?
      @users[@user] && @users[@user][:admin]
    end

    def scoped_path_with_trailing_slash(path)
      path  = scoped_path(path)
      path += "/" if path[-1,1] != "/"
      path == "/" ? nil : path
    end

    def scoped_path(path)
      path = "" if path == "/"

      if admin?
        File.join("/", path)[1,1024]
      else
        File.join("/", @user, path)[1,1024]
      end
    end

    def contains_directory?(xml, path)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      prefix = doc.xpath('/ListBucketResult/Prefix').first.content

      doc.xpath('//CommonPrefixes').any? { |node|
        name  = node.xpath('./Prefix').first.content

        name.to_s.start_with?(prefix)
      }
    end

    def parse_bucket_list(xml, file_condition_proc = Proc.new{ true }, dir_condition_proc = Proc.new{ true })
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      prefix = doc.xpath('/ListBucketResult/Prefix').first.content
      files = doc.xpath('//Contents').select { |node|
        name  = node.xpath('./Key').first.content
        bytes = node.xpath('./Size').first.content.to_i
        name != prefix && bytes > 0 && file_condition_proc.call(name)
      }.map { |node|
        name  = node.xpath('./Key').first.content
        bytes = node.xpath('./Size').first.content
        file_item(name[prefix.size, 1024], bytes)
      }
      dirs = doc.xpath('//CommonPrefixes').select { |node|
        name = node.xpath('./Prefix').first.content
        name != prefix + "/" && dir_condition_proc.call(name)
      }.map { |node|
        name  = node.xpath('./Prefix').first.content
        dir_item(name[prefix.size, 1024].tr("/",""))
      }
      default_dirs + dirs + files
    end

    def default_dirs
      [dir_item("."), dir_item("..")]
    end

    def dir_item(name)
      EM::FTPD::DirectoryItem.new(:name => name, :directory => true, :size => 0)
    end

    def file_item(name, bytes)
      EM::FTPD::DirectoryItem.new(:name => name, :directory => false, :size => bytes)
    end

    def download_publish_data_csv(prefix)
      store_name = extract_store_name(prefix)
      on_error = Proc.new { |response|
        yield false
      }
      on_success = Proc.new { |response|
        yield response.response
      }
      item = Happening::S3::Item.new(@aws_bucket, "#{@user}/#{store_name}/#{PUBLISH_IMAGES_CSV_PATH}", :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.get(:on_success => on_success, :on_error => on_error)
    end

    def extract_store_name(prefix)
      prefix.split("#{@user}/")[1].split('/')[0]
    end

    def get_bytes(bucket, key, &block)
      on_error   = Proc.new do |response|
        write_log('bytes', false)
        yield false
      end
      on_success = Proc.new do |response|
        result = response.response_header["CONTENT_LENGTH"].to_i
        write_log('bytes', result)
        yield result
      end

      item = Happening::S3::Item.new(bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.head(:retry_count => 0, :on_success => on_success, :on_error => on_error)
    end

    def download_file(bucket, key, &block)
      # open a tempfile to store the file as it's downloaded from S3.
      # em-ftpd will close it for us
      tmpfile = Tempfile.new("s3ftp")

      on_error   = Proc.new do |response|
        write_log('get_file', false)
        yield false
      end
      on_success = Proc.new do |response|
        tmpfile.flush
        tmpfile.seek(0)
        write_log('get_file', tmpfile)
        yield tmpfile
      end

      item = Happening::S3::Item.new(bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.get(:retry_count => 1, :on_success => on_success, :on_error => on_error).stream do |chunk|
        tmpfile.write chunk
      end
    end

  end

  class Log
    LOG_FILE = nil
    @@logger = nil

    def self.logger=(log)
      @@logger = log
    end

    def self.logger
      @@logger || create_logger
    end

    def self.create_logger
      config_data = File.read('config.rb')
      class_eval(config_data)
      log_file = LOG_FILE || STDOUT
      @@logger = Logger.new(log_file)
      @@logger.level = Logger::INFO
      @@logger
    end

    def self.level=(lev)
      logger.level = lev
    end

    def self.level
      logger.level
    end

    def self.debug(msg)
      logger.debug("S3FTP: #{msg}")
    end

    def self.info(msg)
      logger.info("S3FTP: #{msg}")
    end

    def self.warn(msg)
      logger.warn("S3FTP: #{msg}")
    end

    def self.error(msg)
      logger.error("S3FTP: #{msg}")
    end

    # 以下、元々あるconfigを使い回すために仕方なく(class_eval用)
    def self.driver(*_args); return end

    def self.driver_args(*_args); return end
  end
end
