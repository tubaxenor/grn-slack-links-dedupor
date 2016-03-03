require "slack-ruby-client"
require "uri"
require "httparty"
require "json"

Slack.configure do |config|
  config.token = ENV["SLACK_API_TOKEN"]
end

client = Slack::RealTime::Client.new

client.on :hello do
  puts "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
end

channel_id = client.web_client.channels_info(channel: '#links').channel.id
github_search_api_base = "https://api.github.com/search/code"

client.on :message do |data|
  if data.channel == channel_id
    if (urls = URI.extract(data.text, ["http", "https"])).any?
      urls.each do |url|
        res = HTTParty.get(github_search_api_base,
          query: { q: url + "+repo:greenruby/grn-static"}
        ).body

        if (json = JSON.parse(res))["total_count"] > 0
          occurrences = []
          json["items"].each do |item|
            if match = item["name"].match(/\Agrn-(\d+).yml\Z/)
              occurrences << match[1]
            end
          end
          client.message channel: data.channel, text: "#{url} already posted in #{occurrences.map { |o| "GRN-#{o}" }.join(", ")}"
        end
      end
    end
  end
end

client.on :close do |_data|
  puts 'Connection closed, exiting.'
  EM.stop
end

client.start!
