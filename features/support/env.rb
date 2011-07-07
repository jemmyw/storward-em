require 'cucumber/web/tableish'

Around do |scenario, blk|
  EM.synchrony do
    blk.call
    EM.stop
  end
end
