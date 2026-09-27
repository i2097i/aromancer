require_relative :spec_helper.to_s

describe "authentication" do
  SERVER_URL = "http://localhost:3000"
  HEADERS =  { "CONTENT_TYPE" => "application/json" }
  after :each do

  end

  context "create new account" do
    it "runs tests" do
      # puts Faraday.new(
      #   url: SERVER_URL,
      #   # params: {param: '1'},
      #   headers: HEADERS
      # ).get("/players").status

      true
    end
  end
end
