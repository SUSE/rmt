
def repo_url_to_local_path(path, url)
  'file://' + path + Repository.make_local_path(url)
end
