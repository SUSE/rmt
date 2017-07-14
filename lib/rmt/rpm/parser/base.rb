class RMT::Rpm::Parser::BaseSaxDocument < Nokogiri::XML::SAX::Document

  attr_reader :packages

  def initialize
    @packages = []
  end

  protected

  def get_attribute(attributes, name)
    attributes.select {|e| e[0] == name }.first[1]
  end

end

class RMT::Rpm::Parser::Base

  attr_reader :referenced_files

  def initialize(filename)
    @referenced_files = []
    @package = {}
    @filename = filename
  end

  def parse
  end

  protected

  def parse_document(filename, class_name)
    sax_document = class_name.new
    if (File.extname(filename) == '.gz')
      Zlib::GzipReader.open(filename) do |gz|
        Nokogiri::XML::SAX::Parser.new(sax_document).parse(gz)
      end
    else
      File.open(filename) do |fh|
        Nokogiri::XML::SAX::Parser.new(sax_document).parse(fh)
      end
    end
    sax_document
  end

end
