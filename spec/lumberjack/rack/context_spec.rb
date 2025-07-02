require "spec_helper"

describe Lumberjack::Rack::Context do
  it "should create a context for a request" do
    app = lambda { |env| [200, {"Content-Type" => env["Content-Type"], "Context-ID" => "#{Lumberjack.context.object_id} #{Lumberjack.context.object_id}"}, ["OK"]] }
    handler = Lumberjack::Rack::Context.new(app)

    response = handler.call("Content-Type" => "text/plain", "action_dispatch.request_id" => "0123-4567-89ab-cdef")
    expect(response[0]).to eq(200)
    expect(response[1]["Content-Type"]).to eq("text/plain")
    expect(response[2]).to eq(["OK"])
    context_ids = response[1]["Context-ID"].split
    expect(context_ids[0]).to eq context_ids[1]
  end
end
