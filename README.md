Some scripts for getting at Wikipedia edits.

Requires Ruby.  If you get an error with the bundle command, run `gem install bundler` or perhaps `sudo gem install bundler` if Bundler isn't installed, or `sudo bundle install` if it is and something is going wrong.

    # git clone git@github.com:wdenton/wikipedia.edits.git
    # cd wikipedia.edits
	# bundle install
	# ./contributions-from-ip.rb ranges/commons.json > commons.csv

Then in another shell run this to see the what's found:

    # tail -f commons.csv

More to come.

# License

GPL v3.
