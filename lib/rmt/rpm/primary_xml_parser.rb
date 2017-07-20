class RMT::Rpm::PrimaryXmlParser < RMT::Rpm::BaseParser

  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
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
    if (name == 'package')
      @referenced_files << RMT::Rpm::FileEntry.new(
        @package[:location],
        @package[:checksum_type],
        @package[:checksum],
        :rpm
      ) unless (@package[:arch] == 'src' and !@mirror_src)
    end
  end

end
