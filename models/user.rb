class User < ActiveRecord::Base
  set_table_name "peglist_users"
  
  validates_uniqueness_of :username
  has_many :pegs
  
  def ordered_pegs
    zeros, rest = pegs.find(:all).partition {|i| i.number.match(/^0/)}
    zeros.sort! {|a,b| a.number <=> b.number}
    rest.sort! {|a,b| a.number.to_i <=> b.number.to_i}
    [zeros, rest].flatten
  end
end
