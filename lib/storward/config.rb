module Storward
  class Config
    extend Property

    property :mongo_host, :default => "localhost"
    property :mongo_db,   :default => "storward"
    property :port,       :default => 8081

    property :worker_log, :default => $stdout
    property :access_log, :default => $stdout

    attr_reader :forwards

    def initialize
      @forwards = []
      instance_eval &Proc.new
    end

    def forward(*paths)
      @forwards << Forward.new(*paths, &Proc.new)
    end
  end
end
