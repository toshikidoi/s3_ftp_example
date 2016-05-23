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
      unless path.match(/(^\/$)|(^\/#{@user}\/?$)|(^\/#{@user}\/#{IMAGES_DIR_NAME}\/?$)/)
        yield false
        return
      end
      prefix = scoped_path(path)

      item = Happening::S3::Bucket.new(@aws_bucket, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        yield contains_directory?(response.response, prefix)
      end
    end

    def dir_contents(path, &block)
      unless path.match(/(^\/$)|(^\/#{@user}\/?$)|(^\/#{@user}\/#{IMAGES_DIR_NAME}\/?$)/)
        yield []
        return
      end
      prefix = scoped_path_with_trailing_slash(path)

      # imageディレクトリへのアクセスなら画像リストcsvから画像ファイル一覧を取得し返す
      if path == "/#{@user}/#{IMAGES_DIR_NAME}"
        download_publish_data_csv do |publish_data_list|
          list = publish_data_list.split("\n").map{|data| data.split(',').first}
          yield list.map{|image_path| file_item(image_path, 0)}
        end
        return
      end

      item = Happening::S3::Bucket.new(@aws_bucket, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        case path
        when '/'
          yield parse_bucket_list(response.response)
        when "/#{@user}"
          file_condition = Proc.new{|name| name == "#{@user}/#{PUBLISH_DATA_CSV_PATH}"}
          dir_condition = Proc.new{|name| name == "#{@user}/#{IMAGES_DIR_NAME}/"}
          yield parse_bucket_list(response.response, file_condition, dir_condition)
        else
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
      unless path.match(/(^\/#{@user}\/#{PUBLISH_DATA_CSV_PATH}$)|(^\/#{@user}\/#{IMAGES_DIR_NAME}\/[^\/]+$)/)
        yield false
        return
      end
      key = scoped_path(path)

      # imageディレクトリへのアクセスなら画像リストcsvから画像ファイルのバケットとキーを取得し返す
      if path.start_with?("/#{@user}/#{IMAGES_DIR_NAME}/")
        download_publish_data_csv do |publish_data_list|
          list = publish_data_list.split("\n").map{|data| data.split(',')}
          bucket, key = list.find{|data| data.first == path.split('/')[3]}[1..2]
          get_bytes(bucket, key, &block)
        end
        return
      end
      get_bytes(@aws_bucket, key, &block)
    end

    def get_file(path, &block)
      unless path.match(/(^\/#{@user}\/#{PUBLISH_DATA_CSV_PATH}$)|(^\/#{@user}\/#{IMAGES_DIR_NAME}\/[^\/]+$)/)
        yield false
        return
      end
      key = scoped_path(path)

      # imageディレクトリへのアクセスなら画像リストcsvから画像ファイルのバケットとキーを取得し返す
      if path.start_with?("/#{@user}/#{IMAGES_DIR_NAME}/")
        download_publish_data_csv do |publish_data_list|
          list = publish_data_list.split("\n").map{|data| data.split(',')}
          bucket, key = list.find{|data| data.first == path.split('/')[3]}[1..2]
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

    def download_publish_data_csv
      on_error = Proc.new { |response|
        yield false
      }
      on_success = Proc.new { |response|
        yield response.response
      }
      item = Happening::S3::Item.new(@aws_bucket, "#{@user}/#{PUBLISH_IMAGES_CSV_PATH}", :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.get(:on_success => on_success, :on_error => on_error)
    end

    def get_bytes(bucket, key, &block)
      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield response.response_header["CONTENT_LENGTH"].to_i }

      item = Happening::S3::Item.new(bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.head(:retry_count => 0, :on_success => on_success, :on_error => on_error)
    end

    def download_file(bucket, key, &block)
      # open a tempfile to store the file as it's downloaded from S3.
      # em-ftpd will close it for us
      tmpfile = Tempfile.new("s3ftp")

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response|
        tmpfile.flush
        tmpfile.seek(0)
        yield tmpfile
      }

      item = Happening::S3::Item.new(bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.get(:retry_count => 1, :on_success => on_success, :on_error => on_error).stream do |chunk|
        tmpfile.write chunk
      end
    end

  end
end
