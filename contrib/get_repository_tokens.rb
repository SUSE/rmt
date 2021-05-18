#!/usr/bin/env ruby
require 'net/http'
require 'optparse'
require 'json'

def process_rels(headers)
  links = (headers['link'].first || '').split(', ').map do |link|
    href, name = link.match(/<(.*?)>; rel="(\w+)"/).captures
    [name.to_sym, href]
  end
  Hash[*links.flatten]
end

def get_token(repo_url)
  url = 'https://scc.suse.com/connect/organizations/repositories'
  response = get(url)

  loop do
    headers = response.header
    data = JSON.parse response.body
    data.each do |repo|
      next unless repo['url'].include? repo_url

      puts('Found a match')
      puts('URL: ' + repo['url'].split('?').first + "\n" + 'Token: ' + repo['url'].split('?').last)
    end
    rels = process_rels(headers.to_hash)
    unless rels.key? :next
      break
    end

    response = get(rels[:next])
  end
end

def get(url)
  uri = URI(url)

  request = Net::HTTP::Get.new uri
  request.basic_auth(@username, @password)

  request['cache-control'] = 'no-cache'
  request['Accept'] = 'application/vnd.scc.suse.com.v4+json'

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  response
end

@username = ''
@password = ''

def main
  OptionParser.new do |opts|
    opts.banner += ' [Repositories]'
    opts.separator 'Get repository CDN tokens'
    opts.version = '0.0.1'

    opts.on('-u', '--user USERNAME',
            '',
            'Mirroring username') { |arg| @username = arg }

    opts.on('-p', '--password PASSWORD',
            '',
            'Mirroring password') { |arg| @password = arg }
    begin
      opts.parse!
    rescue OptionParser::ParseError => e
      warn e
      warn '(-h or --help will show valid options)'
      exit 1
    end
  end

  if ARGV.empty?
    warn "Please add the repository you're searching for"
    exit 1
  else
    ARGV.each do |match_repo_url|
      get_token(match_repo_url)
    end
  end
end

main
