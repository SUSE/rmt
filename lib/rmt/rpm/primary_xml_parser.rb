class RMT::Rpm::PrimaryXmlParser < RepomdParser::PrimaryXmlParser
  attr_reader :referenced_files
  def initialize(filename, mirror_src = false)
    super(filename)
    @mirror_src = mirror_src
  end

  def end_element(name)
    return unless package? name

    unless primary_src_package_with_mirror_src?
      build_reference_for_package_with_src(@package)
      return
    end

    super.end_element(name)
  end

  private

  def package?(name)
    name == 'package'
  end

  def primary_src_package_with_mirror_src?
    @package[:arch] == 'src' && !@mirror_src
  end

  def build_reference_for_package_with_src(package)
    @referenced_files << RepomdParser::Reference.new(
      location: package[:location],
       checksum_type: package[:checksum_type],
       checksum: package[:checksum],
       type: :rpm,
       size: package[:size].to_i || nil
      )
  end
end
