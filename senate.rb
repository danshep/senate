require 'yaml'
require 'csv'

class TransferableVote
  attr_reader :party
  def initialize(party, votes, preferences)
    @party, @votes, @preferences = party, votes, preferences
    @remaining = 1
    @other_votes = []
  end
  def votes
    @votes * @remaining
  end
  def preference(other_vote)
    puts "      Transferring %d from %s to %s" % [other_vote.votes, other_vote.party, self.party]
    @other_votes << other_vote
  end
  def total
    @other_votes.inject(votes) {|s,v| s + v.votes }
  end
  def elect(quota)
    old_total = total
    puts "    Party %s has %d votes, exceeding quota of %d votes" % [self.party, old_total, quota]
    puts "    **  Electing #{self.party}  **"
    raise "Quota must be greater than total" if quota > old_total
    consume_votes(quota / old_total)
  end
  def consume_votes(percent)
    @remaining *= 1 - percent
    @other_votes.each {|v| v.consume_votes(percent) }
  end
  def eliminate(other_votes)
    puts "    Excluding %s (%d votes)" % [self.party, self.total]
    allocate_preferences(other_votes)
    @other_votes.each do |v|
      v.allocate_preferences(other_votes)
    end
  end
  def allocate_preferences(other_votes)
    @preferences.each do |preference|
      if preference.is_a?(String)
        if other_vote = other_votes.detect {|x| x.party == preference}
          other_vote.preference(self)
          return
        end
      elsif preference.is_a?(Hash) && preference.size == 1 && preference['split']
        split_votes = other_votes.select {|vote| preference['split'].include?(vote.party) }
        unless split_votes.empty?
          split = votes / split_votes.size
          split_votes.each do |other_vote|
            other_vote.preference(TransferableVote.new(self.party, split, @preferences))
          end
          return
        end
      else
        raise "Invalid preference #{preference.inspect}"
      end
    end
    if @preferences.empty?
      puts "      No Preferences %s are known, %d ignored" % [self.party, self.votes]
    else
      puts "      Preferences of %s are exhausted, %d wasted" % [self.party, self.votes]
    end
  end
end



class Senate
  attr_reader :remaining_seats
  attr_reader :elected
  def initialize(votes)
    @votes = votes
    @elected = []
  end
  def remaining_seats
    12 - @elected.size
  end
  def remaining_votes
    @votes.inject(0) {|s,v| s + v.total }
  end
  def quota
    remaining_votes / (remaining_seats + 1)
  end
  def process
    while remaining_seats > 0
      @votes.sort_by!(&:total)
      quota = self.quota
      if @votes.last.total >= quota
        elected = @votes.last
        #puts "*** Electing #{elected.party} as #{elected.total} > #{quota}"
        elected.elect(quota)
        @elected << elected.party
      else
        eliminated = @votes.shift
        eliminated.eliminate(@votes)
      end
    end
  end
end

preferences = File.open('preferences/vic.yml') {|f| YAML.load(f) }
# preferences.each do |party, prefs|
#   prefs.each do |pref|
#     raise "Invalid preference #{pref.inspect}" unless preferences[pref]
#   end
# end

votes = []
CSV.open('votes/vic.csv') do |csv|
  csv.each do |row|
    party, total = row
    prefs = preferences[party]
    raise "Invalid party #{party.inspect}" unless prefs
    votes << TransferableVote.new(party, total.to_f, prefs)
  end
end

senate = Senate.new(votes)
senate.process
p senate.elected