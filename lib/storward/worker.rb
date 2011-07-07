require 'storward/request'

module Storward
  class Worker
    attr_accessor :running

    def self.run
      new.run
    end

    def run
      self.running = true
      
      Storward::Server.configuration.couchdb do |db|
        cm = db.create_view("requests", "next_available", %Q|
          function(doc) {
            if(doc.received_at && !doc.sent && !doc.proxying && !doc.worker_id) {
              emit(doc.received_at, doc);
            }
          }|)
        cm.callback { run_worker }
        cm.errback do
          self.running = false
          raise "Could not create next_available view"
        end
      end
    end

    def run_worker
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
          request.save(:lock => self.object_id).tap do |saver|
            saver.callback do
              http = request.forward

              http.callback do
                request.save(:unlock => true).tap do |saver|
                  saver.callback { self.succeed }
                  saver.errback  {|error| self.fail(["Could not save forwarded request, it will be sent again", error]) }
                end
              end

              http.errback do
                request.save(:unlock => true).tap do |saver|
                  saver.callback { self.fail(["Could not forward request, it will be attempted again", false]) }
                  saver.errback  {|error| self.fail(["Could not forward or save request", error]) }
                end
              end
            end
            saver.errback do |error|
              self.fail(["Could not save request information for forwarding. It will be attempted again", error])
            end
          end
        else
          succeed
        end
      end
    end
  end
end
