class RMT::Rpm::ModifiedDeltainfoXmlParser < RepomdParser::DeltainfoXmlParser

  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def end_element(name)
    if (name == 'delta')
      unless (@package[:arch] == 'src' && !@mirror_src)
        super(name)
      end
    end
  end

end
