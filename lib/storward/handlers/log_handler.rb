require 'storward/handler'
require 'storward/mongo'
require 'storward/view'

module Storward
  class LogHandler < Handler
    def handle_request
      MongoConnection.new do |db|
        collection = db.collection("requests")

        if id = request.params['id']
          collection.first({'_id' => BSON::ObjectId(id)}) do |doc|
            if doc
              @response.status = 200
              @response.content_type 'text/html; charset=utf-8'
              @response.content = View.new('request', 'admin', :request => doc).render
            else
              @response.status = 404
            end
            self.succeed
          end
        else
          collection.find({}, :order => ['received_at', :desc], :limit => 50) do |docs|
            @response.status = 200
            @response.content_type 'text/html; charset=utf-8'
            @response.content = View.new('log', 'admin', :requests => docs).render
            self.succeed
          end
        end
      end
    end
  end
end

