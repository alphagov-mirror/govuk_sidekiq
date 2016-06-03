require "spec_helper"
require "govuk_sidekiq/api_headers"

RSpec.describe GovukSidekiq::APIHeaders::ClientMiddleware do
  let(:govuk_request_id) { "some-unique-request-id" }
  let(:govuk_authenticated_user) { "some-unique-user-id" }

  it "adds the govuk_request_id and govuk_authenticated_user to the job arguments" do
    GdsApi::GovukHeaders.set_header(:govuk_request_id, govuk_request_id)
    GdsApi::GovukHeaders.set_header(:x_govuk_authenticated_user, govuk_authenticated_user)

    job = {
      "args" => []
    }

    described_class.new.call("worker_class", job, "queue", "redis_pool") do
      expect(job["args"].last[:request_id]).to eq(govuk_request_id)
      expect(job["args"].last[:authenticated_user]).to eq(govuk_authenticated_user)
    end
  end
end

RSpec.describe GovukSidekiq::APIHeaders::ServerMiddleware do
  let(:govuk_request_id) { "some-unique-request-id" }
  let(:govuk_authenticated_user) { "some-unique-user-id" }

  it "removes the govuk_request_id from the job arguments ands adds it to the API headers" do
    message = {
      "args" => [
        "some arg",
        { "authenticated_user" => govuk_authenticated_user, "request_id" => govuk_request_id },
      ]
    }

    described_class.new.call("worker", message, "queue") do
      expect(message["args"]).to eq(["some arg"])
      expect(GdsApi::GovukHeaders.headers[:govuk_request_id]).to eq(govuk_request_id)
      expect(GdsApi::GovukHeaders.headers[:x_govuk_authenticated_user]).to eq(govuk_authenticated_user)
    end
  end

  it "does nothing if the last argument is not a hash" do
    message = {
      "args" => [
        "some arg",
        "some other arg",
      ]
    }

    original_message = message.dup

    expect(GdsApi::GovukHeaders).not_to receive(:set_header)

    described_class.new.call("worker", message, "queue") do
      expect(message).to eq(original_message)
    end
  end

  it "does nothing if the last argument is a hash with no request_id key" do
    message = {
      "args" => [
        { "some arg" => "some value" },
      ]
    }

    original_message = message.dup

    expect(GdsApi::GovukHeaders).not_to receive(:set_header)

    described_class.new.call("worker", message, "queue") do
      expect(message).to eq(original_message)
    end
  end
end
