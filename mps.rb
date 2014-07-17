#!/usr/bin/env ruby

require 'rubygems'
require 'geocoder'

require 'json'
require 'open-uri'
require 'uri'
require 'csv'
require 'ipaddr'
require 'ipaddr_range_set'
require 'nokogiri'

time_start = "2013-01-01T00:00:00Z"
time_end   = "2014-07-15T23:59:59Z"

# Get all of the gc.ca IP ranges
gc_ca_ranges = JSON.parse(File.read("gc-ca.json"))
# puts gc_ca_ranges

# TODO: Load these in by parsing the JSON file and doing something with it.
# Couldn't get that done, so do it by hand.

government_of_canada = IPAddrRangeSet.new(
  ("192.139.201.0" .. "192.139.201.255"),
  ("192.139.202.0" .. "192.139.202.255"),
  ("192.139.203.0" .. "192.139.203.255"),
  ("192.139.204.0" .. "192.139.204.255"),
  ("192.197.77.0"  .. "192.197.77.255"),
  ("192.197.78.0"  .. "192.197.78.255"),
  ("192.197.80.0"  .. "192.197.80.255"),
  ("192.197.84.0"  .. "192.197.84.255"),
  ("192.197.86.0"  .. "192.197.86.255")
  )

house_of_commons = IPAddrRangeSet.new(
  ("192.197.82.0" .. "192.197.82.255")
  )

dnd = IPAddrRangeSet.new(
  ("131.132.0.0" .. "131.132.255.255"),
  ("131.133.0.0" .. "131.133.255.255"),
  ("131.134.0.0" .. "131.134.255.255"),
  ("131.135.0.0" .. "131.135.255.255"),
  ("131.136.0.0" .. "131.136.255.255"),
  ("131.137.0.0" .. "131.137.255.255"),
  ("131.138.0.0" .. "131.138.255.255"),
  ("131.139.0.0" .. "131.139.255.255"),
  ("131.140.0.0" .. "131.140.255.255"),
  ("131.141.0.0" .. "131.141.255.255")
  )

industry_canada = IPAddrRangeSet.new(
  ("192.197.183.0" .. "192.197.183.255"),
  ("161.187.0.0"   .. "161.187.255.255"),
  ("142.53.0.0"    .. "142.53.255.255")
  )

government_addresses = government_of_canada + house_of_commons + dnd + industry_canada

mps_url = "https://en.wikipedia.org/w/api.php?action=query&list=embeddedin&eititle=Template:Current_Members_of_the_Canadian_House_of_Commons&eilimit=450&format=xml"
senators_url = "https://en.wikipedia.org/w/api.php?action=query&list=embeddedin&eititle=Template:Senate_of_Canada&eilimit=450&format=xml"

revisions_url_base = "https://en.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=user|timestamp&rvstart=#{time_start}&rvend=#{time_end}&rvlimit=max&rvdir=newer&format=xml&pageids=::PAGEID::"

usercontrib_url_base = "https://en.wikipedia.org/w/api.php?action=query&list=usercontribs&ucuser=::USER::&ucstart=#{time_start}&ucend=#{time_end}&ucdir=newer&uclimit=500&ucprop=title|timestamp&format=json"

mps = Nokogiri::XML(open(mps_url).read)
senators = Nokogiri::XML(open(senators_url).read)

# Merge the bits I want from each XML file.  Not elegant, to convert to XML and then back, but it works.
people = Nokogiri::XML((mps.xpath("//embeddedin") + senators.xpath("//embeddedin")).to_xml)

edit_seen = Hash.new { |hash, key| hash[key] = Hash.new(0)}

results_csv = CSV.generate do |csv|
  csv << ["user", "title", "timestamp"]
  people.xpath("//embeddedin/ei").each do |mp|
    # Run through each MP's page
    STDERR.print mp.attr("title") + " "
    revisions_url = URI.escape(revisions_url_base.gsub("::PAGEID::", mp.attr("pageid")))
    # puts revisions_url
    # Get a list of the revisions made to the page since 2014-01-01
    revisions = Nokogiri::XML(open(revisions_url).read)
    revisions.xpath("//revisions/rev").each do |rev|
      user = rev.attr("user")
      # Ignore the revision unless it was done anonymously
      next unless rev.attr("anon")
      # And ignore it unless it came from a government IP address
      next unless government_addresses.include?(user)
      #geo_result = Geocoder.search(user).first
      #city =  defined?(geo_result.city)  ? geo_result.city  : "?"
      #state = defined?(geo_result.state) ? geo_result.state : "?"
      # puts "  #{city}, #{state} (#{user})"
      usercontrib_url = URI.escape(usercontrib_url_base.gsub("::USER::", user))
      # puts usercontrib_url
      edits = JSON.parse(open(usercontrib_url).read)
      contribs = edits["query"]["usercontribs"]
      if contribs.length > 0
        #counts = contribs.map { |e| e["title"]}.inject(Hash.new(0)) { |page, count| page[count] += 1; page}
        #counts.sort_by{ |k ,v| v}.reverse.each do |k, v|
        #  puts "   #{v}\t#{k}"
        #end
        contribs.each do |contrib|
          next unless contrib["ns"] == 0 # 0 are real content, 1 is Talk, 2 is User
          # We'll run into the same edit more than once, perhaps, so only count each once
          title = contrib["title"]
          timestamp = contrib["timestamp"]
          next if edit_seen[user][timestamp] > 0
          edit_seen[user][timestamp] += 1
          # See https://www.mediawiki.org/wiki/API:Meta and output at
          # https://en.wikipedia.org/w/api.php?action=query&meta=siteinfo&siprop=namespaces|namespacealiases
          # Can I only get ns=0 by adding a parameter to the query URL?
          # STDERR.puts "   #{title} (at #{timestamp})"
          csv << [user, title, timestamp]
          STDERR.print "."
        end
      end
    end
    STDERR.print "\n"
  end
end

puts results_csv

# API:Usercontribs: https://www.mediawiki.org/wiki/API:Usercontribs
