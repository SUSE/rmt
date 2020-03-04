class RMT::Rpm::DeltainfoXmlParser < RepomdParser::DeltainfoXmlParser
  attr_reader :referenced_files
  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def end_element(name)
    if (name == 'delta')
      if (@package[:arch] == 'src' && !@mirror_src)
        # Call the end_element from RepomdParser::DeltainfoXmlParser
        super.end_element(name)
      else
        @referenced_files << RMT::Rpm::FileEntry.new(
          @delta[:location],
          @delta[:checksum_type],
          @delta[:checksum],
          :drpm
        )
      end
    end
  end

end
