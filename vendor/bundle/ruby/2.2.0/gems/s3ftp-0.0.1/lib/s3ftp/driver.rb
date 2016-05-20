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
      puts "********************************** change_dir path: #{path}"
      unless path.match(/(^\/$)|(^\/#{@user}\/?$)|(^\/#{@user}\/#{IMAGES_DIR_NAME}\/?$)/)
        puts '********************************** change_dir path: false'
        yield false
        return
      end
      prefix = scoped_path(path)
      puts "********************************** change_dir prefix: #{prefix}"

      item = Happening::S3::Bucket.new(@aws_bucket, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        yield contains_directory?(response.response, prefix)
      end
    end

    def dir_contents(path, &block)
      puts "********************************** dir_contents path: #{path}"
      unless path.match(/(^\/$)|(^\/#{@user}\/?$)|(^\/#{@user}\/#{IMAGES_DIR_NAME}\/?$)/)
        puts '********************************** dir_contents path: false'
        yield []
        return
      end
      prefix = scoped_path_with_trailing_slash(path)
      puts "********************************** dir_contents prefix: #{prefix}"

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield response.response_header["CONTENT_LENGTH"].to_i }

      item = Happening::S3::Bucket.new(@aws_bucket, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        yield parse_bucket_list(response.response)
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

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield response.response_header["CONTENT_LENGTH"].to_i }

      item = Happening::S3::Item.new(@aws_bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.head(:retry_count => 0, :on_success => on_success, :on_error => on_error)
    end

    def get_file(path, &block)
      key = scoped_path(path)

      # open a tempfile to store the file as it's downloaded from S3.
      # em-ftpd will close it for us
      tmpfile = Tempfile.new("s3ftp")

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response|
        tmpfile.flush
        tmpfile.seek(0)
        yield tmpfile
      }

      item = Happening::S3::Item.new(@aws_bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.get(:retry_count => 1, :on_success => on_success, :on_error => on_error).stream do |chunk|
        tmpfile.write chunk
      end
    end

    def put_file(path, tmp_path, &block)
      key = scoped_path(path)

      bytes      = File.size(tmp_path)
      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield bytes  }

      item = Happening::S3::Item.new(@aws_bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.put(File.binread(tmp_path), :retry_count => 0, :on_success => on_success, :on_error => on_error)
    end

    def delete_file(path, &block)
      key = scoped_path(path)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield true  }

      item = Happening::S3::Item.new(@aws_bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.delete(:retry_count => 1, :on_success => on_success, :on_error => on_error)
    end

    def delete_dir(path, &block)
      prefix = scoped_path(path)

      on_error   = Proc.new {|response| yield false }

      item = Happening::S3::Bucket.new(@aws_bucket, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret, :prefix => prefix)
      item.get(:on_error => on_error) do |response|
        keys = bucket_list_to_full_keys(response.response)
        delete_object = Proc.new { |key, iter|
          item = Happening::S3::Item.new(@aws_bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
          item.delete(:retry_count => 1, :on_error => on_error) do |response|
            iter.next
          end
        }
        on_complete = Proc.new { yield true }

        EM::Iterator.new(keys, 5).each(delete_object, on_complete)
      end
    end

    def rename(from, to, &block)
      source_key = scoped_path(from)
      source_obj = @aws_bucket + "/" + source_key
      dest_key   = scoped_path(to)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield true  }

      item = Happening::S3::Item.new(@aws_bucket, dest_key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.put(nil, :retry_count => 1, :on_error => on_error, :headers => {"x-amz-copy-source" => source_obj}) do |response|
        item = Happening::S3::Item.new(@aws_bucket, source_key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
        item.delete(:retry_count => 1, :on_success => on_success, :on_error => on_error)
      end
    end

    def make_dir(path, &block)
      key = scoped_path(path) + "/.dir"

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield true  }

      item = Happening::S3::Item.new(@aws_bucket, key, :aws_access_key_id => @aws_key, :aws_secret_access_key => @aws_secret)
      item.put("", :retry_count => 0, :on_success => on_success, :on_error => on_error)
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

    def bucket_list_to_full_keys(xml)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      doc.xpath('//Contents').map { |node|
        node.xpath('./Key').first.content
      }
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

    def parse_bucket_list(xml)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      prefix = doc.xpath('/ListBucketResult/Prefix').first.content
      files = doc.xpath('//Contents').select { |node|
        name  = node.xpath('./Key').first.content
        bytes = node.xpath('./Size').first.content.to_i
        name != prefix && bytes > 0
      }.map { |node|
        name  = node.xpath('./Key').first.content
        bytes = node.xpath('./Size').first.content
        file_item(name[prefix.size, 1024], bytes)
      }
      dirs = doc.xpath('//CommonPrefixes').select { |node|
        node.xpath('./Prefix').first.content != prefix + "/"
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

  end
end
