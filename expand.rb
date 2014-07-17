#!/usr/bin/env ruby

require 'rubygems'
require 'geocoder'

require 'json'
require 'open-uri'
require 'uri'
require 'csv'
require 'ipaddr'

require 'nokogiri'

time_start = "2014-01-01T00:00:00Z"
time_end   = "2014-07-15T23:59:59Z"

# title = "Dean Del Mastro"
title = "Pamela Wallin"

revisions_url_base = "https://en.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=user|timestamp&rvstart=#{time_start}&rvend=#{time_end}&rvlimit=max&rvdir=newer&format=xml&titles=::TITLE::"

revisions_url = URI.escape(revisions_url_base.gsub("::TITLE::", title))

puts revisions_url

# API:Usercontribs: https://www.mediawiki.org/wiki/API:Usercontribs

usercontrib_url_base = "https://en.wikipedia.org/w/api.php?action=query&list=usercontribs&ucuser=::USER::&ucstart=#{time_start}&ucend=#{time_end}&ucdir=newer&uclimit=100&ucprop=title|timestamp&format=json"

revisions = Nokogiri::XML(open(revisions_url).read)

seen_user = Hash.new(0)

revisions.xpath("//revisions/rev").each do |rev|
  user = rev.attr("user")
  next unless rev.attr("anon")
  #next unless /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/.match(user) # Regex could be better?  Doesn't do IPv6 ... if that's a problem.
  next if seen_user[user] > 0
  seen_user[user] += 1
  puts user
  geo_result = Geocoder.search(user).first
  puts "#{user} #{geo_result.city}, #{geo_result.state}"
  # timestamp = rev.attr("timestamp")
  usercontrib_url = URI.escape(usercontrib_url_base.gsub("::USER::", user))
  puts usercontrib_url
  edits = JSON.parse(open(usercontrib_url).read)
  contribs = edits["query"]["usercontribs"]
  if contribs.length > 0
    contribs.each do |contrib|
      next unless contrib["ns"] == 0 # 0 are real content, 1 is Talk, 2 is User
      # See https://www.mediawiki.org/wiki/API:Meta and output at
      # https://en.wikipedia.org/w/api.php?action=query&meta=siteinfo&siprop=namespaces|namespacealiases
      puts "   #{contrib['title']} (at #{contrib['timestamp']})"
    end
  end
end
