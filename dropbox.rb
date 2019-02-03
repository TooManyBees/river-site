require 'json'
require 'httpclient'
require 'fileutils'

POST_EXTNAMES = %w{
  .html .markdown .mkdown .mkdn .mkd .md
}
def clobber_existing(assets)
  names = assets.map do |(name, _)|
    File.join(File.dirname(name), File.basename(name, File.extname(name)))
  end.uniq
  names.each do |name|
    existing = Dir.glob("#{name}{#{POST_EXTNAMES.join(",")}}")
    existing.each { |filename| File.delete(filename) }
  end
end

AUTH = ENV['DROPBOX_ACCESS_TOKEN'] || begin
  require 'dotenv/load'
  ENV['DROPBOX_ACCESS_TOKEN']
rescue LoadError
end

unless AUTH
  raise <<-ENV_ERROR
Required DROPBOX_ACCESS_TOKEN env variable is not set!
Consider adding the file `#{File.join(Dir.pwd, '.env')}` with the contents:

DROPBOX_ACCESS_TOKEN=your_dropbox_access_token_here

substituting the placeholder for your app's generated token.
ENV_ERROR
end
http_client = HTTPClient.new

STDERR.puts "Getting list of entries from Dropbox"
list_response = http_client.post(
  "https://api.dropboxapi.com/2/files/list_folder",
  header: {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{AUTH}",
  },
  body: JSON.dump({path: "", recursive: true})
)

if list_response.ok?
  body = JSON.parse(list_response.body)
  entries = body.fetch("entries")
  STDERR.print "Downloading entries"
  entries.select do |entry|
    entry[".tag"] == "file"
  end
  .map do |entry|
    name = entry['path_lower']
    [
      File.join(".", name),
      http_client.post_async(
        "https://content.dropboxapi.com/2/files/download",
        header: {
          'Content-Type' => 'text/plain',
          Authorization: "Bearer #{AUTH}",
          'Dropbox-Api-Arg' => JSON.dump(path: name),
        }),
    ]
  end
  .map do |(name, connection)|
    response = connection.pop
    if response.ok?
      STDERR.putc "."
      [name, response.body]
    else
      STDERR.print "\nError: couldn't download #{File.basename(name)} (#{response.status})\n    "
      IO.copy_stream(response.body, STDERR)
      STDERR.puts
    end
  end
  .compact
  .tap { |assets| clobber_existing(assets) }
  .each do |(name, body)|
    FileUtils.mkdir_p(File.dirname(name))
    File.open(name, "w") do |f|
      IO.copy_stream(body, f)
    end
  end
  STDERR.puts
else
  STDERR.print "Failed to get list of files from Dropbox (#{list_response.status})\n    "
  STDERR.puts list_response.body
end
