module RMT
  class Parser

    def self.parse_repomd(filename)
      xml = Nokogiri::XML(File.open(filename))

      metadata = {}

      xml.xpath('/xmlns:repomd/xmlns:data').each do |data_node|
        type = data_node.attr('type').to_sym

        hash = {}
        data_node.xpath('./*').each do |node|
          hash[node.name.to_sym] = { value: node.text.to_s }

          node.attributes.each do |name, attr|
            hash[node.name.to_sym][name.to_sym] = attr.value
          end
        end

        metadata[type] ||= []
        metadata[type] << hash
      end

      metadata
    end

    def self.parse_primary(filename)
      document = PrimaryXmlDocument.new
      if (File.extname(filename) == '.gz')
        Zlib::GzipReader.open(filename) do |gz|
          Nokogiri::XML::SAX::Parser.new(document).parse(gz)
        end
      else
        Nokogiri::XML::SAX::Parser.new(document).parse(File.open(filename))
      end
      document
    end

  end

  class PrimaryXmlDocument < Nokogiri::XML::SAX::Document

    def initialize
      @packages = []
    end

    def start_element(name, attrs = [])
      @current_node = name.to_sym
      if (name == 'package')
        @package = {}
      elsif (name == 'version')
        @package[:version] = get_attribute(attrs, 'ver')
      elsif (name == 'location')
        @package[:location] = get_attribute(attrs, 'href')
      elsif (name == 'checksum')
        @package[:checksum_type] = get_attribute(attrs, 'type')
      end
    end

    def characters(string)
      if (%i(name arch checksum).include? @current_node)
        @package[@current_node] ||= ''
        @package[@current_node] += string.strip
      end
    end

    def end_element(name)
      @packages << @package if (name == 'package')
    end

    def result
      @packages
    end

    protected

    def get_attribute(attributes, name)
      attributes.select {|e| e[0] == name }.first[1]
    end

  end

  class Downloader

    KNOWN_HASH_FUNCTIONS = %i(MD5 SHA1 SHA256 SHA384 SHA512).freeze

    def initialize(repository_url, local_path)
      @repository_url = repository_url
      @local_path = local_path
    end

    def verify_checksum(filename, checksum_type, checksum_value)
      hash_function = checksum_type.gsub(/\W/, '').upcase.to_sym
      unless (KNOWN_HASH_FUNCTIONS.include? hash_function)
        raise "Unknown hash function #{checksum_type}"
      end

      digest = Digest.const_get(hash_function).file(filename)

      raise 'Checksum doesn\'t match!' unless (checksum_value == digest.to_s)

      puts "#{filename} - OK!"
    end

    def download(remote_file, checksum_type = nil, checksum_value = nil)
      filename = make_path(remote_file)
      make_request(remote_file, filename).run

      if (checksum_type and checksum_value)
        verify_checksum(filename, checksum_type, checksum_value)
      end

      filename
    end

    def download_bunch(files)
      @queue = files
      @hydra = Typhoeus::Hydra.new

      4.times { download_one }

      @hydra.run
    end

    protected

    def download_one
      queue_item = @queue.shift
      return unless queue_item

      remote_file = queue_item[:location]
      filename = make_path(remote_file)

      klass = self
      request = make_request(remote_file, filename) do
        klass.verify_checksum(filename, queue_item[:checksum_type], queue_item[:checksum])
        klass.download_one
      end

      @hydra.queue(request)
    end

    def make_path(remote_file)
      filename = File.join(@local_path, remote_file)
      dirname = File.dirname(filename)

      FileUtils.mkdir_p(dirname)

      filename
    end

    def make_request(remote_file, filename, &complete_callback)
      uri = URI.join(@repository_url, remote_file).to_s
      downloaded_file = File.open(filename, 'wb')

      request = Typhoeus::Request.new(uri, followlocation: true)
      request.on_headers do |response|
        raise 'Request failed' if response.code != 200
      end
      request.on_body do |chunk|
        downloaded_file.write(chunk)
      end
      request.on_complete do
        downloaded_file.close
        yield if complete_callback
      end
      request
    end

  end
end
