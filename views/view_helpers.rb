module ViewHelpers
  def included
    puts "I am in"
  end
  def amp
    %q|<span class="amp">&amp;</span>|
  end
end