def add_downloaded_file(checksum_type, checksum, path)
  DownloadedFile.track_file(checksum: checksum,
                            checksum_type: checksum_type,
                            local_path: path,
                            size: File.size(path))
end

def create_and_track_file(file_reference, fixture_paths)
  if fixture_paths
    FileUtils.mkdir_p(File.dirname(file_reference.local_path))
    FileUtils.cp(fixture_paths, file_reference.local_path)
  end

  DownloadedFile.track_file(checksum: file_reference.checksum,
                            checksum_type: file_reference.checksum_type,
                            local_path: file_reference.local_path,
                            size: file_reference.size)
end

def create_repository_file(dir)
  file_dest = File.join(dir, "#{SecureRandom.alphanumeric(10)}.rpm")
  File.write(file_dest, SecureRandom.uuid)
  digest = Digest.const_get(:SHA256).file(file_dest)
  add_downloaded_file('SHA256', digest, file_dest)
end
