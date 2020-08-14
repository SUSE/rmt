def add_downloaded_file(checksum_type, checksum, path)
  DownloadedFile.add_file(checksum_type, checksum, File.size(path), path)
rescue StandardError
  nil
end

def create_repository_file(dir)
  file_dest = File.join(dir, "#{SecureRandom.alphanumeric(10)}.rpm")
  File.open(file_dest, 'w+') { |file| file.write(SecureRandom.uuid) }
  digest = Digest.const_get(:SHA256).file(file_dest)
  add_downloaded_file('SHA256', digest, file_dest)
end
