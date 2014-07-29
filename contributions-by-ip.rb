#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Look up all Wikipedia edits made from a given range of IP numbers.
# Output as CSV.
# Usage:
#  ./contributions-by-ip.rb ip-ranges.json > results.csv
#  ./contributions-by-ip.rb https://raw.githubusercontent.com/edsu/anon/master/conf/congressedits.json > us-congress.csv

require 'rubygems'
# require 'geocoder'

require 'json'
require 'open-uri'
require 'uri'
require 'csv'
require 'ipaddr'
require 'ipaddr_range_set' # https://github.com/jrochkind/ipaddr_range_set

STDOUT.sync = true
STDERR.sync = true

# Ranges file can either be local or on the web.
ranges_file = ARGV.shift
abort 'Please specify JSON file containing IP ranges.' unless ranges_file

if /^http/.match(ranges_file)
  ranges_content = open(ranges_file).read
else
  ranges_content = File.read(ranges_file)
end
ranges = JSON.parse(ranges_content)['ranges']

# Use any start and end dates you want.
uc_start = '2005-01-01T00:00:00Z'
uc_end   = '2014-07-15T23:59:59Z'

# Time to sleep between requests
#   http://www.mediawiki.org/wiki/API:Etiquette says "If you make your
#   requests in series rather than in parallel ... then you should
#   definitely be fine." And "Use a descriptive User-Agent header that
#   includes your application's name and potentially your email address
#   if appropriate."

# TODO: Add User-Agent header.
sleep_time = 0

user_agent = "Crawler: https://github.com/wdenton/wikipedia.edits"

# We'll loop through the Wikipedias for all these languages.
# TODO: Option to specify languages.
langs = %w(ar bg ca zh cs da nl en eo eu fa fi fr de el he hu id it ja
           ko lt ms no pl pt ro ru sk sl es sv tr uk vi vo co)
# langs = %w(en fr)

# URL to get a list of contributions by a known user.  Plug in parameters we need later.
# See https://www.mediawiki.org/wiki/API:Usercontribs
usercontrib_url = 'https://::LANG::.wikipedia.org/w/api.php?' \
  'action=query' \
  '&list=usercontribs' \
  '&ucuser=::IPNUMBER::' \
  "&ucstart=#{uc_start}" \
  "&ucend=#{uc_end}" \
  '&ucdir=newer' \
  '&uclimit=500' \
  '&ucprop=title|timestamp|ids|sizediff' \
  '&format=json'

# We get back chunks that look like this (in JSON):
# {
#   "userid": "0",
#   "user": "192.197.82.203",
#   "pageid": 123498,
#   "revid": 20131642,
#   "parentid": 20131037,
#   "ns": 0,
#   "title": "Senate of Canada",
#   "timestamp": "2005-08-02T18:59:24Z"
# }
#
# With that, we can construct a URL using the pageid and revid
# (setting it as oldid) and "diff=prev" to see the change that was
# made:
# https://en.wikipedia.org/w/index.php?pageid=123498&oldid=20131642&diff=prev

# Header for the resulting CSV ... make sure to adjust this line if
# you fiddle with the output We'll dump out lines as we go, so you can
# tail -f the results file as it runs, or you can analyze it before
# the program finishes.
puts %w(user lang title timestamp pageid revid parentid sizediff).to_csv
ranges.each_pair do |office, netblock|
  STDERR.puts office
  netblock.each do |block|
    ip_range = []
    # ipaddr takes care of constructing ranges, looping through them, etc.  Very nice.
    if block.is_a?(String) # ["1.1.1.0/24"]
      ip_range = IPAddr.new(block).to_range
    else # It's an array like ["1.1.1.0", "1.1.1.255"]
      ip_range = IPAddr.new(block[0])..IPAddr.new(block[1])
    end
    ip_range.each do |ip|
      STDERR.print ip.to_s + ' '
      langs.each do |lang|
        # Query each Wikipedia for this IP number.  This takes a while, so the ...... output tells us how things are going.
        STDERR.print '.'
        url = URI.escape(usercontrib_url.gsub('::IPNUMBER::', ip.to_s)).gsub('::LANG::', lang)
        # STDERR.puts url
        begin
          edits = JSON.parse(open(url, "User-Agent" => user_agent).read)
          contribs = edits['query']['usercontribs']
          if contribs.length > 0
            contribs.each do |contrib|
              puts [
                ip,
                lang,
                contrib['title'],
                contrib['timestamp'],
                contrib['pageid'],
                contrib['revid'],
                contrib['parentid'],
                contrib['sizediff']
              ].to_csv
              STDERR.print '*' # If we found something.  Exciting!
            end
            if edits['query-continue']
              # There are more to get, because we hit the maximum number of
              # results in one query.  Loop through, using the timestamp
              # given, until there's nothing left.
              more_to_get = true
              while more_to_get
                uccontinue = edits['query-continue']['usercontribs']['uccontinue']
                url_for_more = url + URI.escape("&uccontinue=#{uccontinue}")
                # STDERR.puts url_for_more
                edits = JSON.parse(open(url_for_more, "User-Agent" => user_agent).read)
                contribs = edits['query']['usercontribs']
                # STDERR.puts contribs.length
                contribs.each do |contrib|
                  # STDERR.puts contrib
                  puts [
                    ip,
                    lang,
                    contrib['title'],
                    contrib['timestamp'],
                    contrib['pageid'],
                    contrib['revid'],
                    contrib['parentid'],
                    contrib['sizediff']
                  ].to_csv
                  # STDERR.puts contrib['title']
                  STDERR.print '*'
                end
                more_to_get = false unless edits['query-continue']
              end
            end
          end
          sleep sleep_time
        rescue => error
          STDERR.put "Could not load #{url}: #{error}"
        end
      end
      STDERR.print "\n"
    end
  end
end
