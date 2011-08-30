require 'spec_helper'
require 'rocking_chair'

RockingChair.enable

describe Lumberjack::Device::Couchdb do

  before(:all) do
    RockingChair::Server.reset
    @device = Lumberjack::Device::Couchdb.new('http://127.0.0.1:5984',:db => 'dummy-log')
  end

  it "should write to db" do
    @device.write(Lumberjack::LogEntry.new(Time.now, 1, "Hello world!", nil, $$, nil))
    id = @device.db.documents['rows'].first()['id']
    @device.db.get(id)['message'].should == "Hello world!"
  end
  
end
