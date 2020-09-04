#!/usr/bin/ruby

require 'open-uri'
require 'date'
require_relative './expire_v1.rb'
#require_relative './expire_v2.rb'

LOCAL_REPOS="/tmp/"
OSM2PGSQL_DIR="/usr/local/bin/"

def get_lock(file_name, &block)
  # open the locking file, in our case this is a time stamp
  f = File.new(file_name, "r+")

  # assume we didn't get the lock
  got_lock = false

  begin
    # try to acquire an exclusive lock, but return instantly if
    # we can't.
    got_lock = f.flock(File::LOCK_EX | File::LOCK_NB)

    if (got_lock)
      # while we're in the passed block we can use the file
      # knowing that nothing else is using it.
      block.call(f)
    end

  ensure
    # make sure we don't leave the file locked, even if an exception
    # is thrown.
    f.flock(File::LOCK_UN)
  end

  return got_lock
end

# the name of an hourly change file which *ends* at +time+.
def change_file(time)
  prev_time = time - Rational(1,24)
  prev_time.strftime("%Y%m%d%H") + "-" + time.strftime("%Y%m%d%H") + ".osc.gz"
end

# change to the osm2pgsql directory so it can find default.style and
# update the postgres database.
def update_pgsql(osc)
  Dir.chdir(OSM2PGSQL_DIR) do
    `./osm2pgsql --append --slim -G -j -r xml -d gis -C 9999 --number-processes 5 -S /home/chentoz/Downloads/openstreetmap-carto/openstreetmap-carto.style --tag-transform-script /home/chentoz/Downloads/openstreetmap-carto/openstreetmap-carto.lua  #{osc}`
  end
end

# main method:
Dir.chdir(LOCAL_REPOS) do
  osc_file = ARGV[0]
  # osm2pgsql_log = ARGV[1]
  # expiry_log = ARGV[2]

  get_lock("timestamp.txt") do |f|
    # update_pgsql(osc_file)
    Expire::expire(osc_file)
  end or puts "Didn't get the lock"

  exit 0
end
