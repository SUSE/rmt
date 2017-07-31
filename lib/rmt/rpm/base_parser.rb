require 'nokogiri'

class RMT::Rpm::BaseParser < Nokogiri::XML::SAX::Document

  attr_reader :referenced_files

  def initialize(filename)
    @referenced_files = []
    @filename = filename
  end

  def parse
    if (File.extname(@filename) == '.gz')
      Zlib::GzipReader.open(@filename) do |gz|
        Nokogiri::XML::SAX::Parser.new(self).parse(gz)
      end
    else
      File.open(@filename) do |fh|
        Nokogiri::XML::SAX::Parser.new(self).parse(fh)
      end
    end
  end

  protected

  def get_attribute(attributes, name)
    attributes.select { |e| e[0] == name }.first[1]
  end

end
