class RMT::Rpm::Parser::PrimaryXmlDocument < RMT::Rpm::Parser::BaseSaxDocument

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
    if (name == 'package')
      @packages << RMT::Rpm::FileEntry.new(
        @package[:location],
        @package[:checksum_type],
        @package[:checksum],
        :rpm
      )
    end
  end

end

class RMT::Rpm::Parser::PrimaryXml < RMT::Rpm::Parser::Base

  def parse
    document = parse_document(@filename, RMT::Rpm::Parser::PrimaryXmlDocument)
    @referenced_files = document.packages
  end

end
