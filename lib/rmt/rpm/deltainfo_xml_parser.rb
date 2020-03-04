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
        @referenced_files << RepomdParser::Reference.new(
          location: @delta[:location],
          checksum_type: @delta[:checksum_type],
          checksum: @delta[:checksum],
          type: :drpm,
          size: @delta[:size].to_i || nil
        )
      end
    end
  end

end
