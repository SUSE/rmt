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
        @referenced_files << RepomdParser::Reference.new(
          location: @package[:location],
          checksum_type: @package[:checksum_type],
          checksum: @package[:checksum],
             type: :rpm,
             size: @package[:size].to_i || nil
       )
      end
    end
  end

end
