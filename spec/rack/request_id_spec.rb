require 'spec_helper'

describe Lumberjack::Rack::RequestId do
  
  it "should use the action dispatch request id if it exists" do
    app = lambda{|env| [200, {"Content-Type" => env["Content-Type"], "Unit-Of-Work" => Lumberjack.unit_of_work_id.to_s}, ["OK"]]}
    handler = Lumberjack::Rack::RequestId.new(app)
    
    response = handler.call("Content-Type" => "text/plain", "action_dispatch.request_id" => "0123-4567-89ab-cdef")
    response[0].should == 200
    response[1]["Content-Type"].should == "text/plain"
    response[1]["Unit-Of-Work"].should == "0123-4567-89ab-cdef"
    response[2].should == ["OK"]
  end
  
  it "should use an abbreviated action dispatch request id if abbreviated is true" do
    app = lambda{|env| [200, {"Content-Type" => env["Content-Type"], "Unit-Of-Work" => Lumberjack.unit_of_work_id.to_s}, ["OK"]]}
    handler = Lumberjack::Rack::RequestId.new(app, true)
    
    response = handler.call("Content-Type" => "text/plain", "action_dispatch.request_id" => "0123-4567-89ab-cdef")
    response[0].should == 200
    response[1]["Content-Type"].should == "text/plain"
    response[1]["Unit-Of-Work"].should == "0123"
    response[2].should == ["OK"]
  end
  
  it "should create a unit of work in a middleware stack if the request id doesn't exist" do
    app = lambda{|env| [200, {"Content-Type" => env["Content-Type"], "Unit-Of-Work" => Lumberjack.unit_of_work_id.to_s}, ["OK"]]}
    handler = Lumberjack::Rack::RequestId.new(app)
    
    response = handler.call("Content-Type" => "text/plain")
    response[0].should == 200
    response[1]["Content-Type"].should == "text/plain"
    unit_of_work_1 = response[1]["Unit-Of-Work"]
    response[2].should == ["OK"]
    
    response = handler.call("Content-Type" => "text/html")
    response[0].should == 200
    response[1]["Content-Type"].should == "text/html"
    unit_of_work_2 = response[1]["Unit-Of-Work"]
    response[2].should == ["OK"]
    
    unit_of_work_1.should_not == nil
    unit_of_work_2.should_not == nil
    unit_of_work_1.should_not == unit_of_work_2
  end

end
