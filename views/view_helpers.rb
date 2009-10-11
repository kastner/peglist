module ViewHelpers
  def amp
    %q|<span class="amp">&amp;</span>|
  end
  
  def logged_in
    false
  end
  
  def not_logged_in
    true
  end
end