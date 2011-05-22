module Storward
  class Worker
    attr_accessor :running

    def run
      self.running = true

      worker = WorkerRunner.new

      worker.callback { run_next }
      worker.errback do |message, error| 
        Storward.log_error("worker", message, error)
        run_next
      end
    end

    def run_next
      if running
        EM::Timer.new(5) { run }
      end
    end

    def stop
      self.running = false
    end
  end

  class WorkerRunner
    include EventMachine::Deferrable

    def initialize
      Request.next_available do |request|
        if request
          request.worker_id = self.object_id

          request.save.tap do |saver|
            saver.callback do
              http = request.forward

              http.callback do
                request.worker_id = nil
                request.sent = true

                request.save.tap do |saver|
                  saver.callback { self.succeed }
                  saver.errback  {|error| self.fail(["Could not save forwarded request, it will be sent again", error]) }
                end

                http.errback do
                  request.worker_id = nil
                  request.save.tap do |saver|
                    saver.callback { self.fail(["Could not forward request, it will be attempted again", false]) }
                    saver.errback  {|error| self.fail(["Could not forward or save request", error]) }
                  end
                end
              end
            end
            saver.errback do |error|
              self.fail(["Could not save request information for forwarding. It will be attemplted again", error])
            end
          end
        else
          succeed
        end
      end
    end
  end
end
