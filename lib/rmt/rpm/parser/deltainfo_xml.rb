class RMT::Rpm::Parser::DeltainfoXml < RMT::Rpm::Parser::Base

  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def start_element(name, attrs = [])
    @current_node = name.to_sym
    if (name == 'newpackage')
      @package = {}
      @package[:version] = get_attribute(attrs, 'version')
      @package[:name] = get_attribute(attrs, 'name')
      @package[:arch] = get_attribute(attrs, 'arch')
    elsif (name == 'delta')
      @delta = {}
    elsif (name == 'checksum')
      @delta[:checksum_type] = get_attribute(attrs, 'type')
    end
  end

  def characters(string)
    if (@current_node == :filename)
      @delta[:location] ||= ''
      @delta[:location] += string.strip
    elsif (@current_node == :checksum)
      @delta[:checksum] ||= ''
      @delta[:checksum] += string.strip
    end
  end

  def end_element(name)
    if (name == 'delta')
      @referenced_files << RMT::Rpm::FileEntry.new(
        @delta[:location],
        @delta[:checksum_type],
        @delta[:checksum],
        :drpm
      ) unless (@package[:arch] == 'src' and !@mirror_src)
    end
  end

end
