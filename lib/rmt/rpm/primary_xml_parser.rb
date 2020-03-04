class RMT::Rpm::PrimaryXmlParser < RepomdParser::PrimaryXmlParser
  attr_reader :referenced_files
  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def end_element(name)
    if (name == 'package')
      if (@package[:arch] == 'src' && !@mirror_src)
        # Call Parent class end_element in general cases
        super.end_element(name)
      else
        @referenced_files << RMT::Rpm::FileEntry.new(
          @package[:location],
          @package[:checksum_type],
          @package[:checksum],
          :rpm
         )
      end
    end
  end

end
