require 'storward/request'

module Storward
  class Sweeper
    def self.run
      new
    end

    def initialize
      EM::PeriodicTimer.new(3600) { run }
      run
    end

    def run
      Storward.logger("sweeper").info("Starting sweep")
      Storward::Server.configuration.couchdb do |db|
        cm = db.create_view("requests", "sweepable", %Q|
          function(doc) {
            if(doc.received_at && !doc.sent && !doc.proxying && !doc.worker_id) {
              emit(doc.received_at, doc);
            }
          }|)
        cm.callback { sweep }
        cm.errback do
          Storward.logger("sweeper").error("Could not create sweepable view")
        end
      end
    end

    def sweep
      Storward::Server.configuration.couchdb do |db|
        time = Time.now - (60*60*24*7)
        cm = db.execute_view("requests", "sweepable", :endkey => time.to_i, :map_docs => true)
        cm.callback do |docs|
          docs = docs["rows"]
          count = docs.size

          delete_done = proc do
            if docs.empty?
              Storward.logger("sweeper").info("Swept #{count} requests")
            else
              delete_next.call
            end
          end

          delete_next = proc do
            doc = docs.pop

            if doc
              dcm = doc.destroy
              dcm.callback(&delete_done)
              dcm.errback(&delete_done)
            end
          end

          delete_next.call
        end
      end
    end
  end
end
