require 'ruby_llm'
require 'ruby_llm/schema'

# Schema that enforces a fixed array structure so the Gemini response is always
# well-formed. Dynamic email IDs cannot be used as JSON Schema properties, so
# we collect results in a "results" array and reshape afterwards.
class ClassificationSchema < RubyLLM::Schema
  array :results do
    object do
      string :id,   description: 'The email message ID'
      array  :tags, of: :string, description: 'Short lowercase classification tags'
    end
  end
end

class EmailClassifier
  DEFAULT_MODEL = 'mistral-medium-2508'.freeze

  PROMPT = <<~PROMPT
    You are an email classifier. You will receive a JSON array of objects,
    each with an "id" and a "title" (the email subject line).

    Classify each email. For every email produce one entry in the "results" array
    with the original "id" and an array of 1-3 short, lowercase tags.

    Good tag examples: work, personal, newsletter, receipt, travel,
    social, finance, promotion, urgent, job, support, shipping.
  PROMPT

  def initialize(api_key:, model: DEFAULT_MODEL)
    @model = model
    RubyLLM.configure do |config|
      config.mistral_api_key = api_key
    end
  end

  def classify(emails)
    return {} if emails.nil? || emails.empty?

    input = emails.map do |e|
      # Accept both symbol-keyed and string-keyed hashes (MCP sends string keys)
      { id: e[:id] || e['id'], title: e[:title] || e['title'] }
    end

    chat = RubyLLM.chat(model: @model, provider: :mistral)
    response = chat
                 .with_schema(ClassificationSchema)
                 .ask("#{PROMPT}\nEmails:\n#{input.to_json}")

    reshape(response.content)
  end

  private

  # Convert [{"id"=>"msg_1", "tags"=>[...]}] structure to {"msg_1"=>[...]} map.
  def reshape(content)
    results = content.is_a?(Hash) ? content['results'] || content[:results] : nil
    return {} unless results.is_a?(Array)

    results.each_with_object({}) do |entry, hash|
      id   = entry['id']   || entry[:id]
      tags = entry['tags'] || entry[:tags]
      hash[id] = tags if id && tags
    end
  end
end
