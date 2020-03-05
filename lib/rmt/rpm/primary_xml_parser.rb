require 'repomd_parser'

class RMT::Rpm::ModifiedPrimaryXmlParser < RepomdParser::PrimaryXmlParser

  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def end_element(name)
    if (name == 'package')
      unless (@package[:arch] == 'src' && !@mirror_src)
        super(name)
      end
    end
  end

end
