module RMT
  VERSION ||= '2.5.9'.freeze

  DEFAULT_USER = '_rmt'.freeze
  DEFAULT_GROUP = 'nginx'.freeze
  DEFAULT_MIRROR_DIR = File.expand_path(File.join(__dir__, '../public/repo/')).freeze
  DEFAULT_MIRROR_URL_PREFIX = '/repo/'.freeze
end
