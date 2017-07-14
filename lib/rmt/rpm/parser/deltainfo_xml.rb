class RMT::Rpm::Parser::DeltainfoXmlDocument < RMT::Rpm::Parser::BaseSaxDocument

  def start_element(name, attrs = [])
    @current_node = name.to_sym
    if (name == 'newpackage')
      @package = {}
      @package[:version] = get_attribute(attrs, 'version')
      @package[:name] = get_attribute(attrs, 'name')
    elsif (name == 'checksum')
      @package[:checksum_type] = get_attribute(attrs, 'type')
    end
  end

  def characters(string)
    if (@current_node == :filename)
      @package[:location] ||= ''
      @package[:location] += string.strip
    elsif (@current_node == :checksum)
      @package[@current_node] ||= ''
      @package[@current_node] += string.strip
    end
  end

  def end_element(name)
    if (name == 'newpackage')
      @packages << RMT::Rpm::FileEntry.new(
        @package[:location],
        @package[:checksum_type],
        @package[:checksum],
        :drpm
      )
    end
  end

end

class RMT::Rpm::Parser::DeltainfoXml < RMT::Rpm::Parser::Base

  def parse
    document = parse_document(@filename, RMT::Rpm::Parser::DeltainfoXmlDocument)
    @referenced_files = document.packages
  end

end
