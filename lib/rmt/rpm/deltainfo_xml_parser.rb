class RMT::Rpm::DeltainfoXmlParser < RepomdParser::DeltainfoXmlParser
  attr_reader :referenced_files
  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def end_element(name)
    return unless delta? name

    unless delta_src_package_with_mirror_src?
      build_reference_for_package_with_src(@delta)
      return
    end

    super.end_element(name)
  end

  private

  def delta?(name)
    name == 'delta'
  end

  def delta_src_package_with_mirror_src?
    (@package[:arch] == 'src' && !@mirror_src)
  end

  def build_reference_for_package_with_src(delta)
    @referenced_files << RepomdParser::Reference.new(
      location: delta[:location],
       checksum_type: delta[:checksum_type],
       checksum: delta[:checksum],
       type: :drpm,
       size: delta[:size].to_i || nil
     )
  end
end
