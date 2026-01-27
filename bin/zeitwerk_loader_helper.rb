
require 'zeitwerk'


def load_relative_paths(paths, &block)
  loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
  
  rmt_path = File.expand_path('..', __dir__)
  cur_file = File.expand_path('..', __FILE__)
  paths.map do|dir|
    full_load_path = File.join(rmt_path, dir)
    loader.push_dir(full_load_path)
  end
  loader.ignore(cur_file) # Zeitwerk will stop expecting ZeitwerkLoaderHelper here
  
  yield loader if block_given?
  
  loader.setup
  loader.eager_load
end