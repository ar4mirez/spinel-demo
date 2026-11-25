# A Net::HTTP client for the API: creates an author and a book, sends one bad
# request, and prints what comes back. Run it while app.rb is serving.
#
#   spinel run client.rb [BASE_URL]    # default http://127.0.0.1:4580
require "json"
require "net/http"
require "uri"

base = URI(ARGV.fetch(0, "http://127.0.0.1:4580"))

Net::HTTP.start(base.host, base.port) do |http|
  call = lambda do |method, path, body = nil|
    request = Net::HTTP.const_get(method.capitalize).new(path, "Accept" => "application/json")
    if body
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
    end
    response = http.request(request)
    data = response.body.to_s.empty? ? nil : JSON.parse(response.body)
    puts "#{method} #{path} -> #{response.code} #{JSON.generate(data)}"
    data
  end

  author = call.("POST", "/authors", { "name" => "N. K. Jemisin", "born" => 1972 })["data"]
  book = call.("POST", "/books", { "title" => "The Fifth Season", "author_id" => author["id"],
                                   "year" => 2015, "tags" => ["fantasy"] })["data"]
  call.("GET", "/books/#{book["id"]}")
  call.("POST", "/books", { "title" => "", "author_id" => author["id"] })
  call.("DELETE", "/books/#{book["id"]}")
  call.("DELETE", "/authors/#{author["id"]}")
end
