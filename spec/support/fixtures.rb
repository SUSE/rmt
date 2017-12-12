def fixture_file(relative_path)
  File.read(fixture_file_path(relative_path))
end

def fixture_file_path(relative_path)
  ::Rails.root.join('spec', 'fixtures', 'files', relative_path).to_s
end
