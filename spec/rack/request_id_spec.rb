require 'spec_helper'

describe Lumberjack::Rack::RequestId do
  
  it "should use the action dispatch request id if it exists" do
    app = lambda{|env| [200, {"Content-Type" => env["Content-Type"], "Unit-Of-Work" => Lumberjack.unit_of_work_id.to_s}, ["OK"]]}
    handler = Lumberjack::Rack::RequestId.new(app)
    
    response = handler.call("Content-Type" => "text/plain", "action_dispatch.request_id" => "0123-4567-89ab-cdef")
    expect(response[0]).to eq(200)
    expect(response[1]["Content-Type"]).to eq("text/plain")
    expect(response[1]["Unit-Of-Work"]).to eq("0123-4567-89ab-cdef")
    expect(response[2]).to eq(["OK"])
  end
  
  it "should use an abbreviated action dispatch request id if abbreviated is true" do
    app = lambda{|env| [200, {"Content-Type" => env["Content-Type"], "Unit-Of-Work" => Lumberjack.unit_of_work_id.to_s}, ["OK"]]}
    handler = Lumberjack::Rack::RequestId.new(app, true)
    
    response = handler.call("Content-Type" => "text/plain", "action_dispatch.request_id" => "0123-4567-89ab-cdef")
    expect(response[0]).to eq(200)
    expect(response[1]["Content-Type"]).to eq("text/plain")
    expect(response[1]["Unit-Of-Work"]).to eq("0123")
    expect(response[2]).to eq(["OK"])
  end
  
  it "should create a unit of work in a middleware stack if the request id doesn't exist" do
    app = lambda{|env| [200, {"Content-Type" => env["Content-Type"], "Unit-Of-Work" => Lumberjack.unit_of_work_id.to_s}, ["OK"]]}
    handler = Lumberjack::Rack::RequestId.new(app)
    
    response = handler.call("Content-Type" => "text/plain")
    expect(response[0]).to eq(200)
    expect(response[1]["Content-Type"]).to eq("text/plain")
    unit_of_work_1 = response[1]["Unit-Of-Work"]
    expect(response[2]).to eq(["OK"])
    
    response = handler.call("Content-Type" => "text/html")
    expect(response[0]).to eq(200)
    expect(response[1]["Content-Type"]).to eq("text/html")
    unit_of_work_2 = response[1]["Unit-Of-Work"]
    expect(response[2]).to eq(["OK"])
    
    expect(unit_of_work_1).not_to eq(nil)
    expect(unit_of_work_2).not_to eq(nil)
    expect(unit_of_work_1).not_to eq(unit_of_work_2)
  end

end
