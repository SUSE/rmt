def repo_url_to_local_path(path, url)
  'file://' + path + Repository.make_local_path(url)
end

# files: strings containing the 'relative_path'
# from: source directory relative to 'spec/fixtures/files'
# to: destination directory (usually a temp directory)
def mirror_fixtures(*files, from:, to:)
  files.each do |file|
    file_dirname = File.join(to, File.dirname(file))
    FileUtils.mkdir_p(file_dirname)

    fixture_relative_path = File.join(from, file)
    FileUtils.cp([file_fixture(fixture_relative_path)], file_dirname)
  end
end
